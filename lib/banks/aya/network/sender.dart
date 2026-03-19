import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/aya/config/config.dart';
import 'package:auto_report/banks/aya/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';

class Sender {
  final String firebase;
  String authorization;
  final String sentryTrace;
  final String baggage;
  final String deviceId;
  final String deviceName;

  // String? token;
  // String? miPush;
  // String? fullName;

  bool invalid = false;

  int timeDiff = 0;

  Sender({
    required this.firebase,
    required this.deviceId,
    required this.deviceName,
    required this.authorization,
    required this.sentryTrace,
    required this.baggage,
  });

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

  // String timestamp = '1766640002094';

  Future post(
      {
        required String body,
        required Map<String, String> header,
        required String address,
      }) async {
    // final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';

    final url = Uri.https(Config.host, address);
 
    // logger.i('aesKey base64: $aesKey, iv: $ivKey');

    // final sortedBody = sortKeys(body);
    // final bodyContent = jsonEncode(sortedBody);
    // final signContent = timestamp + ivKey + bodyContent;
    // var sign =
    //     ShaHelper.hashMacSha256(signContent, aesKey);

    // var encryptBody = AesHelper.encryptGCM(bodyContent, aesKey, ivKey);
    // // encryptBody = "onqsPmB00s6qhreb4QCP6L2wRpRAdpRPvbP4BwoyO7CKiC/v7BsO3ELZYgx5ThcWO3+VjvWdJZuVT8+VJBhNuJvaOcPwDMbr2SA2lGoW+vBP0wEZ/Ipog9lRiY6VlCvY3L8e5K87Xuw8wHQx20b1Lsc+Pdp4pit2Ab6cMpLwvvVZJqtRc4u4kjnHPAqRWrhSh7/D/acf2lWb/wdGJc8ksaVrXMbzrQBdAH9Db0Zf3yyyQIb5N/+j2zeb0X5sGvSCkyZ0plfjwJaUZKfP37X4ZVLyqu8i66yPPXxHlVn1XWQv8GwFaeiu9DfXOpQ6LXsKxZqVwVO+sOQyVPVIxS2QgrvkPsBIz1K/mJNXzx/MDqPcgGJ2kvEpv5mv23gZC/0ZQChW0L0Sy2c=";
    
    // // logger.i('timestamp: $timestamp');
    // // logger.i('encryptBody: $encryptBody');
    // // logger.i('signContent: $signContent');
    // // logger.i('sign: $sign');
    // // sign = "000d3e7610a4a80294ea94d855a9c4a718f5f2478d85c68bd538a66897900ec6";

    // // return;
    // // test.
    // // const encryptKey = "iZcNfJ2cc9p0npzXN9oa5Gy6dzAHbRM8JkiJda2xClcMWS8iWSwk8e5/uTQ+/Y1fioWL7/40wlmbRzLh4JjTjepmS/FmjIzVXdy2aj/2f/7Y9RfxBPBb/Ixi8eCvUgS1wqtZ4oixJL2+kJYD8sWlmOqySnKWiyKVNomkGkhfussReyMbxhRAhFcdGLv0Hl959Agrf4+5I6vzoeJbictlxzujlCrB/IGe9NNGjL+dE/cBnyDlWvSRTLyPLB6wD8cGNkU6M/42BqWClcsOHjUhj1JCFPPrUaPM71GpamFy3XyuBZRU+6srH3FysN0FdXfuU7JyvmXovo5XVI10X1iaLw==";
    // // const encryptIV = "HpWmIbfJugUzuwVfD1JMrKzXjWt8jXgJjEpEwuH0cSK2MzIvqELaYAwVEnTBQd1Y/Do6yd+6lerjlL5QaqJNfNySc1NjA20HA7LYA6h8WTvwx6vkhG7HDAHqlSuhSr52gkEzvbm0g35ZajkTt3bSLwLbbZ0k6rfdzdE+1fVflKaKJ4IEk5ms4iVua1IktimOXheCsK7EOAmGAuAczorUbXONrsrAkQDIapZv4ZEKPqJc5SGvUZMtsQOekHw+ZgLNYwv4H5h0IjqxgEhxXkG35N0mcykbi5onm4cErIDPJ/3r8pHApCg+3w7yoUH2wzQFodhdWIExM81lwS8kr8GwkQ==";
    // // const sign = "096c6a6eda0edc808f1efc73d876412ce6f3727ef60507379185bb4d5b50a9b9";
    // // const encryptBody = "/BmCWLONIK9/wM0F8O0XJZkfZXQimiG0w/imkr68u02ZdSaOWVtth4dmPBpCe/MZkjKzemYOYGYqck28b8ZdYzJ+ilmZNHEBqXyn3vmSaabBikEKLEWsMq9C7u/HYn3VkoIYyhIlLXlhvojsIIxNSMBcl0OtfLikQ9UvToHoaJC7nFjtoKxXYD5pNFCZPdvgqhC7R0ZhotanPj7+UkiqwSrGKHli+4tmksZA7ZLP0HpIoVTjYEKMz2nm2dxRu4HleF3GUXGM0FBOuYeMwoLga5jvxyp5I/6QKpQozBSXwin886femEloeqa9mXpUU8XAsYPo4PSVrdBOiGpLP4w2VMFyX79lp/2B1kna2nRPinHjmdAgtSyVHbmi3AnV0nUPyHFfqd8Tro4=";
    
    // final headers = Config.getHeaders()
    //   ..addAll(header)
    //   ..addAll({
    //     'Authorization': aesKeyRSA,
    //     'IvKey': ivKeyRSA,
    //     'Sign': sign,
    //     'Timestamp': timestamp,
    //   });

    logger.i('request headers: $header');
    // // logger.i('request body: $sortedBody');
    logger.i('request body content: $body');

    return await Future.any([
      http.post(url, headers: header, body: body),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);
  }

  Map<String, String> getTemplateHeader() {
    var headers = {
        'Content-Type': 'application/json;charset=utf-8',
        'Version': Config.appVersion,
        'Accept-Language': Config.language,
        'Authorization': authorization,
        'Sentry-Trace': sentryTrace,
        'Baggage': baggage,
        'User-Agent': 'okhttp/4.12.0',
      };

    // if (needNew) {
    //   headers['MessageType'] = 'NEW';
    // }
    return headers;
  }


  Map<String, dynamic> getBodyTemplate() {
    return {
      'deviceID': deviceId,
      'deviceName': deviceName,
      'os': Config.osType,
      'osVersion': Config.osVersion,
      'appVersion': Config.appVersion,
      'firebaseToken': firebase,
    };
  }

  Map<String, dynamic> getBodyTemplateContainsHeaders({
    required String commondId,
    required Map<dynamic, dynamic> body,
  }) {
    final timestamp =
        '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
    return {
      'Request': {
        'Header': {
          "CommandID": commondId,
          "ClientType": Config.osType,
          "Language": Config.language,
          "Version": Config.appversion,
          "OriginatorConversationID": const Uuid().v4(),
          // "DeviceID": deviceId,
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

  Future<bool> sendDeviceInfo() async {
    try {
      logger.i('start sendDeviceInfo');

      // final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
      // final timestamp = '1766641597819';
      final body = {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'os': Config.osType,
        'osVersion': Config.osVersion,
        'appVersion': Config.appVersion,
        'firebaseToken': firebase,
        'lat': 0,
        'long': 0,
      };

      final bodyContent = jsonEncode(body);
      // logger.i('bodyContent: $bodyContent');

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/sendDeviceInfo',
      );

      if (response is! http.Response) {
        EasyLoading.showError('sendDeviceInfo timeout');
        logger.i('sendDeviceInfo timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      var errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      return errCode == 200;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<bool> checkPhone({required String phone,}) async {
    try {
      logger.i('start checkPhone');

      // final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
      // final timestamp = '1766641597819';
      final body = {
        'phone': phone,
      };

      final bodyContent = jsonEncode(body);
      // logger.i('bodyContent: $bodyContent');

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/checkPhone',
      );

      if (response is! http.Response) {
        EasyLoading.showError('checkPhone timeout');
        logger.i('checkPhone timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      var errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      // {"err":8004,"message":"Phone number is already registered "}
      return errCode == 200 || errCode == 8004;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  // isSuccess: true, isAuthedByOldDevices: true
  Future<Tuple2<bool, bool>> login({
    required String phone,
    required String password,
  }) async {
    try {
      logger.i('start login');

      // final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
      // final timestamp = '1766641597819';
      final body = {
        'deviceId': deviceId,
        'phone': phone,
        'password': password,
      };

      final bodyContent = jsonEncode(body);
      // logger.i('bodyContent: $bodyContent');

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/login',
      );

      if (response is! http.Response) {
        EasyLoading.showError('login timeout');
        logger.i('login timeout');
        return const Tuple2(false, false);
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      final errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      final isSuccess = errCode == 200;
      var isAuthedByOldDevices = false;

      if (isSuccess) {
        final tokenObj = responseData['token'];
        if (tokenObj != null) {
          final tokenStr = tokenObj['token'];
          logger.i('tokenStr: $tokenStr');
          authorization = 'Bearer $tokenStr';
          isAuthedByOldDevices = true;
        }
      }

      return isSuccess
          ? Tuple2(true, isAuthedByOldDevices)
          : const Tuple2(false, false);
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return const Tuple2(false, false);
  }

  Future<bool> getDefaultSMS({
    required String phone,
  }) async {
    try {
      logger.i('start getDefaultSMS');

      // final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';
      // final timestamp = '1766641597819';
      final body = {
        'phone': phone,
      };

      final bodyContent = jsonEncode(body);
      // logger.i('bodyContent: $bodyContent');

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/getDefaultSMS',
      );

      if (response is! http.Response) {
        EasyLoading.showError('getDefaultSMS timeout');
        logger.i('getDefaultSMS timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      final errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      return errCode == 200;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<bool> loginVerifyOTP({
    required String phone,
    required String otp,
  }) async {
    try {
      logger.i('start loginVerifyOTP');
      final body = {
        'phone': phone,
        'otp': otp,
        'deviceId': deviceId,
        'firebaseToken': firebase,
      };

      final bodyContent = jsonEncode(body);

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/v2/loginVerifyOTP',
      );

      if (response is! http.Response) {
        EasyLoading.showError('loginVerifyOTP timeout');
        logger.i('loginVerifyOTP timeout');
        return false;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      var errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      // Response body: {"err":200,"message":"Success","profile":{"name":"HLA HLA MON","phone":"09429792618","id":"685101c04a9adf6a08b8fdc5"},"oldDeviceInfo":{"id":"67fa2aa86793bcb035a55d8c","os":"android","osVersion":"14","lat":0,"long":0,"deviceName":"Redmi 23053RN02A","ip":"183.182.123.181","status":"active"}}

      return errCode == 200;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  Future<double?> getBalance() async {
    try {
      logger.i('start getBalance');
      final body = {
      };

      final bodyContent = jsonEncode(body);
      // logger.i('bodyContent: $bodyContent');

      final response = await post(
        body: bodyContent,
        header: getTemplateHeader(),
        address: '/api/user/getBalance',
      );

      if (response is! http.Response) {
        EasyLoading.showError('getBalance timeout');
        logger.i('getBalance timeout');
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');
      logger.i('Response body: ${response.body}');

      final responseData = jsonDecode(response.body);
      final errCode = responseData['err'];
      logger.i('Response err code: $errCode');

      if (errCode == 200) {
        final balanceStr = responseData['data']['balance'];
        logger.i('balanceStr: $balanceStr');
        return double.parse('$balanceStr');
      }
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return null;
  }

  Future<List<NewTransRecordListResqonseTransRecordList>?> transHistory({
    required int pageParam,
    required int start,
    required int number,
    }) async {
      try {
        logger.i('start transHistory');

        final now = DateTime.now();
        final yesterday = now.subtract(const Duration(days: 1));
        final tomorrow = now.add(const Duration(days: 1));

        String formatDate(DateTime d) {
          return '${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}/${d.year}';
        }

        final startDate = formatDate(yesterday);
        final endDate = formatDate(tomorrow);

        final body = {
          'pageParam': pageParam,
          'start': start,
          'number': number,
          'startDate': startDate,
          'endDate': endDate,
        };

        final bodyContent = jsonEncode(body);

        final response = await post(
          body: bodyContent,
          header: getTemplateHeader(),
          address: '/api/transaction/transHistory',
        );

        if (response is! http.Response) {
          EasyLoading.showError('transHistory timeout');
          logger.i('transHistory timeout');
          return null;
        }

        logger.i('Response status: ${response.statusCode}');
        logger.i('Response headers: ${response.headers}');
        logger.i('Response body: ${response.body}');

        final responseData = jsonDecode(response.body);
        final errCode = responseData['err'];
        logger.i('Response err code: $errCode');

        if (errCode == 200) {
          final parsed = NewTransRecordListResqonse.fromJson(responseData);
          final records = parsed.transRecordList
              ?.where((e) => e != null)
              .cast<NewTransRecordListResqonseTransRecordList>()
              .toList() ?? [];
          logger.i('transHistory parsed ${records.length} records');
          return records;
        }
      } catch (e, stackTrace) {
        logger.e('transHistory err: $e', stackTrace: stackTrace);
        EasyLoading.showError('request err, code: $e',
            dismissOnTap: true, duration: const Duration(seconds: 60));
      }
      return null;
    }

}
