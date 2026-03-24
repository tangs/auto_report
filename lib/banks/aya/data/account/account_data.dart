import 'dart:async';

import 'package:auto_report/banks/aya/config/config.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/model/data/account.dart';
import 'package:auto_report/banks/aya/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/banks/aya/network/sender.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/network/backend_sender.dart';
import 'package:auto_report/network/statistical_sender.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:tuple/tuple.dart';

enum RequestType { updateOrder, updateBalance }

class AccountData implements Account {
  late Sender sender;
  late String token;
  late String remark;

  late String platformName;
  late String platformUrl;
  late String platformKey;
  late String platformMark;

  late String phoneNumber;
  late String pin;
  late String id;
  late String authCode;

  bool isLogined = false;
  /// 上报服务器授权失败
  bool isAuthInvidWithReport = false;
  bool needRemove = false;

  bool disableReport = false;
  bool disableCash = true;
  bool disableRechargeTransfer = true;
  bool showDetail = false;

  double? balance;

  var isUpdatingBalance = false;
  var isUpdating = false;

  var lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  String? _lastTransId;
  int? _lasttransDate;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

  int cashSuccessCnt = 0;
  int cashFailCnt = 0;

  int transferSuccessCnt = 0;
  int transferFailCnt = 0;

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
    required this.id,
    required this.authCode,
    this.disableReport = true,
    this.disableCash = true,
    this.disableRechargeTransfer = true,
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
      'id': id,
      'authCode': authCode,
      'pauseReport': disableReport,
      'disableCash': disableCash,
      'disableRechargeTransfer': disableRechargeTransfer,
      'firebase': sender.firebase,
      'deviceId': sender.deviceId,
      'deviceName': sender.deviceName,
      'authorization': sender.authorization,
      'sentryTrace': sender.sentryTrace,
      'baggage': sender.baggage,
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
    id = json['id'] ?? '';
    authCode = json['authCode'];

    disableReport = json['pauseReport'];
    disableCash = json['disableCash'] ?? true;
    disableRechargeTransfer = json['disableRechargeTransfer'] ?? true;

    sender = Sender(
      firebase: json['firebase'],
      deviceId: json['deviceId'],
      deviceName: json['deviceName'],
      authorization: json['authorization'],
      sentryTrace: json['sentryTrace'],
      baggage: json['baggage'],
    );
    
