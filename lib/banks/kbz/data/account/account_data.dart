import 'dart:async';
import 'dart:convert';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/account/histories_response.dart';
import 'package:auto_report/banks/kbz/data/log/log_item.dart';
import 'package:auto_report/banks/kbz/data/manager/data_manager.dart';
import 'package:auto_report/banks/kbz/data/proto/response/cash/get_cash_list_response.dart';
import 'package:auto_report/banks/kbz/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/banks/kbz/network/sender.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

enum RequestType { updateOrder, updateBalance, sendCash }

class AccountData {
  late Sender sender;
  late String token;
  late String remark;

  late String platformName;
  late String platformUrl;
  late String platformKey;
  late String platformMark;

  late String phoneNumber;
  late String pin;
  late String authCode;

  // late String deviceId;
  // late String model;
  // late String osVersion;

  late bool isWmtMfsInvalid;

  /// 上报服务器授权失败
  bool isAuthInvidWithReport = false;
  bool needRemove = false;

  bool disableReport = false;
  bool disableCash = true;
  bool showDetail = false;

  double? balance;

  /// 当前正在更新余额
  bool isUpdatingBalance = false;
  bool isUpdatingOrders = false;
  bool isSendingCash = false;

  bool reporting = false;
  bool isGettingCashList = false;

  DateTime lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastGetCashListTime = DateTime.fromMicrosecondsSinceEpoch(0);
  DateTime lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  // final List<HistoriesResponseResponseMapTnxHistoryList?> _waitReportList = [];
  // final List<GetCashListResponseDataList> _waitCashList = [];
  // String? _lastTransId;
  int? _lasttransDate = 0;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

  int cashSuccessCnt = 0;
  int cashFailCnt = 0;

  AccountData({
    required this.sender,
    required this.token,
    required this.remark,
    required this.platformName,
    required this.platformUrl,
    required this.platformKey,
    required this.platformMark,
    required this.phoneNumber,
    required this.pin,
    required this.authCode,
    required this.isWmtMfsInvalid,
    // required this.deviceId,
    // required this.model,
    // required this.osVersion,
    this.disableReport = true,
    this.disableCash = true,
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
      // 'deviceId': deviceId,
      // 'model': model,
      // 'osVersion': osVersion,
      'isWmtMfsInvalid': isWmtMfsInvalid,
      'pauseReport': disableReport,
      'disableCash': disableCash,
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

    // deviceId = json['deviceId'];
    // model = json['model'];
    // osVersion = json['osVersion'];
    isWmtMfsInvalid = json['isWmtMfsInvalid'];
    // isWmtMfsInvalid = false;
    disableReport = json['pauseReport'];
    disableCash = json['disableCash'];
    // isWmtMfsInvalid = false;
    // TODO
    sender = Sender(
        aesKey: '',
        ivKey: 'ivKey',
        deviceId: 'deviceId',
        uuid: 'uuid',
        model: 'model');
  }

  _getLogItem({required LogItemType type, required String content}) {
    return LogItem(
      type: type,
      platformName: platformName,
      platformKey: platformKey,
      phone: phoneNumber,
      time: DateTime.now(),
      content: content,
    );
  }

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode';
  }

