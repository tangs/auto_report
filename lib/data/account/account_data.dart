import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/proto/response/wallet_balance_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/pages/auth_page.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

class AccountData {
  late String phoneNumber;
  late String pin;
  late String authCode;
  late String wmtMfs;

  late String deviceId;
  late String model;
  late String osVersion;

  late bool isWmtMfsInvalid;
  bool needRemove = false;

  double? balance;

  /// 当前正在更新余额
  bool isUpdatingBalance = false;
  bool isUpdatingOrders = false;

  DateTime lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  AccountData({
    required this.phoneNumber,
    required this.pin,
    required this.authCode,
    required this.wmtMfs,
    required this.isWmtMfsInvalid,
    required this.deviceId,
    required this.model,
    required this.osVersion,
  });

  Map<String, dynamic> restore() {
    return {
      'phoneNumber': phoneNumber,
      'pin': pin,
      'authCode': authCode,
      'wmtMfs': wmtMfs,
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
      'isWmtMfsInvalid': isWmtMfsInvalid,
    };
  }

  AccountData.fromJson(Map<String, dynamic> json) {
    phoneNumber = json['phoneNumber'];
    pin = json['pin'];
    authCode = json['authCode'];
    wmtMfs = json['wmtMfs'];
    deviceId = json['deviceId'];
    model = json['model'];
    osVersion = json['osVersion'];
    isWmtMfsInvalid = json['isWmtMfsInvalid'];
  }

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }

  Future getOrders(int offset) async {
    try {
      final url =
          Uri.https(Config.host, 'v3/mfs-customer/utility/tnx-histories', {
        'limit': '${20}',
        'offset': '$offset',
      });
      final headers = Config.getHeaders(
          deviceid: deviceId, model: model, osversion: osVersion)
        ..addAll({
          'user-agent':
              'Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.123 Mobile Safari/537.36',
          Config.wmtMfsKey: wmtMfs,
        });

      final response = await http.get(
        url,
        headers: headers,
      );
      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        logger.e('login err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        EasyLoading.showToast('login err: ${response.statusCode}');
        return;
      }
    } catch (e) {
      logger.e('err: ${e.toString()}', stackTrace: StackTrace.current);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return null;
  }

  update(VoidCallback? dataUpdated) {
    if (!isUpdatingOrders &&
        DateTime.now().difference(lastUpdateTime).inSeconds > 60) {
      updateOrder(dataUpdated);
    }
  }

  updateOrder(VoidCallback? dataUpdated) async {
    if (isUpdatingOrders) return;
    logger.i('start update order.phone: $phoneNumber');
    isUpdatingOrders = true;
    dataUpdated?.call();

    // 等待余额更新结束
    while (isUpdatingBalance) {
      await Future.delayed(const Duration(seconds: 1));
    }

    await getOrders(0);

    // var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    // logger.i('seconds: $seconds');

    logger.i('end update order.phone: $phoneNumber');
    lastUpdateTime = DateTime.now();
    isUpdatingOrders = false;
    dataUpdated?.call();
  }

  updateBalance(VoidCallback? dataUpdated) async {
    if (isUpdatingBalance) return;
    isUpdatingBalance = true;
    dataUpdated?.call();

    // 等待订单更新结束
    while (isUpdatingOrders) {
      await Future.delayed(const Duration(seconds: 1));
    }

    try {
      final url = Uri.https(Config.host, 'v2/mfs-customer/wallet-balance');
      final headers = Config.getHeaders(
          deviceid: deviceId, model: model, osversion: osVersion)
        ..addAll({
          'user-agent': 'okhttp/4.9.0',
          Config.wmtMfsKey: wmtMfs,
        });

      final response = await http.get(
        url,
        headers: headers,
      );
      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        logger.e('login err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        EasyLoading.showToast('login err: ${response.statusCode}');
        return;
      }
      final resBody = WalletBalanceResponse.fromJson(jsonDecode(response.body));
      balance = resBody.responseMap?.balance ?? 0;
      logger.i('update balance: $balance, acc: $phoneNumber');
      lastUpdateBalanceTime = DateTime.now();
    } catch (e) {
      logger.e('err: $e', stackTrace: StackTrace.current);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    } finally {
      isUpdatingBalance = false;
      dataUpdated?.call();
    }
  }
}
