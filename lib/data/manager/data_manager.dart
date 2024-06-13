import 'dart:math';

import 'package:auto_report/main.dart';
import 'package:flutter/material.dart';
import 'package:localstorage/localstorage.dart';
import 'package:package_info_plus/package_info_plus.dart';

class DataManager {
  static final DataManager _singleton = DataManager._internal();

  static const orderRefreshTimeRange = RangeValues(20, 100);

  double orderRefreshTime = 20;
  bool devMode = false;
  String? appVersion;

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
  }

  void restore() {
    orderRefreshTime =
        double.parse(localStorage.getItem('orderRefreshTime') ?? '20');
    orderRefreshTime = min(orderRefreshTimeRange.end,
        max(orderRefreshTimeRange.start, orderRefreshTime));
  }
}
