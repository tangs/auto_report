import 'dart:async';
import 'dart:math';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/log/log_item.dart';
import 'package:auto_report/network/proto/get_cash_list_response.dart';
import 'package:auto_report/network/proto/get_recharge_transfer_list.dart';
import 'package:auto_report/banks/kbz/data/proto/response/new_trans_record_list_resqonse.dart';
import 'package:auto_report/banks/kbz/network/sender.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/network/backend_sender.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:tuple/tuple.dart';

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
  late String id;
  late String authCode;

  // late bool isWmtMfsInvalid;

  /// 上报服务器授权失败
  bool isAuthInvidWithReport = false;
  bool needRemove = false;

  bool disableReport = false;
  bool disableCash = true;
  bool disableRechargeTransfer = true;
  bool showDetail = false;

  double? balance;

  // /// 当前正在更新余额
  var isUpdatingBalance = false;
  // var isUpdatingOrders = false;
  // var isSendingCash = false;

  // var reporting = false;
  // var isGettingCashList = false;
  // var isRechargeTransfer = false;
  var isUpdating = false;

  var lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastGetCashListTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastRechargeTransferTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  // final List<HistoriesResponseResponseMapTnxHistoryList?> _waitReportList = [];
  // final List<GetCashListResponseDataList> _waitCashList = [];
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
    // required this.isWmtMfsInvalid,
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
      // 'isWmtMfsInvalid': isWmtMfsInvalid,
      'pauseReport': disableReport,
      'disableCash': disableCash,
      'disableRechargeTransfer': disableRechargeTransfer,
      'send_aesKey': sender.aesKey,
      'send_ivKey': sender.ivKey,
      'send_deviceId': sender.deviceId,
      'send_uuid': sender.uuid,
      'send_model': sender.model,
      'send_miPush': sender.miPush,
      'send_token': sender.token,
      'send_fullName': sender.fullName,
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

    // isWmtMfsInvalid = json['isWmtMfsInvalid'];
    disableReport = json['pauseReport'];
    disableCash = json['disableCash'];
    disableRechargeTransfer = json['disableRechargeTransfer'];

    sender = Sender(
      aesKey: json['send_aesKey'],
      ivKey: json['send_ivKey'],
      deviceId: json['send_deviceId'],
      uuid: json['send_uuid'],
      model: json['send_model'],
      miPush: json['send_miPush'],
      token: json['send_token'],
      fullName: json['send_fullName'],
    );
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
      const recordCount = 10;
      final isFirst = _lasttransDate == null;
      final lastTime = _lasttransDate ?? 0;
      final records = await sender.newTransRecordListMsg(
        phoneNumber,
        offset,
        recordCount,
        onLogged: onLogged,
        account: this,
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

      // 查询出来的数量小于指定的数量
      if (records.length < recordCount) {
        return false;
      }

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

    try {
      isUpdating = true;
      if (!disableReport &&
          DateTime.now().difference(lastUpdateTime).inSeconds >=
              dm.orderRefreshTime) {
        logger.i('start get orders, phone: $phoneNumber');
        await _updateOrder(dataUpdated, onLogged);
        logger.i('end get orders, phone: $phoneNumber');
      }

      if (!disableCash &&
          DateTime.now().difference(lastGetCashListTime).inSeconds >=
              dm.gettingCashListRefreshTime) {
        logger.i('start get cash list, phone: $phoneNumber');
        final cashList = await getCashList(dataUpdated);
        if (cashList.isNotEmpty) {
          await _sendingMoneys(cashList, dataUpdated, onLogged);
        }

        lastGetCashListTime = DateTime.now();
        logger.i('end get cash list, phone: $phoneNumber');
      }

      if (dm.openRechargeTransfer &&
          !disableRechargeTransfer &&
          DateTime.now().difference(lastRechargeTransferTime).inSeconds >=
              dm.rechargeTransferRefreshTime) {
        logger.i('start get recharge transfer list, phone: $phoneNumber');
        var needUpdateBalance = false;
        final transferList = await getRechargeTransferList(dataUpdated);
        if (transferList.isNotEmpty) {
          needUpdateBalance =
              await _transferMoneys(transferList, dataUpdated, onLogged);

          if (needUpdateBalance) {
            await Future.delayed(const Duration(milliseconds: 300));
            lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
          }
        }

        lastRechargeTransferTime = DateTime.now();
        logger.i('end get recharge transfer list, phone: $phoneNumber');
      }

      // if (DateTime.now().difference(lastGetCashListTime).inSeconds >=
      //     dm.gettingCashListRefreshTime) {
      //   if (!disableCash) {
      //     final cashList = await getCashList(dataUpdated);
      //     if (cashList.isNotEmpty) {
      //       await _sendingMoneys(cashList, dataUpdated, onLogged);
      //     }
      //   }

      //   var needUpdateBalance = false;
      //   final transferList = await getRechargeTransferList(dataUpdated);
      //   if (transferList.isNotEmpty) {
      //     needUpdateBalance =
      //         await _transferMoneys(transferList, dataUpdated, onLogged);
      //   }

      //   if (needUpdateBalance) {
      //     await Future.delayed(const Duration(milliseconds: 300));
      //     await _updateBalance(dataUpdated, onLogged);
      //   }
      //   lastGetCashListTime = DateTime.now();
      // }

      if (DateTime.now().difference(lastUpdateBalanceTime).inMinutes >= 30) {
        _updateBalance(dataUpdated, onLogged);
      }
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

    while (
        !isWmtMfsInvalid && await getOrders(waitReportList, offset, onLogged)) {
      offset += 6;
      await Future.delayed(const Duration(milliseconds: 100));
    }

    waitReportList.sort((a, b) => a.compareTo(b));

    final isFirst = _lasttransDate == null;
    if (isFirst) {
      if (waitReportList.isEmpty) {
        _lasttransDate = 0;
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

  _reportSendMoneySuccess(
    GetCashListResponseDataList cell,
    bool isSuccess,
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    final ret = await BackendSender.reportSendMoneySuccess(
      platformUrl: platformUrl,
      platformName: platformName,
      platformKey: platformKey,
      phoneNumber: phoneNumber,
      destNumber: cell.cashAccount!,
      money: '${cell.money}',
      withdrawalsId: '${cell.withdrawalsId}',
      isSuccess: isSuccess,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
      dataUpdated: dataUpdated,
      // onLogged: onLogged,
    );
    if (ret) {
      cashSuccessCnt++;
    } else {
      cashFailCnt++;
    }
    onLogged(LogItem(
      type: LogItemType.send,
      platformName: platformName,
      platformKey: platformKey,
      phone: phoneNumber,
      time: DateTime.now(),
      content: 'dest phone number: ${cell.cashAccount}, amount: ${cell.money}'
          ', report ret: $ret',
    ));
  }

  _reportTransferSuccess(
    GetRechargeTransferListData cell,
    bool isSuccess,
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    final ret = await BackendSender.reportTransferSuccess(
      platformUrl: platformUrl,
      platformName: platformName,
      platformKey: platformKey,
      phoneNumber: phoneNumber,
      destNumber: cell.inCardNum!,
      money: cell.money!,
      id: '${cell.id}',
      isSuccess: isSuccess,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
      dataUpdated: dataUpdated,
      // onLogged: onLogged,
    );
    if (ret) {
      transferSuccessCnt++;
    } else {
      transferFailCnt++;
    }
    onLogged(LogItem(
      type: LogItemType.transfer,
      platformName: platformName,
      platformKey: platformKey,
      phone: phoneNumber,
      time: DateTime.now(),
      content: 'dest phone number: ${cell.inCardNum}, amount: ${cell.money}'
          ', report ret: $ret',
    ));
  }

  _sendingMoney(
    String receiverAccount,
    String amount,
    ValueChanged<LogItem> onLogged,
  ) async {
    if ((await sender.checkAccount(phoneNumber, receiverAccount)).item2 ==
        false) {
      return false;
    }
    return await sender.transferMsg(
      pin,
      phoneNumber,
      receiverAccount,
      amount,
      // 'transfer',
      receiverAccount,
      onLogged: onLogged,
      account: this,
    );
  }

  final withdrawalsIds = <String>{};
  final withdrawalsIdSeq = <String>[];
  // final transferIds = <int>{};
  // final transferIdSeq = <int>[];

  static const withdrawalsIdsMaxLen = 1024;
  final _rand = Random();

  Future<bool> _transferMoneys(List<GetRechargeTransferListData> transferList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (balance == null) return false;

    logger.i('start transfer. phone: $phoneNumber');
    dataUpdated?.call();

    var hasTransfer = false;
    try {
      for (final cell in transferList) {
        if (isWmtMfsInvalid) return false;
        if (cell.id == null) continue;
        // final id = cell.id!;
        // if (transferIds.contains(id)) continue;
        if (cell.money?.isEmpty ?? true) continue;
        if (double.parse(cell.money!) > balance!) continue;

        logger.i('transfer. phone: ${cell.inCardNum}, money: ${cell.money}');
        final ret = await _sendingMoney(cell.inCardNum!, cell.money!, onLogged);
        hasTransfer = true;

        if (ret) {
          onLogged(
            _getLogItem(
              type: LogItemType.transfer,
              content: 'account: ${cell.inCardNum}, money: ${cell.money}',
            ),
          );
        } else {
          onLogged(
            _getLogItem(
              type: LogItemType.err,
              content: 'transfer money err.account: ${cell.inCardNum}'
                  ', money: ${cell.money}',
            ),
          );
          return false;
        }

        // transferIds.add(id);
        // transferIdSeq.add(id);
        // if (transferIdSeq.isNotEmpty &&
        //     transferIdSeq.length > withdrawalsIdsMaxLen) {
        //   final firstId = transferIds.first;
        //   transferIds.remove(firstId);
        //   transferIdSeq.removeAt(0);
        // }

        _reportTransferSuccess(cell, ret, dataUpdated, onLogged);
        await Future.delayed(
            Duration(milliseconds: 2000 + _rand.nextInt(1500)));
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'transfer money err.err: $e, stackTrace: $stackTrace',
        ),
      );
    } finally {
      dataUpdated?.call();
    }
    return hasTransfer;
  }

  _sendingMoneys(List<GetCashListResponseDataList> cashList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    logger.i('start sending cash.phone: $phoneNumber');
    dataUpdated?.call();

    try {
      for (final cell in cashList) {
        if (isWmtMfsInvalid) return;

        if (cell.cashAccount == null) continue;
        if (cell.withdrawalsId == null) continue;

        final withdrawalsId = cell.withdrawalsId!;
        if (withdrawalsId.isEmpty) continue;
        if (withdrawalsIds.contains(withdrawalsId)) continue;

        final ret =
            await _sendingMoney(cell.cashAccount!, '${cell.money}', onLogged);

        if (ret) {
          onLogged(
            _getLogItem(
              type: LogItemType.send,
              content: 'account: ${cell.cashAccount}, money: ${cell.money}',
            ),
          );
        } else {
          onLogged(
            _getLogItem(
              type: LogItemType.err,
              content: 'send money err.receiverMsisdn: ${cell.cashAccount}'
                  ', money: ${cell.money}',
            ),
          );
          return;
        }

        withdrawalsIds.add(withdrawalsId);
        withdrawalsIdSeq.add(withdrawalsId);
        if (withdrawalsIdSeq.isNotEmpty &&
            withdrawalsIdSeq.length > withdrawalsIdsMaxLen) {
          final firstId = withdrawalsIds.first;
          withdrawalsIds.remove(firstId);
          withdrawalsIdSeq.removeAt(0);
        }

        _reportSendMoneySuccess(cell, ret, dataUpdated, onLogged);
        await Future.delayed(
            Duration(milliseconds: 2000 + _rand.nextInt(1500)));
      }

      if (DataManager().autoUpdateBalance) {
        _updateBalance(dataUpdated, onLogged);
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'send money err.err: $e, stackTrace: $stackTrace',
        ),
      );
    } finally {
      dataUpdated?.call();
    }
  }

  // int _payId = 0;

  /// ret: isSuccess, needRepeat, errMsg
  Future<Tuple3<bool, bool, String?>> _report(VoidCallback? dataUpdated,
      NewTransRecordListResqonseTransRecordList data, String payId) async {
    if (isWmtMfsInvalid) return const Tuple3(false, false, 'token invalid');
    final ret = await BackendSender.report(
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      remark: remark,
      token: token,
      orderId: data.orderId!,
      payId: payId,
      platform: 'KBZ',
      type: '9008',
      amount: '${data.amount}',
      bankTime: '${data.tradeTime}',
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
    if (ret.item4) {
      isAuthInvidWithReport = true;
    }
    return Tuple3(ret.item1, ret.item2, ret.item3);
  }

  _reports(List<NewTransRecordListResqonseTransRecordList> reportList,
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    // final reportList = <HistoriesResponseResponseMapTnxHistoryList?>[];
    // reportList.addAll(list);

    for (final cell in reportList) {
      var isFail = true;
      String? errMsg;
      // 重试3次
      for (var i = 0; i < 3; ++i) {
        // final ret = await report(dataUpdated, cell, _payId++);
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

    final ret = await sender.queryCustomerBalanceMsg(
      phoneNumber,
      onLogged: onLogged,
      account: this,
    );

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

  Future<List<GetCashListResponseDataList>> getCashList(
      VoidCallback? dataUpdated) async {
    return BackendSender.getCashList(
      payName: 'KBZPay',
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
  }

  Future<List<GetRechargeTransferListData>> getRechargeTransferList(
      VoidCallback? dataUpdated) async {
    return BackendSender.getRechargeTransferList(
      payName: 'KBZPay',
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
  }
}
