import 'dart:async';
import 'dart:ui';

import 'package:auto_report/pages/auth_page.dart';

class AccountData {
  String phoneNumber;
  String pin;
  String authCode;
  String wmtMfs;

  String deviceId;
  String model;
  String osVersion;

  bool isWmtMfsInvalid;

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

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }

  updateOrder() async {
    if (isUpdatingOrders) return;
    isUpdatingOrders = true;

    // 等待余额更新结束
    while (isUpdatingBalance) {
      await Future.delayed(const Duration(seconds: 1));
    }

    var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    logger.i('seconds: $seconds');

    isUpdatingOrders = false;
  }

  updateBalance(VoidCallback? dataUpdated) async {
    if (isUpdatingBalance) return;
    isUpdatingBalance = true;
    dataUpdated?.call();

    // 等待订单更新结束
    while (isUpdatingOrders) {
      await Future.delayed(const Duration(seconds: 1));
    }

    await Future.delayed(const Duration(seconds: 5));

    isUpdatingBalance = false;
    dataUpdated?.call();
  }
}
