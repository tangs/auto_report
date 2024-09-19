import 'dart:async';

import 'package:auto_report/banks/kbiz/data/bank/recent_transaction_response.dart';
import 'package:auto_report/banks/kbiz/utils/string_helper.dart';
import 'package:auto_report/container/limit_set.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/model/data/account.dart';
import 'package:auto_report/network/backend_center_sender.dart';
import 'package:auto_report/banks/kbiz/network/bank_sender.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

enum RequestType { updateOrder, updateBalance, sendCash }

class AccountData implements Account {
  late BankSender sender;
  late BackendCenterSender backendSender;

  late String account;
  late String password;

  bool needRemove = false;

  bool disableReport = false;
  bool disableCash = true;
  bool disableRechargeTransfer = true;
  bool showDetail = false;

  double? balance;

  // /// 当前正在更新余额
  var isUpdatingBalance = false;
  var isUpdating = false;

  var lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastGetCashListTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastRechargeTransferTime = DateTime.fromMicrosecondsSinceEpoch(0);
  var lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);

  // String? _lastTransId;
  // int? _lasttransDate;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

  int cashSuccessCnt = 0;
  int cashFailCnt = 0;

  int transferSuccessCnt = 0;
  int transferFailCnt = 0;

  bool _waitBackendAuth = false;

  AccountData({
    required this.sender,
    required this.backendSender,
    required this.account,
    required this.password,
    this.disableReport = true,
    this.disableCash = true,
    this.disableRechargeTransfer = true,
    this.showDetail = false,
  });

  Map<String, dynamic> restore() {
    return {
      'account': account,
      'password': password,
      'disableReport': disableReport,
      'disableCash': disableCash,
      'disableRechargeTransfer': disableRechargeTransfer,
    };
  }

  AccountData.fromJson(Map<String, dynamic> json) {
    account = json['account'];
    password = json['password'];

    disableReport = json['disableReport'];
    disableCash = json['disableCash'];
    disableRechargeTransfer = json['disableRechargeTransfer'];

    sender = BankSender(account: account, password: password);
    backendSender = BackendCenterSender();

    authBackendSender();
  }

  get isBankSenderInvalid {
    return !sender.isNormalState;
  }

  get isBackendSenderInvalid {
    return backendSender.isInvalid;
  }

  authBackendSender() async {
    try {
      _waitBackendAuth = true;
      final ret = await backendSender.authAndVerify(
          account: account, verfyWaitSeconds: 3, queryVerifyTimes: 100);
      Logger().i('auth backen sender ret: $ret');
      _waitBackendAuth = false;
    } catch (e, s) {
      Logger().e(e);
      Logger().e(e, stackTrace: s);
    }
  }

  invalid() {
    return isBankSenderInvalid || isBackendSenderInvalid;
  }

  state() {
    if (_waitBackendAuth) {
      return 'wait backend auth.';
    }
    final invalid = isBankSenderInvalid || isBackendSenderInvalid;
    final state = !invalid
        ? 'normal'
        : isBankSenderInvalid
            ? 'Bank invalid'
            : 'Report invalid';
    return state;
  }

  _getLogItem({required LogItemType type, required String content}) {
    // todo
    return LogItem(
      type: type,
      platformName: '',
      platformKey: '',
      phone: account,
      time: DateTime.now(),
      content: content,
    );
  }

  @override
  String toString() {
    return 'phone number: $account';
  }

  final dm = DataManager();

  update(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isUpdating) return;

    try {
      isUpdating = true;

      if (!sender.isNormalState) {
        final ret = await sender.fullLogin(account, password);
        if (!ret) return;
      }
      if (!disableReport &&
          DateTime.now().difference(lastUpdateTime).inSeconds >=
              dm.orderRefreshTime) {
        logger.i('start get orders, phone: $account');
        await _updateOrder(dataUpdated, onLogged);
        logger.i('end get orders, phone: $account');

        lastUpdateTime = DateTime.now();
        dataUpdated?.call();
      }

      //   if (!disableCash &&
      //       DateTime.now().difference(lastGetCashListTime).inSeconds >=
      //           dm.gettingCashListRefreshTime) {
      //     logger.i('start get cash list, phone: $phoneNumber');
      //     final cashList = await getCashList(dataUpdated);
      //     if (cashList.isNotEmpty) {
      //       await _sendingMoneys(cashList, dataUpdated, onLogged);
      //     }

      //     lastGetCashListTime = DateTime.now();
      //     logger.i('end get cash list, phone: $phoneNumber');
      //   }

      //   if (dm.openRechargeTransfer &&
      //       !disableRechargeTransfer &&
      //       DateTime.now().difference(lastRechargeTransferTime).inSeconds >=
      //           dm.rechargeTransferRefreshTime) {
      //     logger.i('start get recharge transfer list, phone: $phoneNumber');
      //     var needUpdateBalance = false;
      //     final transferList = await getRechargeTransferList(dataUpdated);
      //     if (transferList.isNotEmpty) {
      //       needUpdateBalance =
      //           await _transferMoneys(transferList, dataUpdated, onLogged);

      //       if (needUpdateBalance) {
      //         await Future.delayed(const Duration(milliseconds: 300));
      //         lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
      //       }
      //     }

      //     lastRechargeTransferTime = DateTime.now();
      //     logger.i('end get recharge transfer list, phone: $phoneNumber');
      //   }

      //   // if (DateTime.now().difference(lastGetCashListTime).inSeconds >=
      //   //     dm.gettingCashListRefreshTime) {
      //   //   if (!disableCash) {
      //   //     final cashList = await getCashList(dataUpdated);
      //   //     if (cashList.isNotEmpty) {
      //   //       await _sendingMoneys(cashList, dataUpdated, onLogged);
      //   //     }
      //   //   }

      //   //   var needUpdateBalance = false;
      //   //   final transferList = await getRechargeTransferList(dataUpdated);
      //   //   if (transferList.isNotEmpty) {
      //   //     needUpdateBalance =
      //   //         await _transferMoneys(transferList, dataUpdated, onLogged);
      //   //   }

      // if (needUpdateBalance) {
      //   await Future.delayed(const Duration(milliseconds: 300));
      //   await _updateBalance(dataUpdated, onLogged);
      // }
      //   lastGetCashListTime = DateTime.now();
      // }

      if (DateTime.now().difference(lastUpdateBalanceTime).inMinutes >= 30) {
        await _updateBalance(dataUpdated, onLogged);
      }
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    } finally {
      dataUpdated?.call();
      isUpdating = false;
    }
  }

  var _transFirst = true;
  final _ordersIds = LimitSet<String>();

  reopenReport() async {
    while (isUpdating) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    // _lastTransId = null;
    // _lasttransDate = null;
    lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);
    _transFirst = true;
  }

  _updateOrder(
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    logger.i('start update order.phone: $account');
    dataUpdated?.call();

    var offset = 0;
    const perCount = 20;
    final allOrders = <RecentTransactionResponseDataRecentTransactionList>[];

    do {
      final orders = await sender.getRecentTransactionList(
        pageNo: offset,
        rowPerPage: perCount,
      );

      if (orders == null) return;
      final allDeposit = orders.where((order) => order.isDeposit()).toList();
      allOrders.addAll(allDeposit);

      if (_transFirst) break;
      if (orders.length < perCount) break;
      if (allDeposit.any((order) => _ordersIds.contains(order.origRqUid!))) {
        break;
      }

      offset += 15;
    } while (true);

    final newOrders = allOrders
        .where((order) => order.isDeposit())
        .where((order) => !_ordersIds.contains(order.origRqUid!))
        .toList();
    for (final newOrder in newOrders) {
      if (_transFirst) {
        _ordersIds.add(newOrder.origRqUid!);
        continue;
      }

      final orderId = newOrder.origRqUid!;
      final detail = await sender.getTransactionDetail(
        debitCreditIndicator: newOrder.debitCreditIndicator!,
        origRqUid: newOrder.origRqUid!,
        transCode: newOrder.transCode!,
        transDate: newOrder.getDate(),
        transType: newOrder.transType!,
      );

      if (detail?.data?.toAccountNoMarking == null) {
        _getLogItem(
            content: 'get deposit detail err, id: ${newOrder.origRqUid!}',
            type: LogItemType.err);
        Logger().e('detail err.');
        continue;
      }

      if (detail == null) continue;

      var isReportSuccess = false;
      final payCard =
          StringHelper.transferorConvert(detail.data!.toAccountNoMarking!);
      for (var i = 0; i < 3; ++i) {
        final ret = await backendSender.depositSubmit(
          type: '4101',
          account: account,
          payId: orderId,
          payOrder: orderId,
          payCard: payCard,
          payMoney: '${newOrder.depositAmount}',
          bankTime: newOrder.transDate,
          payName: detail.data!.toAccountNameEn!,
          dataUpdated: dataUpdated,
        );

        if (ret) {
          isReportSuccess = true;
          break;
        }
      }

      if (isReportSuccess) {
        ++reportSuccessCnt;
      } else {
        ++reportFailCnt;
        final errMsg = 'report deposit fail, id: $orderId';
        Logger().e(errMsg);
        _getLogItem(content: errMsg, type: LogItemType.err);
      }

      _getLogItem(
          type: LogItemType.receive,
          content: 'report deposit ret: $isReportSuccess, id: $orderId');

      dataUpdated?.call();

      _ordersIds.add(newOrder.origRqUid!);
      await Future.delayed(const Duration(microseconds: 50));
    }

    _transFirst = false;
  }

  _updateBalance(
      VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isUpdatingBalance) return;

    isUpdatingBalance = true;
    dataUpdated?.call();

    try {
      final ret = await sender.getBalance();
      if (ret != null) {
        balance = ret;
        onLogged(LogItem(
          type: LogItemType.updateBalance,
          platformName: '',
          platformKey: '',
          phone: account,
          time: DateTime.now(),
          content: 'balance: $balance',
        ));
      }
    } catch (e, stackTrace) {
      Logger().e('err: $e');
      Logger().e('err: $e', stackTrace: stackTrace);
    } finally {
      isUpdatingBalance = false;
      dataUpdated?.call();
      lastUpdateBalanceTime = DateTime.now();
    }
  }

  updateBalance() {
    lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
    // todo
    // sender.getRecentTransactionList();
  }

  @override
  String get getPhoneNumber => account;

  @override
  String get getPlatformKey => '';
}