    login();
  }

  login() async{
    sender.authorization = 'Basic hQCOKs75uoYxakySqIA7qrjzdj2Z9PYn';
    final result = await sender.login(phone: phoneNumber, password: pin);
    if (result.item1 && result.item2) {
      isLogined = true;
    }
  }

  get isWmtMfsInvalid {
    return sender.invalid;
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
    ValueChanged<LogItem> onLogged,
  ) async {
    try {
      const recordCount = 20;
      final isFirst = _lasttransDate == null;
      final lastTime = _lasttransDate ?? 0;
      final records = await sender.transHistory(
        pageParam: 0,
        start: offset,
        number: recordCount,
      );

      if (records == null) return false;

      if (isFirst) {
        waitReportList.addAll(records);
        return false;
      }

      final filtedRecords = records
          .where((record) =>
              record.tradeTime! > lastTime && (isFirst || record.amount! > 0))
          .toList();
      waitReportList.addAll(filtedRecords);

      // // 查询出来的数量小于指定的数量
      // if (records.length < recordCount) {
      //   return false;
      // }

      // 以前没有相关记录时
      if (lastTime == 0) return false;

      if (filtedRecords.isEmpty) return false;

      return filtedRecords.last.tradeTime! > lastTime;
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

  final dm = DataManager();

  update(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isWmtMfsInvalid) return;
    if (isAuthInvidWithReport) return;
    if (isUpdating) return;
    if (!isLogined) return;

    try {
      isUpdating = true;
      if (!disableReport &&
          DateTime.now().difference(lastUpdateTime).inSeconds >=
              dm.orderRefreshTime) {
        logger.i('start get orders, phone: $phoneNumber');
        await _updateOrder(dataUpdated, onLogged);
        logger.i('end get orders, phone: $phoneNumber');
      }

      // if (needUpdateBalance && DateTime.now().difference(lastUpdateBalanceTime).inMinutes >= 240) {
      //   _updateBalance(dataUpdated, onLogged);
      // }
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    }

    isUpdating = false;
  }

  reopenReport() async {
    while (isUpdating) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    _lastTransId = null;
    _lasttransDate = null;
  }

  _updateOrder(
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    logger.i('start update order.phone: $phoneNumber');
    dataUpdated?.call();

    final waitReportList = <NewTransRecordListResqonseTransRecordList>[];
    var offset = 0;

    while (!isWmtMfsInvalid &&
        await getOrders(waitReportList, offset, onLogged)) {
      offset += 15;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    waitReportList.sort((a, b) => a.compareTo(b));

    final isFirst = _lasttransDate == null;
    if (isFirst) {
      if (waitReportList.isEmpty) {
        _lasttransDate = DateTime.now()
            .subtract(const Duration(seconds: 30))
            .millisecondsSinceEpoch;
        _lastTransId = '-1';
      } else {
        final cell = waitReportList.last;
        _lastTransId = cell.orderId;
        _lasttransDate = cell.tradeTime!;
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
      final needReportList = waitReportList.where((cell) {
        if (cell.orderId == null) return false;
        if (ids.contains(cell.orderId)) return false;
        ids.add(cell.orderId!);
        return true;
      }).map((cell) {
        logger.i('report: phone: $phoneNumber id: ${cell.orderId}'
            ', amount: ${cell.amount}, time: ${cell.tradeTime}');
        return cell;
      }).toList();
      logger.i('report: cnt: ${needReportList.length}, phone: $phoneNumber');

      if (needReportList.isNotEmpty) {
        final lastCell = needReportList.last;
        _lastTransId = lastCell.orderId!;
        _lasttransDate = lastCell.tradeTime;

        _reports(needReportList, dataUpdated, onLogged);
        if (DataManager().autoUpdateBalance) {
          _updateBalance(dataUpdated, onLogged);
        }
      }
    }
    var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    logger.i('seconds: $seconds');

    waitReportList.clear();

    logger.i('end update order.phone: $phoneNumber');
    lastUpdateTime = DateTime.now();
    dataUpdated?.call();
  }

  /// ret: isSuccess, needRepeat, errMsg
  Future<Tuple3<bool, bool, String?>> _report(VoidCallback? dataUpdated,
      NewTransRecordListResqonseTransRecordList data, String payId) async {
    if (isWmtMfsInvalid) return const Tuple3(false, false, 'token invalid');
    final ret = await BackendSender.report(
      platformUrl: platformUrl,
      platformName: platformName,
      phoneNumber: phoneNumber,
      remark: remark,
      token: token,
      orderId: data.orderId!,
      payId: payId,
      platform: 'aya',
      type: '4710',
      amount: '${data.amount}',
      bankTime: '${data.tradeTime}',
      payCardNum: data.target(),
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
    if (ret.item4) {
      isAuthInvidWithReport = true;
    }

    if (ret.item1) {
      StatisticalSender.report(
        orderId: data.orderId!,
        targetNumber: data.target(),
        sourceNumber: phoneNumber,
        money: data.amount!.toDouble(),
        bank: 'AYA',
        channel: platformName,
      );
    }
    return Tuple3(ret.item1, ret.item2, ret.item3);
  }

  _reports(List<NewTransRecordListResqonseTransRecordList> reportList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    for (final cell in reportList) {
      var isFail = true;
      String? errMsg;
      // 重试3次
      for (var i = 0; i < 3; ++i) {
        final ret = await _report(dataUpdated, cell, cell.orderId!);
        final isSuccess = ret.item1;
        final needRepeat = ret.item2;
        errMsg = ret.item3;
        if (isSuccess) {
          isFail = false;
          await Future.delayed(const Duration(milliseconds: 10));
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
        if (!needRepeat) break;
      }
      onLogged(LogItem(
        type: LogItemType.receive,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'transId: ${cell.orderId}, amount: ${cell.amount}, '
            'transDate: ${cell.tradeTime}, report ret: ${!isFail}, '
            'err msg: ${errMsg ?? ''}',
      ));
      if (isFail) {
        onLogged(LogItem(
          type: LogItemType.err,
          platformName: platformName,
          platformKey: platformKey,
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'report err, transId: ${cell.orderId}, amount: ${cell.amount},'
              ' transDate: ${cell.tradeTime}, err msg: ${errMsg ?? ''}',
        ));
      }
      logger.i(
          'report: ret: ${!isFail}, phone: $phoneNumber, id: ${cell.orderId},'
          ' amount: ${cell.amount}, date: ${cell.tradeTime}');
      if (isFail) {
        reportFailCnt++;
      } else {
        reportSuccessCnt++;
      }
    }
    dataUpdated?.call();
  }

  _updateBalance(
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isUpdatingBalance) return;

    isUpdatingBalance = true;
    dataUpdated?.call();

    final ret = await sender.getBalance();

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

  updateBalance() {
    lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
  }

  @override
  String get getPhoneNumber => phoneNumber;

  @override
  String get getPlatformKey => platformKey;
}