  Future<bool> getOrders(
      List<NewTransRecordListResqonseTransRecordList> waitReportList,
      int offset,
      ValueChanged<LogItem> onLogged) async {
    try {
      final isFirst = _lasttransDate == null;
      final now = DateTime.fromMicrosecondsSinceEpoch(0).millisecondsSinceEpoch;
      final lastTime = _lasttransDate ?? now;
      var records = await sender.newTransRecordListMsg(phoneNumber, 0, 10);
      if (records != null && records.isNotEmpty) {
        records =
            records.where((record) => record.tradeTime! > lastTime).toList();
      }

      final hasRecords = records != null && records.isNotEmpty;
      if (isFirst) {
        // _lasttransDate = hasRecords ? records.last.tradeTime : now;
        return false;
      }

      if (hasRecords) {
        waitReportList.addAll(records);
        return records.last.tradeTime! > lastTime;
      }
    } catch (e, stackTrace) {
      logger.e('err: ${e.toString()}', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'get order err.err: $e, stackTrace: $stackTrace',
        ),
      );
    }
    return false;
  }

  update(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isWmtMfsInvalid) return;
    if (isAuthInvidWithReport) return;

    if (!disableReport) {
      if (!isUpdatingOrders &&
          DateTime.now().difference(lastUpdateTime).inSeconds >=
              DataManager().orderRefreshTime) {
        updateOrder(dataUpdated, onLogged);
      }
    }

    if (!disableCash) {
      if (!isGettingCashList &&
          DateTime.now().difference(lastGetCashListTime).inSeconds >=
              DataManager().gettingCashListRefreshTime) {
        final cashList = await getCashList(dataUpdated);
        if (cashList?.isNotEmpty ?? false) {
          sendingMoney(cashList!, dataUpdated, onLogged);
        }
      }
    }

    if (!isUpdatingBalance &&
        DateTime.now().difference(lastUpdateBalanceTime).inMinutes >= 30) {
      updateBalance(dataUpdated, onLogged);
    }
  }

  checkNeedWaiting(RequestType without) {
    switch (without) {
      case RequestType.updateOrder:
        return isUpdatingBalance || isSendingCash;
      case RequestType.updateBalance:
        return isUpdatingOrders || isSendingCash;
      case RequestType.sendCash:
        return isUpdatingOrders || isUpdatingBalance;
    }
  }

  reopenReport() async {
    while (isUpdatingOrders) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    // _lastTransId = null;
    _lasttransDate = null;
  }

  updateOrder(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isUpdatingOrders) return;
    logger.i('start update order.phone: $phoneNumber');
    isUpdatingOrders = true;
    dataUpdated?.call();

    // 等待余额更新结束
    while (checkNeedWaiting(RequestType.updateOrder)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final waitReportList = <NewTransRecordListResqonseTransRecordList>[];
    // // _waitReportList.clear();

    var offset = 0;
    while (
        !isWmtMfsInvalid && await getOrders(waitReportList, offset, onLogged)) {
      offset += 6;
      await Future.delayed(const Duration(milliseconds: 150));
    }
    // waitReportList.sort((a, b) => a.compareTo(b));
    // final isFirst = _lasttransDate == null;
    // if (isFirst) {
    //   if (waitReportList.isEmpty) {
    //     _lasttransDate = DateTime.fromMicrosecondsSinceEpoch(0);
    //     _lastTransId = '-1';
    //   } else {
    //     final cell = waitReportList.last;
    //     _lastTransId = cell.transId;
    //     _lasttransDate = cell.toDateTime();
    //   }
    //   logger.i('report: init last date time: $_lasttransDate, $_lastTransId');
    //   onLogged(LogItem(
    //     type: LogItemType.info,
    //     platformName: platformName,
    //     platformKey: platformKey,
    //     phone: phoneNumber,
    //     time: DateTime.now(),
    //     content:
    //         'get last order info. time : $_lasttransDate, id: $_lastTransId',
    //   ));
    // } else {
    //   final ids = <String>{};
    //   final needReportList = waitReportList.where((cell) {
    //     if (cell.transId == null) return false;
    //     if (ids.contains(cell.transId)) return false;
    //     ids.add(cell.transId!);
    //     return true;
    //   }).map((cell) {
    //     logger.i(
    //         'report: phone: $phoneNumber id: ${cell.transId}, amount: ${cell.amount}, time: ${cell.transDate}');
    //     return cell;
    //   }).toList();
    //   logger.i('report: cnt: ${needReportList.length}, phone: $phoneNumber');

    //   if (needReportList.isNotEmpty) {
    //     final lastCell = needReportList.last;
    //     _lastTransId = lastCell.transId!;
    //     _lasttransDate = lastCell.toDateTime();

    //     reports(needReportList, dataUpdated, onLogged);
    //     if (DataManager().autoUpdateBalance) {
    //       updateBalance(dataUpdated, onLogged);
    //     }
    //   }
    // }
    // // var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    // // logger.i('seconds: $seconds');

    // waitReportList.clear();

    // await sender.newTransRecordListMsg(phoneNumber, 0, 10);

    logger.i('end update order.phone: $phoneNumber');
    lastUpdateTime = DateTime.now();
    isUpdatingOrders = false;
    dataUpdated?.call();
  }

  reportSendMoneySuccess(GetCashListResponseDataList cell, bool isSuccess,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    final host = platformUrl.replaceAll('http://', '');
    const path = 'api/pay/callback_cash';
    final url = Uri.http(host, path);
    final response = await Future.any([
      http.post(url, body: {
        'withdrawals_id': cell.withdrawalsId,
        'type': '${isSuccess ? 2 : 3}',
      }),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);

    final isFail = response is! http.Response;

    if (isFail) {
      EasyLoading.showError('report send money timeout');
      logger.i('report send money timeout');
      cashFailCnt++;
      dataUpdated?.call();
      return null;
    }

    onLogged(LogItem(
      type: LogItemType.send,
      platformName: platformName,
      platformKey: platformKey,
      phone: phoneNumber,
      time: DateTime.now(),
      content:
          'dest phone number: ${cell.cashAccount}, amount: ${cell.money}, report ret: ${!isFail}',
    ));
    logger.i('report send money success.');
    cashSuccessCnt++;
    dataUpdated?.call();
  }

  sendingMoney(List<GetCashListResponseDataList> cashList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    while (isSendingCash) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    logger.i('start sending cash.phone: $phoneNumber');
    isSendingCash = true;
    dataUpdated?.call();

    // 等待余额更新结束
    while (checkNeedWaiting(RequestType.sendCash)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // try {
    // for (final cell in cashList) {
    //   if (isWmtMfsInvalid) return;

    //   return;
    // }

    // final resBody = SendMoneyResponse.fromJson(jsonDecode(response.body));
    // if (!resBody.isSuccess()) {
    //   logger.e(
    //       'cash err: ${resBody.statusCode}, ${resBody.message}, dest num: ${cell.cashAccount!}',
    //       stackTrace: StackTrace.current);
    //   EasyLoading.showToast(
    //       'cash err: ${resBody.statusCode}, ${resBody.message}');
    //   reportSendMoneySuccess(cell, false, dataUpdated, onLogged);
    //   continue;
    // }

    // reportSendMoneySuccess(cell, true, dataUpdated, onLogged);
    // }
    // if (DataManager().autoUpdateBalance) {
    //   updateBalance(dataUpdated, onLogged);
    // }
    // } catch (e, stackTrace) {
    //   logger.e('e: $e', stackTrace: stackTrace);
    //   onLogged(
    //     _getLogItem(
    //       type: LogItemType.err,
    //       content: 'send money err.err: $e, stackTrace: $stackTrace',
    //     ),
    //   );
    // } finally {
    //   isSendingCash = false;
    //   dataUpdated?.call();
    // }
  }

  int _payId = 0;
  Future<bool> report(VoidCallback? dataUpdated,
      HistoriesResponseResponseMapTnxHistoryList data, int payId) async {
    if (isWmtMfsInvalid) return false;
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
          'platform': 'KBZ',
          'pay_id': '$payId',
          'type': '9008',
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
        return false;
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      return false;
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
        if (await report(dataUpdated, cell, _payId++)) {
          isFail = false;
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
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
      if (isFail) {
        onLogged(LogItem(
          type: LogItemType.err,
          platformName: platformName,
          platformKey: platformKey,
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'transId: ${cell.transId}, amount: ${cell.amount}, transDate: ${cell.transDate}.',
        ));
      }
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

  updateBalance(
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isUpdatingBalance) return;
    isUpdatingBalance = true;
    dataUpdated?.call();

    // 等待订单更新结束
    while (checkNeedWaiting(RequestType.updateBalance)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    final ret = await sender.queryCustomerBalanceMsg(phoneNumber);

    if (ret != null) {
      balance = ret;
      onLogged(LogItem(
        type: LogItemType.updateBalance,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'balance: $balance',
      ));
    }
    isUpdatingBalance = false;
    dataUpdated?.call();
    lastUpdateBalanceTime = DateTime.now();
  }

  Future<List<GetCashListResponseDataList>?> getCashList(
      VoidCallback? dataUpdated) async {
    try {
      final host = platformUrl.replaceAll('http://', '');
      const path = 'api/pay/get_cash_list';
      final url = Uri.http(host, path);
      // logger.i('url: ${url.toString()}');
      // logger.i('host: $host, path: $path');
      final response = await Future.any([
        http.post(url, body: {
          'pay_account': phoneNumber,
          'pay_name': 'WavePay',
        }),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        // EasyLoading.showError('et cash list timeout');
        logger.i('get cash list timeout, phone: $phoneNumber');
        return null;
      }

      final body = response.body;
      // logger.i('cash res body: $body');

      final jsonData = jsonDecode(body);
      if (jsonData['success'] == false) {
        // 当前没有需要转账的数据
        return [];
      }
      final res = GetCashListResponse.fromJson(jsonData);
      if (res.error?.isNotEmpty ?? false) {
        EasyLoading.showError('get cash list fail. err: ${res.error}');
        return null;
      }

      final waitCashList = (res.data?.list ?? [])
          .where((cell) => cell != null)
          .cast<GetCashListResponseDataList>()
          .toList();

      if (waitCashList.isNotEmpty) {
        logger.i('get cash list.len: ${waitCashList.length}');
      }

      return waitCashList;
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    } finally {
      lastGetCashListTime = DateTime.now();
    }
    return null;
  }
}
