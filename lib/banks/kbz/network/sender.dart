import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/account/account_data.dart';
import 'package:auto_report/banks/kbz/data/proto/response/err_response.dart';
import 'package:auto_report/banks/kbz/data/proto/response/general_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/guest_login_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/login_for_sms_code_resqonse1.dart';
import 'package:auto_report/banks/kbz/data/proto/response/login_for_sms_code_resqonse_5.8.1.dart';
import 'package:auto_report/banks/kbz/data/proto/response/login_for_sms_code_resqonse.dart'
    as login_for_smscode_resqonse_old_version;
import 'package:auto_report/banks/kbz/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/query_customer_balance_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/transfer_to_account_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/verify_pin_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/verify_qr_code_resqonse.dart';
import 'package:auto_report/banks/kbz/utils/aes_helper.dart';
import 'package:auto_report/banks/kbz/utils/sha_helper.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';

class Sender {
  final String aesKey;
  final String aesKeyRSA;
  final String ivKey;
  final String ivKeyRSA;
  final String deviceId;
  final String uuid;
  final String model;

  String? token;
  String? miPush;
  String? fullName;

  bool invalid = false;

  int timeDiff = 0;

  String _encryptPin(String pin, timestamp) {
    final random = Random.secure();
    final rand4 = random.nextInt(10000).toString().padLeft(4, '0');
    final rand2 = random.nextInt(100).toString().padLeft(2, '0');
    // final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final pinUuid = const Uuid().v4();
    final vaguePin = '01${rand4}06$timestamp$pin$pinUuid$rand2';
    logger.i('vaguePin: $vaguePin');
    return RSAHelper.encrypt(vaguePin, Config.pinPublicKey);
  }

  Sender({
    required this.aesKey,
    required this.aesKeyRSA,
    required this.ivKey,
    required this.ivKeyRSA,
    required this.deviceId,
    required this.uuid,
    required this.model,
    this.miPush,
    this.token,
    this.fullName,
  }) {
    miPush ??= generateRandomString(64);
    token ??= '';
  }

  // set token(v) => token = v;

  String generateRandomString(int length) {
    const charset =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789/+';
    final random = Random.secure();
    final randomString =
        List.generate(length, (_) => charset[random.nextInt(charset.length)])
            .join('');
    return randomString;
  }

  Map<String, dynamic> sortKeys(Map<String, dynamic> json) {
    var sortedKeys = json.keys.toList()..sort();
    var sortedMap = <String, dynamic>{};
    for (var key in sortedKeys) {
      sortedMap[key] = json[key];
    }
    return sortedMap;
  }

  Future<String> encrypt(String str) async {
    var resq = await http.get(Uri.parse("http://192.168.50.100:8080/encrypt?str=$str"));
    logger.i("ret status: ${resq.statusCode}");
    logger.i("ret: ${resq.body}");
    return resq.body;
  }

  // String timestamp = '1766640002094';

