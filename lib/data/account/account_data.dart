import 'dart:async';
import 'dart:convert';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/account/histories_response.dart';
import 'package:auto_report/data/log/log_item.dart';
import 'package:auto_report/data/manager/data_manager.dart';
import 'package:auto_report/data/proto/response/cash/get_cash_list_response.dart';
import 'package:auto_report/data/proto/response/cash/send_money_response.dart';
import 'package:auto_report/data/proto/response/generate_otp_response.dart';
import 'package:auto_report/data/proto/response/report/general_response.dart';
import 'package:auto_report/data/proto/response/wallet_balance_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

enum RequestType { updateOrder, updateBalance, sendCash }

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

  final List<HistoriesResponseResponseMapTnxHistoryList?> _waitReportList = [];
  // final List<GetCashListResponseDataList> _waitCashList = [];
  String? _lastTransId;
  DateTime? _lasttransDate;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

  int cashSuccessCnt = 0;
  int cashFailCnt = 0;

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
      'wmtMfs': wmtMfs,
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
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
    wmtMfs = json['wmtMfs'];

    deviceId = json['deviceId'];
    model = json['model'];
    osVersion = json['osVersion'];
    isWmtMfsInvalid = json['isWmtMfsInvalid'];
    // isWmtMfsInvalid = false;
    disableReport = json['pauseReport'];
    disableCash = json['disableCash'];
    // isWmtMfsInvalid = false;
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
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }

  Future<bool> getOrders(int offset, ValueChanged<LogItem> onLogged) async {
    try {
      final url =
          Uri.https(Config.host, 'v3/mfs-customer/utility/tnx-histories', {
        'limit': '${20}',
        'offset': '$offset',
      });
      final headers = Config.getHeaders(
        deviceid: deviceId,
        model: model,
        osversion: osVersion,
      )..addAll({
          'user-agent':
              'Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.123 Mobile Safari/537.36',
          Config.wmtMfsKey: wmtMfs,
        });

      logger.i('get order list: offset: $offset.');
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
        EasyLoading.showToast('get order err: ${response.statusCode}');
        if (response.statusCode == 401) {
          isWmtMfsInvalid = true;
        }
        onLogged(
          _getLogItem(
            type: LogItemType.err,
            content:
                'get order err.status code: ${response.statusCode}, body: ${response.body}',
          ),
        );
        return false;
      }
      final lastTime = _lasttransDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final histories = HistoriesResponse.fromJson(jsonDecode(response.body));
      final tnxHistoryList = histories.responseMap?.tnxHistoryList
        ?..sort((a, b) => a?.compareTo(b) ?? 0);
      final cells = tnxHistoryList
              ?.where((cell) => cell?.isReceve() ?? false)
              .where((cell) {
            final time = cell!.toDateTime();
            return time.isAfter(lastTime);
          }).toList() ??
          []
        ..sort((a, b) => a?.compareTo(b) ?? 0);
      if (cells.isEmpty) return false;

      _waitReportList.addAll(cells);
      // 第一次只需要获取最新的订单
      if (_lasttransDate == null) return false;
      // 没有多余订单了
      if ((tnxHistoryList?.length ?? 0) < 20) return false;
      return !tnxHistoryList!
          .where((cell) => cell?.isReceve() ?? false)
          .any((cell) => !cell!.toDateTime().isAfter(lastTime));
      // return cells.last!.toDateTime().isAfter(lastTime);
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
    _lastTransId = null;
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

    _waitReportList.clear();

    var offset = 0;
    while (!isWmtMfsInvalid && await getOrders(offset, onLogged)) {
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
      final needReportList = _waitReportList.where((cell) {
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
        if (DataManager().autoUpdateBalance) {
          updateBalance(dataUpdated, onLogged);
        }
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

  Future<String?> _generateToken() async {
    logger.i('get token start.');
    logger.i('Phone number: $phoneNumber');
    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/security-token', {'msisdn': '_phoneNumber'});
    final headers = Config.getHeaders(
        deviceid: deviceId, model: model, osversion: osVersion)
      ..addAll({
        'user-agent': 'okhttp/4.9.0',
        Config.wmtMfsKey: wmtMfs,
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        // EasyLoading.showError('get token timeout');
        logger.i('get token timeout');
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        // EasyLoading.dismiss();
        return null;
      }
      // EasyLoading.showInfo('send auth code success.');
      logger.i('get token success.');
      return resBody.responseMap?.securityCounter;
    } catch (e, stackTrace) {
      logger.e('get token err: $e', stackTrace: stackTrace);
      EasyLoading.showError('get token err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return null;
    }
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

    try {
      for (final cell in cashList) {
        if (isWmtMfsInvalid) return;

        final url = Uri.https(Config.host, 'v2/mfs-customer/send-money-ma');
        final headers = Config.getHeaders(
            deviceid: deviceId, model: model, osversion: osVersion)
          ..addAll({
            // 'Content-Type': 'application/x-www-form-urlencoded',
            'user-agent': 'Dart/3.2 (dart:io)',
            Config.wmtMfsKey: wmtMfs,
          });

        final token = await _generateToken();
        final pin1 = RSAHelper.encrypt('$pin:$token', Config.rsaPublicKey);

        // final formData = [
        //   '${Uri.encodeQueryComponent('receiverMsisdn')}=${Uri.encodeQueryComponent(cell.cashAccount!)}',
        //   '${Uri.encodeQueryComponent('amount')}=${Uri.encodeQueryComponent(cell.money.toString())}',
        //   '${Uri.encodeQueryComponent('pin')}=${Uri.encodeQueryComponent(pin1)}',
        //   '${Uri.encodeQueryComponent('note')}=${Uri.encodeQueryComponent('')}',
        // ].join('&');
        final formData = {
          'receiverMsisdn': cell.cashAccount!,
          'amount': cell.money.toString(),
          'pin': pin1,
          'note': '',
        };

        logger.i('cash: $formData');

        final response = await Future.any([
          http.post(url, headers: headers, body: formData),
          Future.delayed(
              const Duration(seconds: Config.httpRequestTimeoutSeconds)),
        ]);

        if (response is! http.Response) {
          EasyLoading.showError('cash timeout');
          logger.i('cash timeout');
          return;
        }

        wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
        logger.i('cash Response status: ${response.statusCode}');
        logger.i(
            'cash Response body: ${response.body}, len: ${response.body.length}');
        logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

        if (response.statusCode != 200) {
          onLogged(
            _getLogItem(
              type: LogItemType.err,
              content:
                  'send money err.receiverMsisdn: ${cell.cashAccount}, money: ${cell.money} status code: ${response.statusCode}, body: ${response.body}',
            ),
          );
          if (response.statusCode == 400) {
            final resBody =
                SendMoneyFailResponse.fromJson(jsonDecode(response.body));
            if (resBody.codeStatus == 'PL001' &&
                resBody.message == 'Not enough balance.') {
              reportSendMoneySuccess(cell, false, dataUpdated, onLogged);
              continue;
            }
          }
          logger.e(
              'cash err: ${response.statusCode}, dest num: ${cell.cashAccount!}',
              stackTrace: StackTrace.current);
          EasyLoading.showToast('cash err: ${response.statusCode}');
          if (response.statusCode == 401) {
            isWmtMfsInvalid = true;
          }
          return;
        }

        final resBody = SendMoneyResponse.fromJson(jsonDecode(response.body));
        if (!resBody.isSuccess()) {
          logger.e(
              'cash err: ${resBody.statusCode}, ${resBody.message}, dest num: ${cell.cashAccount!}',
              stackTrace: StackTrace.current);
          EasyLoading.showToast(
              'cash err: ${resBody.statusCode}, ${resBody.message}');
          reportSendMoneySuccess(cell, false, dataUpdated, onLogged);
          continue;
        }

        reportSendMoneySuccess(cell, true, dataUpdated, onLogged);
      }
      if (DataManager().autoUpdateBalance) {
        updateBalance(dataUpdated, onLogged);
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
      isSendingCash = false;
      dataUpdated?.call();
    }
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
        if (response.statusCode == 401) {
          isWmtMfsInvalid = true;
        }
        onLogged(
          _getLogItem(
            type: LogItemType.err,
            content:
                'get wallet balance err.status code: ${response.statusCode}, body: ${response.body}',
          ),
        );
        return;
      }
      final resBody = WalletBalanceResponse.fromJson(jsonDecode(response.body));
      balance = resBody.responseMap?.balance ?? 0;
      logger.i('update balance: $balance, acc: $phoneNumber');
      lastUpdateBalanceTime = DateTime.now();
      onLogged(LogItem(
        type: LogItemType.updateBalance,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content: 'balance: $balance',
      ));
    } catch (e, stackTrace) {
      logger.e('err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'get order err.err: $e, stackTrace: $stackTrace',
        ),
      );
    } finally {
      isUpdatingBalance = false;
      dataUpdated?.call();
    }
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
