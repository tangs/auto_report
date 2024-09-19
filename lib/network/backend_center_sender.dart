import 'dart:convert';
import 'dart:ui';

import 'package:auto_report/banks/wave/config/config.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:localstorage/localstorage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/v4.dart';

enum AuthVerifyResult {
  success,
  fail,
  wait,
  err,
}

class BackendCenterSender {
  static const _deviceIdKey = 'BackendCenterSender_DeviceId';
  static const _host = "tgsanfang.com";
  // static const _host = "baidu.com:335";

  static final _deviceId = _genDevieId();

  static _genDevieId() {
    var deviceId = localStorage.getItem(_deviceIdKey);
    if (deviceId != null) return;

    deviceId = const UuidV4().generate();
    Logger().i('gen device id: $deviceId');
    localStorage.setItem(_deviceIdKey, deviceId);
    return deviceId;
  }

  // todo
  get isInvalid => false;

  Future<http.Response?> _post({
    required String path,
    Object? body,
  }) async {
    try {
      final url = Uri.http(_host, path);
      logger.i('url: ${url.toString()}');
      logger.i('host: $_host, path: $path');
      final response = await Future.any([
        http.post(url, body: body),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);
      return response;
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
      return null;
    }
  }

  Future<bool> auth({
    required String account,
    VoidCallback? dataUpdated,
  }) async {
    try {
      final response = await _post(path: 'tool_apply', body: {
        'device_id': _deviceId,
        'account': account,
      });

      if (response == null) return false;

      final body = response.body;
      logger.i('res body: $body');

      final res = ReportGeneralResponse.fromJson(jsonDecode(body));
      if (res.status == 'T' && res.message == 'success' ||
          res.message == 'repeat') {
        dataUpdated?.call();
        return true;
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    }
    return false;
  }

  Future<AuthVerifyResult> authVerify({
    required String account,
    VoidCallback? dataUpdated,
  }) async {
    try {
      final response = await _post(path: 'tool_verify', body: {
        'device_id': _deviceId,
        'account': account,
      });

      if (response == null) return AuthVerifyResult.err;

      final body = response.body;
      logger.i('res body: $body');

      final res = ReportGeneralResponse.fromJson(jsonDecode(body));
      if (res.status == 'T' && res.message == 'success') {
        dataUpdated?.call();
        return AuthVerifyResult.success;
      }

      if (res.message == 'wait') {
        return AuthVerifyResult.wait;
      }

      return AuthVerifyResult.fail;
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      return AuthVerifyResult.err;
    }
  }

  Future<bool> authAndVerify({
    required String account,
    required int verfyWaitSeconds,
    required int queryVerifyTimes,
  }) async {
    final authRet = await auth(account: account);
    if (!authRet) return false;

    for (var i = 0; i < queryVerifyTimes; ++i) {
      final result = await authVerify(account: account);
      Logger().i('auth verify result: $result');

      if (result != AuthVerifyResult.wait) {
        return result == AuthVerifyResult.success;
      }

      await Future.delayed(Duration(seconds: verfyWaitSeconds));
    }

    return false;
  }

  Future<bool> depositSubmit({
    required String type,
    required String account,
    required String payId,
    required String payOrder,
    required String payCard,
    required String payMoney,
    String? payName,
    String? bankTime,
  }) async {
    try {
      final response = await _post(
        path: 'tool_submit',
        body: {
          'type': type,
          'device_id': _deviceId,
          'account': account,
          'pay_id': payId,
          'pay_order': payOrder,
          'pay_card': payCard,
          'pay_money': payMoney,
          'pay_name': payName,
          'bank_time': bankTime,
        }..removeWhere((k, v) => v == null),
      );

      if (response == null) return false;

      final body = response.body;
      logger.i('res body: $body');

      final res = ReportGeneralResponse.fromJson(jsonDecode(body));
      if (res.status == 'T' && res.message == 'success') {
        return true;
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    }

    return false;
  }

  static test() async {
    EasyLoading.show();

    final sender = BackendCenterSender();
    await sender.auth(account: '123456');
    do {
      final result = await sender.authVerify(account: '123456');
      Logger().i('auth verify result: $result');
      if (result != AuthVerifyResult.wait) break;
      await Future.delayed(const Duration(seconds: 3));
    } while (true);

    EasyLoading.dismiss();
  }
}