  Future post(
      {
        required Map<String, dynamic> body,
        required Map<String, String> header,
        String? timestamp,
      }) async {
    timestamp ??= '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';

    final url = Uri.https(Config.host, 'api/interface/version1.3/customer');
 
    // logger.i('aesKey base64: $aesKey, iv: $ivKey');

    final sortedBody = sortKeys(body);
    final bodyContent = jsonEncode(sortedBody);
    final signContent = timestamp + ivKey + bodyContent;
    var sign =
        ShaHelper.hashMacSha256(signContent, aesKey);

    var encryptBody = AesHelper.encryptGCM(bodyContent, aesKey, ivKey);
    // encryptBody = "onqsPmB00s6qhreb4QCP6L2wRpRAdpRPvbP4BwoyO7CKiC/v7BsO3ELZYgx5ThcWO3+VjvWdJZuVT8+VJBhNuJvaOcPwDMbr2SA2lGoW+vBP0wEZ/Ipog9lRiY6VlCvY3L8e5K87Xuw8wHQx20b1Lsc+Pdp4pit2Ab6cMpLwvvVZJqtRc4u4kjnHPAqRWrhSh7/D/acf2lWb/wdGJc8ksaVrXMbzrQBdAH9Db0Zf3yyyQIb5N/+j2zeb0X5sGvSCkyZ0plfjwJaUZKfP37X4ZVLyqu8i66yPPXxHlVn1XWQv8GwFaeiu9DfXOpQ6LXsKxZqVwVO+sOQyVPVIxS2QgrvkPsBIz1K/mJNXzx/MDqPcgGJ2kvEpv5mv23gZC/0ZQChW0L0Sy2c=";
    
    // logger.i('timestamp: $timestamp');
    // logger.i('encryptBody: $encryptBody');
    // logger.i('signContent: $signContent');
    // logger.i('sign: $sign');
    // sign = "000d3e7610a4a80294ea94d855a9c4a718f5f2478d85c68bd538a66897900ec6";

    // return;
    // test.
    // const encryptKey = "iZcNfJ2cc9p0npzXN9oa5Gy6dzAHbRM8JkiJda2xClcMWS8iWSwk8e5/uTQ+/Y1fioWL7/40wlmbRzLh4JjTjepmS/FmjIzVXdy2aj/2f/7Y9RfxBPBb/Ixi8eCvUgS1wqtZ4oixJL2+kJYD8sWlmOqySnKWiyKVNomkGkhfussReyMbxhRAhFcdGLv0Hl959Agrf4+5I6vzoeJbictlxzujlCrB/IGe9NNGjL+dE/cBnyDlWvSRTLyPLB6wD8cGNkU6M/42BqWClcsOHjUhj1JCFPPrUaPM71GpamFy3XyuBZRU+6srH3FysN0FdXfuU7JyvmXovo5XVI10X1iaLw==";
    // const encryptIV = "HpWmIbfJugUzuwVfD1JMrKzXjWt8jXgJjEpEwuH0cSK2MzIvqELaYAwVEnTBQd1Y/Do6yd+6lerjlL5QaqJNfNySc1NjA20HA7LYA6h8WTvwx6vkhG7HDAHqlSuhSr52gkEzvbm0g35ZajkTt3bSLwLbbZ0k6rfdzdE+1fVflKaKJ4IEk5ms4iVua1IktimOXheCsK7EOAmGAuAczorUbXONrsrAkQDIapZv4ZEKPqJc5SGvUZMtsQOekHw+ZgLNYwv4H5h0IjqxgEhxXkG35N0mcykbi5onm4cErIDPJ/3r8pHApCg+3w7yoUH2wzQFodhdWIExM81lwS8kr8GwkQ==";
    // const sign = "096c6a6eda0edc808f1efc73d876412ce6f3727ef60507379185bb4d5b50a9b9";
    // const encryptBody = "/BmCWLONIK9/wM0F8O0XJZkfZXQimiG0w/imkr68u02ZdSaOWVtth4dmPBpCe/MZkjKzemYOYGYqck28b8ZdYzJ+ilmZNHEBqXyn3vmSaabBikEKLEWsMq9C7u/HYn3VkoIYyhIlLXlhvojsIIxNSMBcl0OtfLikQ9UvToHoaJC7nFjtoKxXYD5pNFCZPdvgqhC7R0ZhotanPj7+UkiqwSrGKHli+4tmksZA7ZLP0HpIoVTjYEKMz2nm2dxRu4HleF3GUXGM0FBOuYeMwoLga5jvxyp5I/6QKpQozBSXwin886femEloeqa9mXpUU8XAsYPo4PSVrdBOiGpLP4w2VMFyX79lp/2B1kna2nRPinHjmdAgtSyVHbmi3AnV0nUPyHFfqd8Tro4=";
    
    final headers = Config.getHeaders()
      ..addAll(header)
      ..addAll({
        'Authorization': aesKeyRSA,
        'IvKey': ivKeyRSA,
        'Sign': sign,
        'Timestamp': timestamp,
      });

    logger.i('request headers: $headers');
    // logger.i('request body: $sortedBody');
    logger.i('request body content: $bodyContent');

    return await Future.any([
      http.post(url, headers: headers, body: encryptBody),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);
  }

  Map<String, String> getTemplateHeader(bool needNew) {
    var headers = ({
      // 'MessageType': 'NEW',
      'Content-Type': 'application/json; charset=utf-8',
      'KBZPay-App-Type' : 'customer',
      'KBZPay-Device-Type' : 'Android',
      'KBZPay-Version': Config.appversion,
      'KBZPay-Command-Id': 'GuestLogin',
      'User-Agent': 'okhttp/4.12.0',
      });

    if (needNew) {
      headers['MessageType'] = 'NEW';
    }
    return headers;
  }


  Map<String, dynamic> getBodyTemplate() {
    return getBodyTemplate1()
      ..addAll({
        'brand': 'google',
        'deviceModel': model,
        'deviceToken': '',
        // 'miPushRegisterId': miPush,
        'miPushRegisterId': '',
        'networkMode': 'wifi',
        'osVersion': 'Android11',
        'resolution': '2160x1080',
        'supportGoogleService': 'false',
      });
  }

  Map<String, dynamic> getBodyTemplate1() {
    final timestamp =
        '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
    return {
      'deviceID': '',
      'imei': deviceId,
      // 'DeviceToken': '',
      'encoding': 'unicode',
      'language': Config.language,
      'originatorConversationID': const Uuid().v4(),
      'platform': 'Android',
      'token': token,
      'version': Config.appversion,
      'timestamp': timestamp,
    };
  }

  Map<String, dynamic> getBodyTemplateContainsHeaders({
    required String commondId,
    required Map<dynamic, dynamic> body,
    String? timestamp,
    bool useDynamicCaller = false,
  }) {
    timestamp ??= '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
    return {
      'Request': {
        'Header': {
          "CommandID": commondId,
          "ClientType": Config.osType,
          "Language": Config.language,
          "Version": Config.appversion,
          "OriginatorConversationID": const Uuid().v4(),
          "DeviceID": deviceId,
          "Imei": deviceId,
          "UseDynamicCaller": useDynamicCaller,
          "Token": token,
          "DeviceVersion": Config.deviceVersion,
          "KeyOwner": "",
          "Timestamp": timestamp,
          "Caller": {
            'CallerType': '2',
            'ThirdPartyID': '1',
            'Password': '',
          },
        },
        'Body': body,
      }
    };
  }

  Future<bool> geustLoginMsg() async {
    try {
      logger.i('start geust login');

      final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
      // final timestamp = '1766641597819';
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
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'GuestLogin',
        }),
      );

