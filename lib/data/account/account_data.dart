import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/account/histories_response.dart';
import 'package:auto_report/data/proto/response/wallet_balance_response.dart';
import 'package:auto_report/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

class AccountData {
  late String token;
  late String remark;

  late String platformName;
  late String platformUrl;
  late String platformKey;
  late String platformMark;

  late String phoneNumber;
  late String pin;
  late String authCode;
  late String wmtMfs;

  late String deviceId;
  late String model;
  late String osVersion;

  late bool isWmtMfsInvalid;
  bool needRemove = false;

  bool pauseReport = false;
  bool showDetail = false;

  double? balance;

  /// 当前正在更新余额
  bool isUpdatingBalance = false;
  bool isUpdatingOrders = false;

  DateTime lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  final List<HistoriesResponseResponseMapTnxHistoryList?> _waitReportList = [];
  String? _lastTransId;
  DateTime? _lasttransDate;

  AccountData({
    required this.token,
    required this.remark,
    required this.platformName,
    required this.platformUrl,
    required this.platformKey,
    required this.platformMark,
    required this.phoneNumber,
    required this.pin,
    required this.authCode,
    required this.wmtMfs,
    required this.isWmtMfsInvalid,
    required this.deviceId,
    required this.model,
    required this.osVersion,
    this.pauseReport = false,
    this.showDetail = false,
  });

  Map<String, dynamic> restore() {
    return {
      'token': token,
      'remark': remark,
      'platformName': platformName,
      'platformUrl': platformUrl,
      'platformKey': platformKey,
      'platformMark': platformMark,
      'phoneNumber': phoneNumber,
      'pin': pin,
      'authCode': authCode,
      'wmtMfs': wmtMfs,
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
      'isWmtMfsInvalid': isWmtMfsInvalid,
      'pauseReport': pauseReport,
    };
  }

  AccountData.fromJson(Map<String, dynamic> json) {
    token = json['token'];
    remark = json['remark'];

    platformName = json['platformName'];
    platformUrl = json['platformUrl'];
    platformKey = json['platformKey'];
    platformMark = json['platformMark'];

    phoneNumber = json['phoneNumber'];
    pin = json['pin'];
    authCode = json['authCode'];
    wmtMfs = json['wmtMfs'];

    deviceId = json['deviceId'];
    model = json['model'];
    osVersion = json['osVersion'];
    isWmtMfsInvalid = json['isWmtMfsInvalid'];
    pauseReport = json['pauseReport'];
    // isWmtMfsInvalid = false;
  }

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }

  Future<bool> getOrders(int offset) async {
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
        isWmtMfsInvalid = true;
        EasyLoading.showToast('login err: ${response.statusCode}');
        return false;
      }
      final lastTime = _lasttransDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final histories = HistoriesResponse.fromJson(jsonDecode(response.body));
      final tnxHistoryList = histories.responseMap?.tnxHistoryList;
      final cells = tnxHistoryList
          ?.where((cell) => cell?.isReceve() ?? false)
          .where((cell) {
        final time = cell!.toDateTime();
        return time.isAfter(lastTime) ||
            (time == lastTime && cell.transId != _lastTransId);
      }).toList();
      if (cells != null) {
        _waitReportList.addAll(cells);
      }
      // 第一次只需要获取最新的订单
      if (_lasttransDate == null) return false;
      // 没有多余订单了
      if (tnxHistoryList == null || tnxHistoryList.length < 20) return false;
      return tnxHistoryList.last?.toDateTime().isAfter(lastTime) ?? false;
    } catch (e) {
      logger.e('err: ${e.toString()}', stackTrace: StackTrace.current);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
    }
    return false;
  }

  update(VoidCallback? dataUpdated) {
    if (isWmtMfsInvalid) return;
    if (pauseReport) return;

    if (!isUpdatingOrders &&
        DateTime.now().difference(lastUpdateTime).inSeconds > 60) {
      updateOrder(dataUpdated);
    }
    if (!isUpdatingBalance &&
        DateTime.now().difference(lastUpdateBalanceTime).inMinutes > 10) {
      updateBalance(dataUpdated);
    }
  }

  updateOrder(VoidCallback? dataUpdated) async {
    if (isUpdatingOrders) return;
    logger.i('start update order.phone: $phoneNumber');
    isUpdatingOrders = true;
    dataUpdated?.call();

    // 等待余额更新结束
    while (isUpdatingBalance) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    _waitReportList.clear();

    var offset = 0;
    while (!isWmtMfsInvalid && await getOrders(offset)) {
      offset += 10;
    }
    final ids = <String>{};

    if (_lasttransDate == null) {
      if (_waitReportList.isEmpty) {
        _lasttransDate = DateTime.fromMicrosecondsSinceEpoch(0);
        _lastTransId = '-1';
      } else {
        final cell = _waitReportList.first;
        _lastTransId = cell!.transId;
        _lasttransDate = cell.toDateTime();
      }
      logger.i('report: init last date time: $_lasttransDate');
    } else {
      var needReportList = _waitReportList.where((cell) {
        if (cell?.transId == null) return false;
        if (ids.contains(cell?.transId ?? true)) return false;
        ids.add(cell!.transId!);
        return true;
      }).map((cell) {
        logger.i(
            'report: phone: $phoneNumber id: ${cell!.transId}, amount: ${cell.amount}, time: ${cell.transDate}');
        return cell;
      }).toList();
      logger.i('report: cnt: ${needReportList.length}, phone: $phoneNumber');

      if (needReportList.isNotEmpty) {
        final lastCell = needReportList.last;
        _lastTransId = lastCell.transId!;
        _lasttransDate = lastCell.toDateTime();
      }
    }

    // var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    // logger.i('seconds: $seconds');

    // todo report
    _waitReportList.clear();

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
      await Future.delayed(const Duration(milliseconds: 100));
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
        isWmtMfsInvalid = true;
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
