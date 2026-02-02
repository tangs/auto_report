import 'dart:math';

import 'package:auto_report/banks/aya/config/config.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';
import 'package:uuid/uuid.dart';

class Sender {
  final String firebase;
  // final String aesKeyRSA;
  // final String ivKey;
  // final String ivKeyRSA;
  // final String deviceId;
  // final String uuid;
  // final String model;

  String? token;
  String? miPush;
  String? fullName;

  bool invalid = false;

  int timeDiff = 0;

  Sender({
    required this.firebase,
    // required this.aesKeyRSA,
    // required this.ivKey,
    // required this.ivKeyRSA,
    // required this.deviceId,
    // required this.uuid,
    // required this.model,
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

  // String timestamp = '1766640002094';

  Future post(
      {required Map<String, dynamic> body,
      required Map<String, String> header}) async {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch + timeDiff}';

    final url = Uri.https(Config.host, 'api/interface/version1.3/customer');
 
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

    // logger.i('request headers: $headers');
    // // logger.i('request body: $sortedBody');
    // logger.i('request body content: $bodyContent');

    return await Future.any([
      // http.post(url, headers: headers, body: encryptBody),
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
        // 'deviceModel': model,
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
      // 'deviceID': deviceId,
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
          // 'deviceID': deviceId,
          'encoding': 'unicode',
          // 'initiatorMSISDN': 'Guest_$deviceId',
          'language': Config.language,
          // 'originatorConversationID': uuid,
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

      // if (response.headers['isencrypt']?.toLowerCase() == 'true') {
      //   // var aesKey =  "rMtQ0gbqicreL4SR/vzkij0ugUcVop7Y/9h719vRHUY=";
      //   // var ivKey = "d3d5b0fb2b53b5620c246ee1a99bb28f33364348445e1c85d0b8ff899fa2119d";

      //   final decryptBody = AesHelper.decrypt(response.body, aesKey, ivKey);
      //   final responseData =
      //       GuestLoginResqonse.fromJson(jsonDecode(decryptBody));

      //   logger.i('decrypt body: $decryptBody');
      //   logger.i('guest token: ${responseData.guestToken}');
      //   logger.i('server timestamp: ${responseData.serverTimestamp}');
      //   token = responseData.guestToken!;
      //   return responseData.responseCode == '0';
      // }

      // EasyLoading.showInfo('geust login success.');
      // logger.i('geust login success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

}
