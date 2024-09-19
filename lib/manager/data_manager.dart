import 'dart:math';

import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:auto_report/widges/bank_selector.dart';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DataManager {
  static final DataManager _singleton = DataManager._internal();

  static const orderRefreshTimeRange = RangeValues(50, 120);
  static const gettingCashListRefreshTimeRange = RangeValues(10, 60);
  static const rechargeTransferRefreshTimeRange = RangeValues(10, 60);

  double orderRefreshTime = 60;
  double gettingCashListRefreshTime = 15;
  double rechargeTransferRefreshTime = 30;

  bool devMode = false;
  bool isDark = false;
  bool openRechargeTransfer = false;
  bool autoUpdateBalance = GlobalConfig.bankType == BankType.kbz;

  String? appVersion;
  bool autoRefreshLog = false;

  factory DataManager() {
    return _singleton;
  }

  DataManager._internal() {
    logger.i('DataManager.init().');
    init();
  }

  void init() async {
    restore();
    final packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
  }

  void save() {
    localStorage.setItem('orderRefreshTime', orderRefreshTime.toString());
    localStorage.setItem(
        'gettingCashListRefreshTime', gettingCashListRefreshTime.toString());
    localStorage.setItem(
        'rechargeTransferRefreshTime', rechargeTransferRefreshTime.toString());

    localStorage.setItem('isDark', isDark.toString());
    localStorage.setItem(
        'openRechargeTransfer', openRechargeTransfer.toString());
    localStorage.setItem('autoUpdateBalance', autoUpdateBalance.toString());
  }

  void restore() {
    try {
      orderRefreshTime = double.parse(
          localStorage.getItem('orderRefreshTime') ??
              orderRefreshTime.toString());
      gettingCashListRefreshTime = double.parse(
          localStorage.getItem('gettingCashListRefreshTime') ??
              gettingCashListRefreshTime.toString());
      rechargeTransferRefreshTime = double.parse(
          localStorage.getItem('rechargeTransferRefreshTime') ??
              rechargeTransferRefreshTime.toString());

      orderRefreshTime = min(orderRefreshTimeRange.end,
          max(orderRefreshTimeRange.start, orderRefreshTime));
      gettingCashListRefreshTime = min(
          gettingCashListRefreshTimeRange.end,
          max(gettingCashListRefreshTimeRange.start,
              gettingCashListRefreshTime));
      rechargeTransferRefreshTime = min(
          rechargeTransferRefreshTimeRange.end,
          max(rechargeTransferRefreshTimeRange.start,
              rechargeTransferRefreshTime));

      isDark = bool.parse(localStorage.getItem('isDark') ?? 'false');
      openRechargeTransfer =
          bool.parse(localStorage.getItem('openRechargeTransfer') ?? 'false');
      autoUpdateBalance =
          bool.parse(localStorage.getItem('autoUpdateBalance') ?? 'false');
    } catch (e, stackTrace) {
      logger.e(e, stackTrace: stackTrace);
    }
  }
}
