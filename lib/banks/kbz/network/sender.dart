import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/proto/response/general_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/guest_login_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/login_for_sms_code_resqonse.dart';
import 'package:auto_report/banks/kbz/utils/aes_helper.dart';
import 'package:auto_report/banks/kbz/utils/sha_helper.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';

class Sender {
  final String aesKey;
  final String ivKey;
  final String deviceId;
  final String uuid;
  final String model;

  String? _token;
  String? _miPush;

  Sender({
    required this.aesKey,
    required this.ivKey,
    required this.deviceId,
    required this.uuid,
    required this.model,
  }) {
    _miPush = generateRandomString(64);
  }

  set token(v) => _token = v;

  String generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/+';
    final random = Random.secure();
    final randomString =
        List.generate(length, (_) => charset[random.nextInt(charset.length)])
            .join('');
    return randomString;
  }

  Future post({required Map body, required Map<String, String> header}) async {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final url = Uri.https(Config.host, 'api/interface/version1.1/customer');
    final encryptKey = RSAHelper.encrypt(aesKey, Config.rsaPublicKey);
    final encryptIV = RSAHelper.encrypt(ivKey, Config.rsaPublicKey);

    final bodyConetnt = jsonEncode(body);
    final sign =
        ShaHelper.hashMacSha256(timestamp + ivKey + bodyConetnt, aesKey);

    final encryptBody = AesHelper.encrypt(bodyConetnt, aesKey, ivKey);
    final headers = Config.getHeaders()
      ..addAll(header)
      ..addAll({
        'Authorization': encryptKey,
        'IvKey': encryptIV,
        'Sign': sign,
        "Timestamp": timestamp,
      });

    return await Future.any([
      http.post(url, headers: headers, body: encryptBody),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);
  }

  Future<bool> geustLoginMsg() async {
    try {
      logger.i('start geust login');

      final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
      final response = await post(
        body: {
          'commandId': 'GuestLogin',
          'deviceID': deviceId,
          'encoding': 'unicode',
          'initiatorMSISDN': 'Guest_$deviceId',
          'language': Config.language,
          'originatorConversationID': uuid,
          'platform': Config.osType,
          'timestamp': timestamp,
          'token': '',
          'version': Config.appversion,
        },
        header: {
          'user-agent': 'okhttp-okgo/jeasonlzy',
          'Messagetype': 'NEW',
        },
      );

      if (response is! http.Response) {
        EasyLoading.showError('geust login timeout');
        logger.i('geust login timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt'] == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        final responseData =
            GuestLoginResqonse.fromJson(jsonDecode(decryptBody));

        logger.i('guest token: ${responseData.guestToken}');
        logger.i('server timestamp: ${responseData.serverTimestamp}');
        _token = responseData.guestToken!;
        return responseData.responseCode == '0';
      }

      // EasyLoading.showInfo('geust login success.');
      // logger.i('geust login success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<bool> requestOtpMsg(String phoneNumber) async {
    try {
      logger.i('start request otp: $phoneNumber');

      final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
      final response = await post(
        body: {
          'Request': {
            'Header': {
              "CommandID": "SMSVerificationCode",
              "ClientType": Config.osType,
              "Language": Config.language,
              "Version": Config.versioncode,
              "OriginatorConversationID": const Uuid().v4(),
              "DeviceID": deviceId,
              "Token": _token,
              "DeviceVersion": Config.deviceVersion,
              "KeyOwner": "",
              "Timestamp": timestamp,
              "Caller": {
                'CallerType': '2',
                'Password': '',
                'ThirdPartyID': '1',
              },
            },
            'Body': {
              'Identity': {
                'Initiator': {
                  'Identifier': phoneNumber,
                  'IdentifierType': '1',
                },
                'ReceiverParty': {
                  'Identifier': phoneNumber,
                  'IdentifierType': '1',
                }
              }
            }
          }
        },
        header: {
          'user-agent': 'okhttp/4.10.0',
        },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt'] == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData = GeneralResqonse.fromJson(jsonDecode(decryptBody));
        return responseData.Response?.Body?.ResponseCode == '0';
      }

      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<Tuple3<bool, String, LoginForSmsCodeResqonse?>> loginMsg(
      String phoneNumber, String otpCode) async {
    try {
      logger.i('start login.phone number: $phoneNumber, otp code: $otpCode');

      final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
      final response = await post(
        body: {
          'commandId': 'LoginForSmsCode',
          'brand': 'google',
          'deviceModel': model,
          'deviceToken': '',
          'homeConfigVersion': '1.1.984',
          'miPushRegisterId': _miPush,
          'myServiceVersion': '1.0.925',
          'networkMode': 'wifi',
          'osVersion': 'Android11',
          'resolution': '2160x1080',
          'smsCode': otpCode,
          'supportGoogleService': 'false',
          'deviceID': deviceId,
          'encoding': 'unicode',
          'initiatorMSISDN': phoneNumber,
          'language': Config.language,
          'originatorConversationID': const Uuid().v4(),
          'platform': 'Android',
          'timestamp': timestamp,
          'token': '',
          'version': Config.appversion,
        },
        header: {
          'user-agent': 'okhttp/4.10.0',
          'Messagetype': 'NEW',
        },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt'] == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            LoginForSmsCodeResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<bool> requestIdentityVerificationMsg(
      String phoneNumber, String id) async {
    try {
      logger.i('start request otp: $phoneNumber, $id');

      final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
      final response = await post(
        body: {
          'Request': {
            'Header': {
              "CommandID": "IdentityVerification",
              "ClientType": Config.osType,
              "Language": Config.language,
              "Version": Config.versioncode,
              "OriginatorConversationID": const Uuid().v4(),
              "DeviceID": deviceId,
              "Token": _token,
              "DeviceVersion": Config.deviceVersion,
              "KeyOwner": "",
              "Timestamp": timestamp,
              "Caller": {
                'CallerType': '2',
                'ThirdPartyID': '1',
                'Password': '',
              },
            },
            'Body': {
              'RequestDetail': {
                'Encoding': 'unicode',
                'IDType': '01',
                'IdNo': id,
                'isLiveDb': false,
              },
              'Identity': {
                'Initiator': {
                  'Identifier': phoneNumber,
                  'IdentifierType': '1',
                },
                'ReceiverParty': {
                  'Identifier': phoneNumber,
                  'IdentifierType': '1',
                },
              }
            }
          }
        },
        header: {
          'user-agent': 'okhttp/4.10.0',
        },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt'] == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData = GeneralResqonse.fromJson(jsonDecode(decryptBody));
        return responseData.Response?.Body?.ResponseCode == '0';
      }

      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }
}