      if (response is! http.Response) {
        EasyLoading.showError('geust login timeout');
        logger.i('geust login timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        // var aesKey =  "rMtQ0gbqicreL4SR/vzkij0ugUcVop7Y/9h719vRHUY=";
        // var ivKey = "d3d5b0fb2b53b5620c246ee1a99bb28f33364348445e1c85d0b8ff899fa2119d";

        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        final responseData =
            GuestLoginResqonse.fromJson(jsonDecode(decryptBody));

        logger.i('decrypt body: $decryptBody');
        logger.i('guest token: ${responseData.guestToken}');
        logger.i('server timestamp: ${responseData.serverTimestamp}');
        token = responseData.guestToken!;
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

      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'SMSVerificationCode',
          body: {
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
          },
        ),
        // header: {
        //   'User-Agent': 'okhttp/4.12.0',
        // },
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'SMSVerificationCode',
        }),
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData = GeneralResqonse.fromJson(jsonDecode(decryptBody));
        final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch;
        timeDiff =
            responseData.Response!.Body!.ResponseDetail!.ServerTimestamp! -
                timestamp;
        logger.i('timeDiff: $timeDiff');
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

  Future<
      Tuple4<bool, String, LoginForSmsCodeResqonse?,
          LoginForSmsCodeResqonse1?>> loginMsg(
      String phoneNumber, String otpCode, String? businessUniqueId) async {
    try {
      logger.i(
          'start login.phone number: $phoneNumber, otp code: $otpCode, businessUniqueId: ${businessUniqueId ?? ''}');
      final body = getBodyTemplate()
        ..addAll({
          'commandId': 'LoginForSmsCode',
          // 'homeConfigVersion': '1.1.984',
          // 'myServiceVersion': '1.0.925',
          'homeConfigVersion': '',
          'myServiceVersion': '',
          'smsCode': otpCode,
          'initiatorMSISDN': phoneNumber,
        });
      if (businessUniqueId != null) {
        body.addAll({
          'businessUniqueId': businessUniqueId,
        });
      }

      final response = await post(
        body: body,
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'LoginForSmsCode',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple4(false, 'request otp timeout', null, null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            LoginForSmsCodeResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        // if (ret) {
        //   fullName = responseData.userInfo?.fullName ?? '';
        // }
        if (responseData.token?.isNotEmpty ?? false) {
          logger.i('old token: $token');
          token = responseData.token!;
          logger.i('new token: $token');
        } else {
          final responseData1 = login_for_smscode_resqonse_old_version
              .LoginForSmsCodeResqonse.fromJson(jsonDecode(decryptBody));
          if (responseData1.userInfo?.token?.isNotEmpty ?? false) {
            logger.i('old token1: $token');
            token = responseData1.userInfo?.token!;
            logger.i('new token1: $token');
          }
        }
        if (responseData.businessUniqueId?.isNotEmpty ?? false) {
          return Tuple4(
              ret, responseData.responseDesc ?? '', responseData, null);
        }
        final responseData1 =
            LoginForSmsCodeResqonse1.fromJson(jsonDecode(decryptBody));
        return Tuple4(
            ret, responseData.responseDesc ?? '', null, responseData1);
      }

      return Tuple4(false, response.body, null, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple4(false, 'login err: $e', null, null);
    }
  }

  Future<Tuple3<bool, String, VerifyPinResqonse?>> verifyPin(
      String phoneNumber, String businessUniqueId, String pin) async {
    try {
      logger.i(
          'start verify pin: $phoneNumber, business uniqueId: $businessUniqueId, pin: $pin');
      final bodyTemp = getBodyTemplate1();
      final timestamp = bodyTemp['timestamp'];
      final encryptPin = _encryptPin(pin, timestamp);
      logger.i('encrypt pin: $encryptPin, timestamp: $timestamp');

      final response = await post(
        body: bodyTemp
          ..addAll({
            'commandId': 'RiskControlCheckVerifyPin',
            'businessUniqueId': businessUniqueId,
            'initiatorMSISDN': phoneNumber,
            'initiatorPin': encryptPin,
            'useDynamicCaller': "true",
          }),
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'RiskControlCheckVerifyPin',
        }),
        timestamp: timestamp,
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            VerifyPinResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0' &&
            responseData.isCorrect == "true";
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, VerifyPinResqonse?>> historyPinCheckIdentity(
      String phoneNumber, String pin) async {
    try {
      logger.i('start history verify pin: $phoneNumber, pin: $pin');
      final bodyTemp = getBodyTemplate1();
      final timestamp = bodyTemp['timestamp'];
      final encryptPin = _encryptPin(pin, timestamp);
      logger.i('encrypt pin: $encryptPin');

      final response = await post(
        body: bodyTemp
          ..addAll({
            'commandId': 'HistoryPinCheckIdentity',
            'businessScenario': 'history',
            'initiatorMSISDN': phoneNumber,
            'initiatorPin': encryptPin,
            'useDynamicCaller': "true",
          }),
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'HistoryPinCheckIdentity',
        }),
        timestamp: timestamp,
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            VerifyPinResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0' &&
            responseData.isCorrect == "true";
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, VerifyQrCodeResqonse?>> verifyQRCode(
      String phoneNumber, String serialNo, String businessUniqueId) async {
    try {
      logger.i(
          'start get qrcode, phoneNumber: $phoneNumber, serialNo: $serialNo, business uniqueId: $businessUniqueId');

      final response = await post(
        body: getBodyTemplate1()
          ..addAll({
            'commandId': 'RiskGetVerifyQRCodes',
            'businessUniqueId': businessUniqueId,
            'initiatorMSISDN': phoneNumber,
            'serialNo': serialNo,
          }),
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'RiskGetVerifyQRCodes',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            VerifyQrCodeResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, VerifyPinResqonse?>> finishQRCode(
      String phoneNumber, String serialNo, String businessUniqueId) async {
    try {
      logger.i(
          'finish qrcode, phoneNumber: $phoneNumber, serialNo: $serialNo, business uniqueId: $businessUniqueId');

      final response = await post(
        body: getBodyTemplate1()
          ..addAll({
            'commandId': 'RiskFinishVerifyQRCode',
            'businessUniqueId': businessUniqueId,
            'initiatorMSISDN': phoneNumber,
            'serialNo': serialNo,
          }),
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'RiskFinishVerifyQRCode',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            VerifyPinResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, VerifyPinResqonse?>> verifyNrc(
      String phoneNumber, String businessUniqueId, String idNumber) async {
    try {
      logger.i(
          'verify nrc, phoneNumber: $phoneNumber, idNumber: $idNumber, business uniqueId: $businessUniqueId');

      final response = await post(
        body: getBodyTemplate1()
          ..addAll({
            'commandId': 'RiskControlCheckVerifyNrc',
            'businessUniqueId': businessUniqueId,
            'initiatorMSISDN': phoneNumber,
            'idNumber': idNumber,
            // 'idType': 'Nrc',
            'idType': '01',
          }),
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'RiskControlCheckVerifyNrc',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            VerifyPinResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, LoginForSmsCodeResqonse1?>> queryLoginMode(
      String phoneNumber) async {
    try {
      logger.i('start queryLoginMode.phone number: $phoneNumber');
      final body = getBodyTemplate()
        ..addAll({
          'commandId': 'QueryLoginMode',
          'initiatorMSISDN': phoneNumber,
        });

      final response = await post(
        body: body,
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'QueryLoginMode',
        }),
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        return const Tuple3(true, '', null);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<Tuple3<bool, String, LoginForSmsCodeResqonse1?>> loginMsg1(
      String phoneNumber, String otpCode, String businessUniqueId) async {
    try {
      logger.i(
          'start login.phone number: $phoneNumber, otp code: $otpCode, businessUniqueId: $businessUniqueId');
      final body = getBodyTemplate()
        ..addAll({
          'commandId': 'LoginForSmsCode',
          // 'homeConfigVersion': '1.1.984',
          // 'myServiceVersion': '1.0.925',
          'homeConfigVersion': '',
          'myServiceVersion': '',
          'smsCode': otpCode,
          'initiatorMSISDN': phoneNumber,
          'businessUniqueId': businessUniqueId,
        });

      final response = await post(
        body: body,
        header: getTemplateHeader(true)..addAll({
          'KBZPay-Command-Id': 'LoginForSmsCode',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        //   'Messagetype': 'NEW',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return const Tuple3(false, 'request otp timeout', null);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            LoginForSmsCodeResqonse1.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        if (ret) {
          fullName = responseData.userInfo?.fullName ?? '';
        }
        return Tuple3(ret, responseData.responseDesc ?? '', responseData);
      }

      return Tuple3(false, response.body, null);
    } catch (e, stackTrace) {
      logger.e('login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return Tuple3(false, 'login err: $e', null);
    }
  }

  Future<bool> newAutoLoginMsg(
      String phoneNumber, String businessUniqueId, bool autoLogin) async {
    try {
      logger.i(
          'start new auto login.phone number: $phoneNumber, businessUniqueId: $businessUniqueId');

      final header = {'User-Agent': 'okhttp/4.10.0'};
      if (autoLogin) {
        // header['Messagetype'] = 'NEW';
      }

      final response = await post(
        body: getBodyTemplate()
          ..addAll({
            'commandId': 'NewAutoLogin',
            // 'homeConfigVersion': '1.1.985',
            // 'myServiceVersion': '1.0.926',
            'homeConfigVersion': '',
            'myServiceVersion': '',
            'deviceToken':
                'fVgN1aB3CdE:APA91bH7GhIjK8lMnOPQrStUVwXyZaBCDEfGHIJKLMNOPQRSTuvWXYZ_abcdefghijklmNOPQRSTUVWXyz1234567890',
            'initiatorMSISDN': phoneNumber,
            'businessUniqueId': businessUniqueId,
          }),
        header: header,
      );

      if (response is! http.Response) {
        EasyLoading.showError('new auto login timeout');
        logger.i('new auto login timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            LoginForSmsCodeResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        // if (ret) {
        //   token = responseData.token!;
        // }
        return ret;
      }

      return false;
    } catch (e, stackTrace) {
      logger.e('new auto login err: $e', stackTrace: stackTrace);
      EasyLoading.showError('new auto login err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    }
  }

  Future<bool> identityVerificationMsg(String phoneNumber, String id) async {
    try {
      logger.i('start identity verification: $phoneNumber, $id');

      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'IdentityVerification',
          body: {
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
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'IdentityVerification',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('identity verification timeout');
        logger.i('identity verification timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData = GeneralResqonse.fromJson(jsonDecode(decryptBody));
        return responseData.Response?.Body?.ResponseCode == '0';
      }

      return true;
    } catch (e, stackTrace) {
      logger.e('identity verification err: $e', stackTrace: stackTrace);
      EasyLoading.showError('identity verification err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<double?> queryCustomerBalanceMsg(
    String phoneNumber, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      logger.i('start query customer balance: $phoneNumber');

      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'QueryCustomerBalance',
          body: {
            'RequestDetail': {
              'Encoding': 'unicode',
              'QueryBalanceFlag': 'false',
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
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'QueryCustomerBalance',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('query customer balance timeout');
        logger.i('query customer balance timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance timeout.',
        ));
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');

        final responseData =
            QueryCustomerBalanceResqonse.fromJson(jsonDecode(decryptBody));
        if (responseData.Response!.Body!.ResponseCode == '0') {
          return double.parse(
              responseData.Response!.Body!.ResponseDetail!.Balance!);
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response decrypt: $decryptBody',
        ));
        return null;
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        final code = responseData.Response!.Body!.ResponseCode;
        if (code == 'AS403' || code == 'AS402') {
          invalid = true;
        }

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response: ${response.body}',
        ));
      }

      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('query customer balance err: $e', stackTrace: stackTrace);
      EasyLoading.showError('query customer balance err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'query balance err, err: $e, stack: $stackTrace',
      ));
    }
    return null;
  }

  Future<double?> pgWGetAccessToken(
    String phoneNumber, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      logger.i('start query customer balance: $phoneNumber');

      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'PGWGetAccessToken',
          body: {
            'RequestDetail': {
              'Encoding': 'unicode',
              'QueryBalanceFlag': 'false',
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
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'PGWGetAccessToken',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('query customer balance timeout');
        logger.i('query customer balance timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance timeout.',
        ));
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');

        final responseData =
            QueryCustomerBalanceResqonse.fromJson(jsonDecode(decryptBody));
        if (responseData.Response!.Body!.ResponseCode == '0') {
          return double.parse(
              responseData.Response!.Body!.ResponseDetail!.Balance!);
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response decrypt: $decryptBody',
        ));
        return null;
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        final code = responseData.Response!.Body!.ResponseCode;
        if (code == 'AS403' || code == 'AS402') {
          invalid = true;
        }

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response: ${response.body}',
        ));
      }

      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('query customer balance err: $e', stackTrace: stackTrace);
      EasyLoading.showError('query customer balance err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'query balance err, err: $e, stack: $stackTrace',
      ));
    }
    return null;
  }

  Future<double?> pgWGetAccessToken1(
    String phoneNumber, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      logger.i('start query customer balance: $phoneNumber');

      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'PGWGetAccessToken',
          body: {
            'RequestDetail': {
              'Merch_APPID': 'kpbe8dec8eb6e04bc19fbb5974fb32c0',
              'TradeType': 'APPH5',
              'IsGuest': "false",
            },
            'Identity': {
              'Initiator': {
                'Identifier': phoneNumber,
                'IdentifierType': '1',
              },
              'ReceiverParty': {
                'IdentifierType': '1',
              },
            }
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'PGWGetAccessToken',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('query customer balance timeout');
        logger.i('query customer balance timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance timeout.',
        ));
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');

        final responseData =
            QueryCustomerBalanceResqonse.fromJson(jsonDecode(decryptBody));
        if (responseData.Response!.Body!.ResponseCode == '0') {
          return double.parse(
              responseData.Response!.Body!.ResponseDetail!.Balance!);
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response decrypt: $decryptBody',
        ));
        return null;
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        final code = responseData.Response!.Body!.ResponseCode;
        if (code == 'AS403' || code == 'AS402') {
          invalid = true;
        }

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'query balance err, err: $e, response: ${response.body}',
        ));
      }

      // EasyLoading.showInfo('request otp success.');
      // logger.i('request otp success');
    } catch (e, stackTrace) {
      logger.e('query customer balance err: $e', stackTrace: stackTrace);
      EasyLoading.showError('query customer balance err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'query balance err, err: $e, stack: $stackTrace',
      ));
    }
    return null;
  }

  Future<List<NewTransRecordListResqonseTransRecordList>?>
      newTransRecordListMsg(
    String pin,
    String phoneNumber,
    int startNumber,
    int count, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    var ret = await _newTransRecordListMsg(phoneNumber, startNumber, count);
    if (ret?.needVerifyPin == 'true' || false) {
      await historyPinCheckIdentity(phoneNumber, pin);
      ret = await _newTransRecordListMsg(phoneNumber, startNumber, count);
    }
    if (ret == null || ret.transRecordList == null) return [];
    final records = ret.transRecordList!
        // .where((record) => record != null && record.amount! > 0)
        .where((record) => record != null)
        .cast<NewTransRecordListResqonseTransRecordList>()
        .toList()
      ..sort((a, b) => a.compareTo(b));
    return records;
  }

  Future<NewTransRecordListResqonse?> _newTransRecordListMsg(
    String phoneNumber,
    int startNumber,
    int count, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      logger.i(
          'start new trans record list msg.phone number: $phoneNumber, s: $startNumber, cnt: $count');

      // final header = {
      //   'User-Agent': 'okhttp-okgo/jeasonlzy',
      //   'Messagetype': 'NEW',
      // };

      final header = getTemplateHeader(true)..addAll({
        'KBZPay-Command-Id': 'NewTransRecordList',
      });

      final response = await post(
        body: getBodyTemplate1()
          ..addAll({
            'startNum': startNumber,
            'count': count,
            'needTotalAmount': startNumber != 0,
            'filterTypes': [],
            'isHomePage': 'false',
            'commandId': 'NewTransRecordList',
            'initiatorMSISDN': phoneNumber,
            "direction": "",
            "toDate": 0,
            "fromDate": 0,
            "maxAmount": "",
            "minAmount": "",
            "oppositeMsisdn": "",
            "oppositePartyId": "",
            "oppositeShortCode": "",
          }),
        header: header,
      );

      if (response is! http.Response) {
        EasyLoading.showError('new trans record list msg timeout');
        logger.i('new trans record list msg timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'get record list timeout, s: $startNumber, count: $count',
        ));
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            NewTransRecordListResqonse.fromJson(jsonDecode(decryptBody));
        final ret = responseData.responseCode == '0';
        if (ret) {
          // final records = responseData.transRecordList!
          //     // .where((record) => record != null && record.amount! > 0)
          //     .where((record) => record != null)
          //     .cast<NewTransRecordListResqonseTransRecordList>()
          //     .toList()
          //   ..sort((a, b) => a.compareTo(b));
          return responseData;
          // return records;
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'get record list fail, s: $startNumber, count: $count, response decrypt: $decryptBody',
        ));
        return null;
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        if (responseData.Response?.Body?.ResponseCode == 'AS403' || false) {
          invalid = true;
        }

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'get record list fail, s: $startNumber, count: $count, response: ${response.body}',
        ));
      }

      return null;
    } catch (e, stackTrace) {
      logger.e('new trans record list msg err: $e', stackTrace: stackTrace);
      EasyLoading.showError('new trans record list msg err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'get record list fail, s: $startNumber, count: $count, err: $e, stack: $stackTrace',
      ));
      return null;
    }
  }

  final verifiedAccounts = <String>{};

  /// ret: hasNoErr, checkResult
  Future<Tuple2<bool, bool>> checkAccount(
    String phoneNumber,
    String receiverAccount, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      if (!receiverAccount.startsWith('0')) {
        receiverAccount = '0$receiverAccount';
      }
      if (verifiedAccounts.contains(receiverAccount)) {
        logger.i('account has verified: $receiverAccount');
        return const Tuple2(true, true);
      }
      logger.i('check account: $phoneNumber, r: $receiverAccount');
      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondId: 'GetUserInfo',
          body: {
            'RequestDetail': {
              'Encoding': 'unicode',
              'Msisdn': receiverAccount,
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
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'GetUserInfo',
        }),
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('check account timeout');
        logger.i('check account timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'check account timeout, dest: $receiverAccount',
        ));
        return const Tuple2(false, false);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');

        final responseData =
            QueryCustomerBalanceResqonse.fromJson(jsonDecode(decryptBody));

        if (responseData.Response!.Body!.ResponseCode == '0' &&
            responseData.Response!.Body!.ResponseDetail!.ResultCode == '0') {
          onLogged?.call(LogItem(
            type: LogItemType.info,
            platformName: account?.platformName ?? '',
            platformKey: account?.platformKey ?? '',
            phone: phoneNumber,
            time: DateTime.now(),
            content:
                'check account success, dest: $receiverAccount, response data: $decryptBody',
          ));
          verifiedAccounts.add(receiverAccount);
          return const Tuple2(true, true);
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'check account fail, dest: $receiverAccount, response data: ${response.body}, response decrypt: $decryptBody',
        ));
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        if (responseData.Response!.Body!.ResponseCode == 'AS403') {
          invalid = true;
        }

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'check account fail, dest: $receiverAccount, response: ${response.body}',
        ));
      }
    } catch (e, stackTrace) {
      logger.e('check account err: $e', stackTrace: stackTrace);
      EasyLoading.showError('check account err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'check account fail, dest: $receiverAccount, err: $e, stack: $stackTrace',
      ));
    }
    return const Tuple2(true, false);
  }

  Future<bool> transferToAccount(
    String pin,
    String phoneNumber,
    String receiverAccount,
    String amount,
    String note,
    String prepayId,
    // String balanceStr,
  ) async {
    try {
      logger.i(
          'start transferToAccount.pin: $pin, phone number: $phoneNumber, receiverAccount: $receiverAccount, amount: $amount, note: $note, prepayId: $prepayId');

      final header = getTemplateHeader(true)..addAll({
        'KBZPay-Command-Id': 'PayOrder.TransferToAccount',
      });

      final bodyTemp = getBodyTemplate1();
      final timestamp = bodyTemp['timestamp'];
      final encryptPin = _encryptPin(pin, timestamp);


      final response = await post(
        body: bodyTemp
          ..addAll({
            'additionalParam': {},
            "extendParams": {"amount": amount, "transNote": note},
            "payMethod": {
              "alpha": 1.0,
              "available": "true",
              "displayIcon": "https://static.kbzpay.com/app/prod/res/img/pgwtc/balance_icon.png",
              "displayInfo": "余额",
              "isSelect": true,
              "odActivate": false,
              "payMethod": "PAY_BY_WALLET",
              "selected": "true",
              // "supplementInfo": "<font color='#808080'>$balanceStr</font>"
            },
            "prepayId": prepayId,
            "referenceData": {"authType":"PIN","qrOrigin":""},
            'commandId': 'PayOrder.TransferToAccount',
            "supportMultiPayMethod":"true",
            'initiatorMSISDN': phoneNumber,
            "initiatorPin": encryptPin,
            'receiverMSISDN': receiverAccount,
            "useDynamicCaller": "true",
          }),
        header: header,
      );

      if (response is! http.Response) {
        EasyLoading.showError('new trans record list msg timeout');
        logger.i('new trans record list msg timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseJson = jsonDecode(decryptBody);

        final ret = responseJson['responseCode'] == '0';
        return ret;

      } 
    } catch (e, stackTrace) {
      logger.e('new trans record list msg err: $e', stackTrace: stackTrace);
      EasyLoading.showError('new trans record list msg err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }

    return false;
  }

  Future<Tuple2<bool, String>> preCheckoutTransferToAccount(
    String phoneNumber,
    String receiverAccount,
    String amount,
    String note,
  ) async {
    if (note.isEmpty) note = 'n';
    try {
      logger.i(
          'start preCheckoutTransferToAccount.phone number: $phoneNumber, receiverAccount: $receiverAccount, amount: $amount, note: $note');

      final header = getTemplateHeader(true)..addAll({
        'KBZPay-Command-Id': 'PreCheckout.TransferToAccount',
      });

      final response = await post(
        body: getBodyTemplate1()
          ..addAll({
            'amount': amount,
            'note': note,
            "referenceData": {"authType":"PIN","qrOrigin":""},
            "supportMultiPayMethod":"true",
            'commandId': 'PreCheckout.TransferToAccount',
            'initiatorMSISDN': phoneNumber,
            'receiverMSISDN': receiverAccount,
          }),
        header: header,
      );

      if (response is! http.Response) {
        EasyLoading.showError('new trans record list msg timeout');
        logger.i('new trans record list msg timeout');
        return const Tuple2(false, "");
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseJson = jsonDecode(decryptBody);

        final ret = responseJson['responseCode'] == '0';
        if (ret) {
          final prepayId = responseJson['prepayId'] as String;
          // final balanceStr = responseJson['availablePayMethods'][0]['supplementInfo'];
          return Tuple2(true, prepayId);
        }

      } 
    } catch (e, stackTrace) {
      logger.e('new trans record list msg err: $e', stackTrace: stackTrace);
      EasyLoading.showError('new trans record list msg err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }

    return const Tuple2(false, "");
  }

  Future<Tuple2<bool, String>> transferMsg(
    String pin,
    String phoneNumber,
    String receiverAccount,
    String amount,
    String transNote, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      if (!receiverAccount.startsWith('0')) {
        receiverAccount = '0$receiverAccount';
      }
      logger.i(
          'start transfer: $phoneNumber, r: $receiverAccount, amount: $amount, note: $transNote');
      final bodyTemp = getBodyTemplate1();
      final timestamp = bodyTemp['timestamp'];
      final encryptPin = _encryptPin(pin, timestamp);
      // todo time stamp need same.
      final response = await post(
        body: getBodyTemplateContainsHeaders(
          useDynamicCaller: true,
          commondId: 'TransferToAccount',
          body: {
            'RequestDetail': {
              'Amount': amount,
              'Encoding': 'unicode',
              'FromName': fullName,
              'ReceiverType': '1',
              'TransNote': transNote,
              'isLiveDb': false,
            },
            'Identity': {
              'Initiator': {
                'Identifier': phoneNumber,
                'IdentifierType': '1',
                'SecurityCredential': encryptPin,
              },
              'ReceiverParty': {
                'Identifier': receiverAccount,
                'IdentifierType': '1',
              },
            }
          },
        ),
        header: getTemplateHeader(false)..addAll({
          'KBZPay-Command-Id': 'TransferToAccount',
        }),
        timestamp: timestamp,
        // header: {
        //   'User-Agent': 'okhttp/4.10.0',
        // },
      );

      if (response is! http.Response) {
        EasyLoading.showError('transfer timeout');
        logger.i('transfer timeout');
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'transfer timeout, dest: $receiverAccount, amount: $amount',
        ));
        return const Tuple2(false, '');
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');

        final responseData =
            TransferToAccountResqonse.fromJson(jsonDecode(decryptBody));

        if (responseData.Response!.Body!.ResponseCode == '0'
            // && responseData.Response!.Body!.ResponseDetail!.ResultCode == '0'
            ) {
          onLogged?.call(LogItem(
            type: LogItemType.send,
            platformName: account?.platformName ?? '',
            platformKey: account?.platformKey ?? '',
            phone: phoneNumber,
            time: DateTime.now(),
            content:
                'transfer success, dest: $receiverAccount, amount: $amount, response data: $decryptBody',
          ));
          return Tuple2(
              true, responseData.Response!.Body!.ResponseDetail!.OrderNo!);
        }
        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'transfer fail, dest: $receiverAccount, amount: $amount, response data: ${response.body}, response decrypt: $decryptBody',
        ));
      } else {
        final responseData = ErrResponse.fromJson(jsonDecode(response.body));
        if (responseData.Response!.Body!.ResponseCode == 'AS403') {
          invalid = true;
        }
        // final decryptDesc = AesHelper.decrypt(
        //     responseData.Response!.Body!.ResponseDesc!, aesKey, ivKey);
        // logger.i('decrypt desc: $decryptDesc');

        onLogged?.call(LogItem(
          type: LogItemType.err,
          platformName: account?.platformName ?? '',
          platformKey: account?.platformKey ?? '',
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'transfer fail, dest: $receiverAccount, amount: $amount, response: ${response.body}',
        ));
      }
    } catch (e, stackTrace) {
      logger.e('transfer err: $e', stackTrace: stackTrace);
      EasyLoading.showError('transfer err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged?.call(LogItem(
        type: LogItemType.err,
        platformName: account?.platformName ?? '',
        platformKey: account?.platformKey ?? '',
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'transfer fail, dest: $receiverAccount, amount: $amount, err: $e, stack: $stackTrace',
      ));
    }
    return const Tuple2(false, '');
  }
}
