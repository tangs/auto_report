import 'dart:convert';

import 'package:auto_report/main.dart';
import 'package:auto_report/network/proto/get_cash_list_response.dart';
import 'package:auto_report/network/proto/get_recharge_transfer_list.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';

class BackendSender {
  /// ret: isSuccess, needRepeat, errMsg, isAuthInvid
  static Future<Tuple4<bool, bool, String?, bool>> report({
    required String platformUrl,
    required String phoneNumber,
    required String remark,
    required String token,
    required String orderId,
    required String payId,
    required String platform,
    required String type,
    required String amount,
    required String bankTime,
    required int httpRequestTimeoutSeconds,
    VoidCallback? dataUpdated,
  }) async {
    var isAuthInvidWithReport = false;
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
          'terminal': remark,
          'platform': platform, // 'KBZ',
          'pay_id': payId,
          'type': type, // '9008',
          'pay_order_num': orderId,
          'order_type': 'p2p',
          'pay_money': amount, // '${data.amount}',
          'bank_time': bankTime, //'${data.tradeTime}',
        }),
        Future.delayed(Duration(seconds: httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        final errMsg =
            'report order timeout, phone: $phoneNumber, id: $orderId';
        EasyLoading.showError('report order timeout');
        logger.i(errMsg);
        return Tuple4(false, true, errMsg, isAuthInvidWithReport);
      }

      final body = response.body;
      logger.i('res body: $body');

      final res = ReportGeneralResponse.fromJson(jsonDecode(body));
      if (res.status != 'T') {
        if (res.message == 'not authorized') {
          isAuthInvidWithReport = true;
          dataUpdated?.call();
        }
        if (res.message != 'ERROR-repeat-pay_order_num') {
          final errMsg =
              'report order fail. code: ${res.status}, msg: ${res.message}';
          EasyLoading.showError(errMsg);
          return Tuple4(false, false, errMsg, isAuthInvidWithReport);
        }
      }
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      return Tuple4(
          false, true, 'err: $e, s: $stackTrace', isAuthInvidWithReport);
    }
    return Tuple4(true, false, null, isAuthInvidWithReport);
  }

  /// 获取转账列表(给玩家)
  static Future<List<GetCashListResponseDataList>> getCashList({
    required String payName,
    required String platformUrl,
    required String phoneNumber,
    required int httpRequestTimeoutSeconds,
    VoidCallback? dataUpdated,
  }) async {
    try {
      final host = platformUrl.replaceAll('http://', '');
      const path = 'api/pay/get_cash_list2';
      final url = Uri.http(host, path);
      final response = await Future.any([
        http.post(url, body: {
          'pay_account': phoneNumber,
          'pay_name': payName,
        }),
        Future.delayed(Duration(seconds: httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        logger.i('get cash list timeout, phone: $phoneNumber');
        return [];
      }

      final body = response.body;

      final jsonData = jsonDecode(body);
      if (jsonData['success'] == false) {
        // 当前没有需要转账的数据
        return [];
      }
      final res = GetCashListResponse.fromJson(jsonData);
      if (res.error?.isNotEmpty ?? false) {
        EasyLoading.showError('get cash list fail. err: ${res.error}');
        return [];
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
    }
    return [];
  }

  /// 获取转账列表(给自己其他号码)
  static Future<List<GetRechargeTransferListData>> getRechargeTransferList({
    required String payName,
    required String platformUrl,
    required String phoneNumber,
    required int httpRequestTimeoutSeconds,
    VoidCallback? dataUpdated,
  }) async {
    try {
      final host = platformUrl.replaceAll('http://', '');
      const path = 'api/pay/get_recharge_transfer_list';
      final url = Uri.http(host, path);
      final response = await Future.any([
        http.post(url, body: {
          'pay_account': phoneNumber,
          'bank_name': payName,
        }),
        Future.delayed(Duration(seconds: httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        logger.i('get cash list timeout, phone: $phoneNumber');
        return [];
      }

      final body = response.body;

      final jsonData = jsonDecode(body);
      if (jsonData['success'] == false) {
        // 当前没有需要转账的数据
        return [];
      }
      final res = GetRechargeTransferList.fromJson(jsonData);
      if (res.success != true) {
        return [];
      }
      if (res.error?.isNotEmpty ?? false) {
        EasyLoading.showError('get cash list fail. err: ${res.error}');
        return [];
      }

      if (res.data == null) {
        return [];
      }

      return [res.data!];
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    }
    return [];
  }

  static Future<bool> reportSendMoneySuccess({
    required String platformUrl,
    required String platformName,
    required String platformKey,
    required String phoneNumber,
    required String destNumber,
    required String money,
    required String withdrawalsId,
    required bool isSuccess,
    required int httpRequestTimeoutSeconds,
    required VoidCallback? dataUpdated,
    // required ValueChanged<LogItem> onLogged,
  }) async {
    final host = platformUrl.replaceAll('http://', '');
    const path = 'api/pay/callback_cash';
    final url = Uri.http(host, path);
    final response = await Future.any([
      http.post(url, body: {
        'withdrawals_id': withdrawalsId,
        'type': '${isSuccess ? 2 : 3}',
      }),
      Future.delayed(Duration(seconds: httpRequestTimeoutSeconds)),
    ]);

    final isFail = response is! http.Response;

    if (isFail) {
      EasyLoading.showError('report send money timeout');
      logger.i('report send money timeout');
      // cashFailCnt++;
      dataUpdated?.call();
      return false;
    }

    // onLogged(LogItem(
    //   type: LogItemType.send,
    //   platformName: platformName,
    //   platformKey: platformKey,
    //   phone: phoneNumber,
    //   time: DateTime.now(),
    //   content: 'dest phone number: $destNumber, amount: $money'
    //       ', report ret: ${!isFail}',
    // ));
    logger.i('report send money success.');
    // cashSuccessCnt++;
    dataUpdated?.call();
    return true;
  }

  static Future<bool> reportTransferSuccess({
    required String platformUrl,
    required String platformName,
    required String platformKey,
    required String phoneNumber,
    required String destNumber,
    required String money,
    required String id,
    required bool isSuccess,
    required int httpRequestTimeoutSeconds,
    required VoidCallback? dataUpdated,
    // required ValueChanged<LogItem> onLogged,
  }) async {
    final host = platformUrl.replaceAll('http://', '');
    const path = 'api/pay/callback_recharge_transfer';
    final url = Uri.http(host, path);
    final response = await Future.any([
      http.post(url, body: {
        'id': id,
        'log': '',
        'type': '${isSuccess ? 2 : 3}',
      }),
      Future.delayed(Duration(seconds: httpRequestTimeoutSeconds)),
    ]);

    final isFail = response is! http.Response;

    if (isFail) {
      EasyLoading.showError('transfer timeout');
      logger.i('transfer timeout');
      // transferFailCnt++;
      dataUpdated?.call();
      return false;
    }

    // onLogged(LogItem(
    //   type: LogItemType.transfer,
    //   platformName: platformName,
    //   platformKey: platformKey,
    //   phone: phoneNumber,
    //   time: DateTime.now(),
    //   content: 'dest phone number: $destNumber, amount: $money'
    //       ', report ret: ${!isFail}',
    // ));
    logger.i('transfer success, id: $id, responce: ${response.body}');
    // transferSuccessCnt++;
    dataUpdated?.call();
    return true;
  }
}
