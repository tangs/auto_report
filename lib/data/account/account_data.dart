import 'dart:async';
import 'dart:convert';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/account/histories_response.dart';
import 'package:auto_report/data/log/log_item.dart';
import 'package:auto_report/data/manager/data_manager.dart';
import 'package:auto_report/data/proto/response/report/general_response.dart';
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

  /// 上报服务器授权失败
  bool isAuthInvidWithReport = false;
  bool needRemove = false;

  bool pauseReport = false;
  bool showDetail = false;

  double? balance;

  /// 当前正在更新余额
  bool isUpdatingBalance = false;
  bool isUpdatingOrders = false;
  bool reporting = false;

  DateTime lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  final List<HistoriesResponseResponseMapTnxHistoryList?> _waitReportList = [];
  String? _lastTransId;
  DateTime? _lasttransDate;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

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

      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get order timeout');
        logger.i('get order timeout');
        return false;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        logger.e('get order err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        isWmtMfsInvalid = true;
        EasyLoading.showToast('get order err: ${response.statusCode}');
        return false;
      }
      final lastTime = _lasttransDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final histories = HistoriesResponse.fromJson(jsonDecode(response.body));
      final tnxHistoryList = histories.responseMap?.tnxHistoryList;
      final cells = tnxHistoryList
          ?.where((cell) => cell?.isReceve() ?? false)
          .where((cell) {
        final time = cell!.toDateTime();
        return time.isAfter(lastTime);
        // return time.isAfter(lastTime) ||
        //     (time == lastTime && cell.transId != _lastTransId);
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

  update(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) {
    if (isWmtMfsInvalid) return;
    if (isAuthInvidWithReport) return;
    if (pauseReport) return;

    if (!isUpdatingOrders &&
        DateTime.now().difference(lastUpdateTime).inSeconds >=
            DataManager().orderRefreshTime) {
      updateOrder(dataUpdated, onLogged);
    }
    if (!isUpdatingBalance &&
        DateTime.now().difference(lastUpdateBalanceTime).inMinutes > 30) {
      updateBalance(dataUpdated);
    }
  }

  reopenReport() async {
    while (isUpdatingOrders) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastTransId = null;
    _lasttransDate = null;
  }

  updateOrder(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
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
    _waitReportList.sort((a, b) => a?.compareTo(b) ?? 0);
    final isFirst = _lasttransDate == null;
    if (isFirst) {
      if (_waitReportList.isEmpty) {
        _lasttransDate = DateTime.fromMicrosecondsSinceEpoch(0);
        _lastTransId = '-1';
      } else {
        final cell = _waitReportList.last;
        _lastTransId = cell!.transId;
        _lasttransDate = cell.toDateTime();
      }
      logger.i('report: init last date time: $_lasttransDate, $_lastTransId');
      onLogged(LogItem(
        type: LogItemType.info,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'get last order info. time : $_lasttransDate, id: $_lastTransId',
      ));
    } else {
      final ids = <String>{};
      var needReportList = _waitReportList.where((cell) {
        if (cell == null) return false;
        if (cell.transId == null) return false;
        if (ids.contains(cell.transId)) return false;
        ids.add(cell.transId!);
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

        reports(needReportList, dataUpdated, onLogged);
        updateBalance(dataUpdated);
      }
    }
    // var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    // logger.i('seconds: $seconds');

    _waitReportList.clear();

    logger.i('end update order.phone: $phoneNumber');
    lastUpdateTime = DateTime.now();
    isUpdatingOrders = false;
    dataUpdated?.call();
  }

  int payId = 0;
  Future<bool> report(VoidCallback? dataUpdated,
      HistoriesResponseResponseMapTnxHistoryList data, int payId) async {
    try {
      final host = platformUrl.replaceAll('http://', '');
      const path = 'api/pay/payinfo_app';
      final url = Uri.http(host, path);
      logger.i('url: ${url.toString()}');
      logger.i('host: $host, path: $path');
      final response = await Future.any([
        http.post(url, body: {
          'token': token,
          'phone': phoneNumber,
          'terminal': data.msisdn,
          'platform': 'WavePay',
          'pay_id': '$payId',
          'type': '9002',
          'pay_order_num': data.transId,
          'order_type': data.transType,
          'pay_money': '${data.amount}',
          'bank_time': data.transDate,
        }),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('report order timeout');
        logger.i(
            'report order timeout, phone: $phoneNumber, id: ${data.transId}');
        return false;
      }

      final body = response.body;
      logger.i('res body: $body');

      final res = ReportGeneralResponse.fromJson(jsonDecode(body));
      if (res.status != 'T') {
        if (res.message == 'not authorized') {
          isAuthInvidWithReport = true;
          dataUpdated?.call();
        }
        EasyLoading.showError(
            'report order fail. code: ${res.status}, msg: ${res.message}');
      }
    } catch (e) {
      logger.e('e: $e', stackTrace: StackTrace.current);
    }
    return true;
  }

  reports(List<HistoriesResponseResponseMapTnxHistoryList> reportList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    // final reportList = <HistoriesResponseResponseMapTnxHistoryList?>[];
    // reportList.addAll(list);

    while (reporting) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    reporting = true;
    for (final cell in reportList) {
      var isFail = true;
      // 重试3次
      for (var i = 0; i < 3; ++i) {
        if (await report(dataUpdated, cell, payId++)) {
          isFail = false;
          break;
        }
      }
      onLogged(LogItem(
        type: LogItemType.receive,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'transId: ${cell.transId}, amount: ${cell.amount}, transDate: ${cell.transDate}, report ret: ${!isFail}',
      ));
      logger.i(
          'report: ret: ${!isFail}, phone: $phoneNumber, id: ${cell.transId}, amount: ${cell.amount}, date: ${cell.transDate}');
      if (isFail) {
        reportFailCnt++;
      } else {
        reportSuccessCnt++;
      }
    }
    reporting = false;
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

      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get wallet balance timeout');
        logger.i('get wallet balance timeout');
        return;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        logger.e('get wallet balance err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        EasyLoading.showToast('get wallet balance err: ${response.statusCode}');
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
