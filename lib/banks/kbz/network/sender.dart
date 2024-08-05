import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/account/account_data.dart';
import 'package:auto_report/banks/kbz/data/log/log_item.dart';
import 'package:auto_report/banks/kbz/data/proto/response/err_response.dart';
import 'package:auto_report/banks/kbz/data/proto/response/general_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/guest_login_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/login_for_sms_code_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/banks/kbz/data/proto/response/query_customer_balance_resqonse.dart';
import 'package:auto_report/banks/kbz/utils/aes_helper.dart';
import 'package:auto_report/banks/kbz/utils/sha_helper.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:flutter/widgets.dart';
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

  String? token;
  String? miPush;
  String? fullName;

  bool invalid = false;

  Sender({
    required this.aesKey,
    required this.ivKey,
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

  Future post(
      {required Map<String, dynamic> body,
      required Map<String, String> header}) async {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final url = Uri.https(Config.host, 'api/interface/version1.1/customer');
    final encryptKey = RSAHelper.encrypt(aesKey, Config.rsaPublicKey);
    final encryptIV = RSAHelper.encrypt(ivKey, Config.rsaPublicKey);

    final sortedBody = sortKeys(body);
    final bodyContent = jsonEncode(sortedBody);
    final sign =
        ShaHelper.hashMacSha256(timestamp + ivKey + bodyContent, aesKey);

    final encryptBody = AesHelper.encrypt(bodyContent, aesKey, ivKey);
    final headers = Config.getHeaders()
      ..addAll(header)
      ..addAll({
        'Authorization': encryptKey,
        'IvKey': encryptIV,
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

  Map<String, dynamic> getBodyTemplate() {
    return getBodyTemplate1()
      ..addAll({
        'brand': 'google',
        'deviceModel': model,
        'deviceToken': '',
        'miPushRegisterId': miPush,
        'networkMode': 'wifi',
        'osVersion': 'Android11',
        'resolution': '2160x1080',
        'supportGoogleService': 'false',
      });
  }

  Map<String, dynamic> getBodyTemplate1() {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    return {
      'deviceID': deviceId,
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
    required String commondid,
    required Map<dynamic, dynamic> body,
  }) {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    return {
      'Request': {
        'Header': {
          "CommandID": commondid,
          "ClientType": Config.osType,
          "Language": Config.language,
          "Version": Config.versioncode,
          "OriginatorConversationID": const Uuid().v4(),
          "DeviceID": deviceId,
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
          'User-Agent': 'okhttp-okgo/jeasonlzy',
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

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        final responseData =
            GuestLoginResqonse.fromJson(jsonDecode(decryptBody));

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
          commondid: 'SMSVerificationCode',
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
        header: {
          'User-Agent': 'okhttp/4.10.0',
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

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
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

      final response = await post(
        body: getBodyTemplate()
          ..addAll({
            'commandId': 'LoginForSmsCode',
            'homeConfigVersion': '1.1.984',
            'myServiceVersion': '1.0.925',
            'smsCode': otpCode,
            'initiatorMSISDN': phoneNumber,
          }),
        header: {
          'User-Agent': 'okhttp/4.10.0',
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

      if (response.headers['isencrypt']?.toLowerCase() == 'true') {
        final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
        logger.i('decrypt body: $decryptBody');
        final responseData =
            LoginForSmsCodeResqonse.fromJson(jsonDecode(decryptBody));
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

  Future<bool> newAutoLoginMsg(String phoneNumber, bool autoLogin) async {
    try {
      logger.i('start new auto login.phone number: $phoneNumber');

      final header = {'User-Agent': 'okhttp/4.10.0'};
      if (autoLogin) {
        header['Messagetype'] = 'NEW';
      }

      final response = await post(
        body: getBodyTemplate()
          ..addAll({
            'commandId': 'NewAutoLogin',
            'homeConfigVersion': '1.1.985',
            'myServiceVersion': '1.0.926',
            'initiatorMSISDN': phoneNumber,
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
        if (ret) {
          token = responseData.token!;
        }
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
          commondid: 'IdentityVerification',
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
        header: {
          'User-Agent': 'okhttp/4.10.0',
        },
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
          commondid: 'QueryCustomerBalance',
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
        header: {
          'User-Agent': 'okhttp/4.10.0',
        },
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
        if (responseData.Response!.Body!.ResponseCode == 'AS403') {
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
    String phoneNumber,
    int startNumber,
    int count, {
    ValueChanged<LogItem>? onLogged,
    AccountData? account,
  }) async {
    try {
      logger.i(
          'start new trans record list msg.phone number: $phoneNumber, s: $startNumber, cnt: $count');

      final header = {
        'User-Agent': 'okhttp-okgo/jeasonlzy',
        'Messagetype': 'NEW',
      };

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
          final records = responseData.transRecordList!
              // .where((record) => record != null && record.amount! > 0)
              .where((record) => record != null)
              .cast<NewTransRecordListResqonseTransRecordList>()
              .toList()
            ..sort((a, b) => a.compareTo(b));
          return records;
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
          commondid: 'GetUserInfo',
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
        header: {
          'User-Agent': 'okhttp/4.10.0',
        },
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

  Future<bool> transferMsg(
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
      final encryptPin = RSAHelper.encrypt(pin, Config.pinPublicKey);
      final response = await post(
        body: getBodyTemplateContainsHeaders(
          commondid: 'TransferToAccount',
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
        header: {
          'User-Agent': 'okhttp/4.10.0',
        },
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
        return false;
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
            type: LogItemType.send,
            platformName: account?.platformName ?? '',
            platformKey: account?.platformKey ?? '',
            phone: phoneNumber,
            time: DateTime.now(),
            content:
                'transfer success, dest: $receiverAccount, amount: $amount, response data: $decryptBody',
          ));
          return true;
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
    return false;
  }
}
