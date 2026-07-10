import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/wave/config/config.dart';
import 'package:auto_report/banks/wave/data/account/histories_response.dart';
import 'package:auto_report/banks/wave/pages/accounts_page.dart';
import 'package:auto_report/banks/wave/utils/wave_crypto.dart';
import 'package:auto_report/container/limit_set.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/banks/wave/data/proto/response/cash/send_money_response.dart';
import 'package:auto_report/banks/wave/data/proto/response/generate_otp_response.dart';
import 'package:auto_report/model/data/account.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/network/backend_sender.dart';
import 'package:auto_report/network/proto/get_cash_list_response.dart';
import 'package:auto_report/banks/wave/data/proto/response/wallet_balance_response.dart';
import 'package:auto_report/network/proto/get_recharge_transfer_list.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:tuple/tuple.dart';

enum RequestType { updateOrder, updateBalance, sendCash }

class AccountData implements Account {
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
  DateTime? _lasttransDate;

  int reportSuccessCnt = 0;
  int reportFailCnt = 0;

  int cashSuccessCnt = 0;
  int cashFailCnt = 0;

  int transferSuccessCnt = 0;
  int transferFailCnt = 0;

  final LimitSet<String> transIds = LimitSet();

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
      'authCode': authCode,
      'wmtMfs': wmtMfs,
      'deviceId': deviceId,
      'model': model,
      'osVersion': osVersion,
      'isWmtMfsInvalid': isWmtMfsInvalid,
      'pauseReport': disableReport,
      'disableCash': disableCash,
      'disableRechargeTransfer': disableRechargeTransfer,
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
    disableRechargeTransfer = json['disableRechargeTransfer'];
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
    return 'phone number: $phoneNumber, pin: $pin, '
        'auth code: $authCode, wmt mfs: $wmtMfs';
  }

  String generateMixpanelCookie({
    required String distinctId,
    required String deviceId,
    required String userId,
    String mixpanelToken = "39057ddd82d23c6cd2af5c346a1f9d4c",
  }) {
    // 1. 构造内部 JSON 结构
    // 注意：Mixpanel 的 Key 很多是以 $ 开头的，在 Dart 中作为 Map Key 没问题，
    // 但在 String 模板中要注意转义。
    final Map<String, dynamic> cookieMap = {
      "distinct_id": distinctId,
      "\$device_id": deviceId,
      "\$user_id": userId,
      "\$initial_referrer": "\$direct",
      "\$initial_referring_domain": "\$direct",
      "__mps": {},
      "__mpso": {},
      "__mpus": {},
      "__mpa": {},
      "__mpu": {},
      "__mpr": [],
      "__mpap": [],
    };

    // 2. 将 Map 转为 JSON 字符串
    String jsonStr = jsonEncode(cookieMap);

    // 3. 对 JSON 字符串进行 URL 编码 (UrlEncode)
    // 这是最关键的一步，必须把 { } " : 等符号转为 %xx 格式
    String encodedJson = Uri.encodeComponent(jsonStr);

    // 4. 拼接最终的 Cookie 字符串
    return "mp_${mixpanelToken}_mixpanel=$encodedJson";
  }

  String? _cfBmCookie;
  Future<void> step1GetCookie() async {
    final url = Uri.parse(
      "https://api.wavemoney.io:8100/v2/wave-tnx-history/splash",
    );

    final response = await http.get(
      url,
      headers: {
        "user-agent":
            "Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/147.0.7727.137 Mobile Safari/537.36",
        "accept": "*/*",
        "content-type": "application/json",
        "referer":
            "https://api.wavemoney.io:8100/v2/wave-tnx-history/?mixpanel_source=Home+Screen",
        "accept-encoding": "gzip, deflate, br, zstd",

        "sec-ch-ua":
            '"Android WebView";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
        "sec-ch-ua-mobile": "?1",
        "sec-ch-ua-platform": "Android",

        "origin": "https://api.wavemoney.io:8100",
        "x-requested-with": "mm.com.wavemoney.wavepay",

        "sec-fetch-site": "same-origin",
        "sec-fetch-mode": "cors",
        "sec-fetch-dest": "empty",
        // "cookie": cookie,
        Config.wmtMfsKey: wmtMfs,
      },
    );

    // 从 response headers 中提取 set-cookie
    String? rawCookie = response.headers['set-cookie'];
    logger.i('raw cookie1: $rawCookie');
    if (rawCookie != null && rawCookie.contains("__cf_bm=")) {
      // 提取 __cf_bm 部分（直到第一个分号结束）
      _cfBmCookie = rawCookie
          .split(';')
          .firstWhere((c) => c.trim().startsWith('__cf_bm='));
      logger.i("成功捕获 Cookie: $_cfBmCookie");
    }
  }

  static String buildHeader({
    required String rawSetCookie, // 从 response.headers['set-cookie'] 拿到的原始串
    required String distinctId,
    required String deviceId,
    String mixpanelToken = "39057ddd82d23c6cd2af5c346a1f9d4c",
  }) {
    // 1. 清洗 __cf_bm (只保留 key=value)
    String cfBm = rawSetCookie
        .split(';')
        .firstWhere((c) => c.trim().startsWith('__cf_bm='))
        .trim();

    // 2. 构造 Mixpanel JSON
    final Map<String, dynamic> mixpanelMap = {
      "distinct_id": distinctId,
      "\$device_id": deviceId,
      "\$user_id": distinctId,
      "\$initial_referrer": "\$direct",
      "\$initial_referring_domain": "\$direct",
      "__mps": {},
      "__mpso": {},
      "__mpus": {},
      "__mpa": {},
      "__mpu": {},
      "__mpr": [],
      "__mpap": [],
    };

    // 3. 对 Mixpanel 进行 URL 编码
    String encodedMixpanel = Uri.encodeComponent(jsonEncode(mixpanelMap));
    String mixpanelCookie = "mp_${mixpanelToken}_mixpanel=$encodedMixpanel";

    // 4. 最终合并 (注意中间的分号和空格)
    return "$cfBm; $mixpanelCookie";
  }

  String? _orderWmtMfs;

  void _logTnxResponse(Map<String, dynamic> response, String clientAppVersion) {
    final responseBody = response["body"];
    String bodyText;
    if (responseBody == null) {
      bodyText = "(empty)";
    } else if (responseBody is String) {
      bodyText = responseBody;
    } else {
      bodyText = const JsonEncoder.withIndent("  ").convert(responseBody);
    }

    logger.i(
      "[WAVE_TNX_RESPONSE] appVersion=$clientAppVersion, "
      "status=${response["status"]}, "
      "limit=${response["requestLimit"]}, "
      "offset=${response["requestOffset"]}, "
      "contentType=${response["contentType"]}, "
      "cfRay=${response["cfRay"]}, bodyLength=${bodyText.length}",
    );

    const chunkSize = 2800;
    final partCount = max(1, (bodyText.length / chunkSize).ceil());
    for (var part = 0; part < partCount; part++) {
      final start = part * chunkSize;
      final end = min(start + chunkSize, bodyText.length);
      logger.i(
        "[WAVE_TNX_RESPONSE_BODY ${part + 1}/$partCount]\n"
        "${bodyText.substring(start, end)}",
      );
    }
  }

  /// return [isSuccess, hasUnreadOrder]
  Future<Tuple2<bool, bool>> getOrders(
    List<HistoriesResponseResponseMapTnxHistoryList> waitReportList, {
    required int offset,
    required int limit,
    required ValueChanged<LogItem> onLogged,
  }) async {
    try {
      logger.i("start get orders.");
      final orderWmtMfs = _orderWmtMfs ?? wmtMfs;
      final ret1 = await WaveTnxHistoryWebClient.fetchTnxHistories(
        deviceId: deviceId,
        model: model,
        osVersion: osVersion,
        limit: limit,
        offset: offset,
        wmtMfs: orderWmtMfs,
      );
      final clientAppVersion =
          ret1["clientAppVersion"] ?? DataManager().appVersion ?? "unknown";
      ret1["clientAppVersion"] = clientAppVersion;
      _logTnxResponse(ret1, clientAppVersion);
      final retJson = jsonEncode(ret1);
      logger.i("retJson: $retJson");

      final state = ret1["status"];
      if (state != 200) {
        final contentType = ret1["contentType"];
        final cfRay = ret1["cfRay"];
        final responseBody = ret1["body"];
        final bodyText = responseBody is String
            ? responseBody
            : jsonEncode(responseBody);
        final bodyPreview = bodyText.length > 500
            ? bodyText.substring(0, 500)
            : bodyText;
        logger.i(
          "state check fail, appVersion: $clientAppVersion, state: $state, "
          "contentType: $contentType, "
          "cfRay: $cfRay, origin: ${ret1["origin"]}, "
          "href: ${ret1["href"]}, userAgent: ${ret1["userAgent"]}, "
          "platform: ${ret1["platform"]}, "
          "requestLimit: ${ret1["requestLimit"]}, "
          "requestOffset: ${ret1["requestOffset"]}, "
          "cloudflareBlocked: ${ret1["cloudflareBlocked"]}, "
          "retryAfterSeconds: ${ret1["retryAfterSeconds"]}, "
          "body: $bodyPreview",
        );
        return const Tuple2(false, false);
      }
      final nextWmtMfs = ret1["nextWmtMfs"];
      if (nextWmtMfs is String && nextWmtMfs.isNotEmpty) {
        _orderWmtMfs = nextWmtMfs;
      }
      final body = ret1["body"];
      // final tnxHistoryList = body["responseMap"]["tnxHistoryList"];
      // await step1GetCookie();
      // var cookie = buildHeader(deviceId: deviceId, distinctId: '44961545', rawSetCookie: _cfBmCookie ?? '');
      // logger.i('dest cookie: $cookie');
      // // var cookie = generateMixpanelCookie(distinctId: '44961545', deviceId: deviceId, userId: '44961545');
      // final url =
      //     // Uri.https(Config.host, 'v3/mfs-customer/utility/tnx-histories', {
      //     // Uri.https(Config.host, 'v3/mfs-customer/tnxhistory-utility/tnx-histories', {
      //     // Uri.https(Config.host, 'v3/mfs-customer/tnxhistory-utility/v2/tnx-histories', {
      //     Uri.https(Config.host, '/merchant-app/tnxhistory-utility/v2/tnx-histories', {
      //   'limit': '$limit',
      //   'offset': '$offset',
      // });
      // // final url = Uri.https(Config.host, 'v2/wave-tnx-history/?mixpanel_source=Home%20Screen');
      // final headers = Config.getHeaders(
      //   deviceid: deviceId,
      //   model: model,
      //   osversion: osVersion,
      // )..addAll({
      //     // 'user-agent':
      //     //     'Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.123 Mobile Safari/537.36',
      //     "user-agent": "Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/147.0.7727.137 Mobile Safari/537.36",
      //     "accept": "*/*",
      //     "content-type": "application/json",
      //     "referer": "https://api.wavemoney.io:8100/v2/wave-tnx-history/?mixpanel_source=Home+Screen",

      //     "origin": "https://api.wavemoney.io:8100",
      //     "x-requested-with": "mm.com.wavemoney.wavepay",

      //     // "accept-encoding": "gzip, deflate, br, zstd",
      //     // "sec-ch-ua": '"Android WebView";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
      //     // "sec-ch-ua-mobile": "?1",
      //     // "sec-ch-ua-platform": "Android",
      //     // "sec-fetch-site": "same-origin",
      //     // "sec-fetch-mode": "cors",
      //     // "sec-fetch-dest": "empty",
      //     // "cookie": cookie,
      //     Config.wmtMfsKey: wmtMfs,
      //   });

      // headers.forEach((k, v) {
      //   logger.i('header: $k: $v');
      // });
      // return const Tuple2(false, false);

      // logger.i('cookie:$_cfBmCookie');

      // logger.i('get order list: offset: $offset.');

      // final engine = CronetEngine.build(
      //   enableHttp2: true,
      //   enableQuic: true,
      //   cacheMode: CacheMode.memory,
      // );
      // final client = CronetClient.fromCronetEngine(engine);
      // var response = await client.get(url, headers: headers);
      // final response = await Future.any([
      //   http.get(url, headers: headers),
      //   Future.delayed(
      //       const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      // ]);

      // if (response is! http.Response) {
      //   EasyLoading.showError('get order timeout');
      //   logger.i('get order timeout');
      //   return const Tuple2(false, false);
      // }

      // wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      // logger.i('Response status: ${response.statusCode}');
      // logger.i('Response body: ${response.body}, len: ${response.body.length}');
      // logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      // return const Tuple2(false, false);

      // if (response.statusCode != 200) {
      //   logger.e('get order err: ${response.statusCode}',
      //       stackTrace: StackTrace.current);
      //   EasyLoading.showToast('get order err: ${response.statusCode}');
      //   if (response.statusCode == 401) {
      //     isWmtMfsInvalid = true;
      //   }
      //   onLogged(
      //     _getLogItem(
      //       type: LogItemType.err,
      //       content: 'get order err.status code: ${response.statusCode}, '
      //           'body: ${response.body}',
      //     ),
      //   );
      //   return const Tuple2(false, false);
      // }
      final lastTime = _lasttransDate ?? DateTime.fromMicrosecondsSinceEpoch(0);
      final histories = HistoriesResponse.fromJson(body);
      final tnxHistoryList = histories.responseMap?.tnxHistoryList
        ?..sort((a, b) => a?.compareTo(b) ?? 0);

      // The initial cursor must use the newest transaction of any type.
      // Filtering to incoming orders here would turn a valid page containing
      // only outgoing transactions into the sentinel 1970/-1 state.
      if (_lasttransDate == null) {
        final initialTransactions =
            tnxHistoryList
                ?.whereType<HistoriesResponseResponseMapTnxHistoryList>()
                .toList() ??
            [];
        if (initialTransactions.isNotEmpty) {
          initialTransactions.sort((a, b) => a.compareTo(b));
          waitReportList.add(initialTransactions.last);
        }
        return const Tuple2(true, false);
      }

      // final tnxHistoryList = histories?..sort((a, b) => a?.compareTo(b) ?? 0);
      final cells =
          tnxHistoryList
                    ?.where((cell) => cell?.isReceve() ?? false)
                    .cast<HistoriesResponseResponseMapTnxHistoryList>()
                    .where((cell) {
                      final time = cell.toDateTime();
                      return time.isAfter(lastTime);
                    })
                    .toList() ??
                []
            ..sort((a, b) => a.compareTo(b));
      if (cells.isEmpty) return const Tuple2(true, false);

      waitReportList.addAll(cells);
      // 没有多余订单了
      if ((tnxHistoryList?.length ?? 0) < 20) return const Tuple2(true, false);
      final ret = !tnxHistoryList!
          .where((cell) => cell?.isReceve() ?? false)
          .any((cell) => !cell!.toDateTime().isAfter(lastTime));
      return Tuple2(true, ret);
      // return cells.last!.toDateTime().isAfter(lastTime);
    } catch (e, stackTrace) {
      logger.e('err: ${e.toString()}', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'get order err.err: $e, stackTrace: $stackTrace',
        ),
      );
      return const Tuple2(false, false);
    }
  }

  final dm = DataManager();

  update(VoidCallback? dataUpdated, ValueChanged<LogItem> onLogged) async {
    if (isWmtMfsInvalid) return;
    if (isAuthInvidWithReport) return;
    if (isUpdating) return;

    isUpdating = true;

    try {
      final orderRefreshTime = max(dm.orderRefreshTime, 90);
      if (disableReport) {
        _orderWmtMfs = null;
      }
      if (!disableReport &&
          DateTime.now().difference(lastUpdateTime).inSeconds >=
              orderRefreshTime) {
        logger.i('start get orders, phone: $phoneNumber');
        await _updateOrder(dataUpdated, onLogged);
        logger.i('end get orders, phone: $phoneNumber');
      }

      if (!disableCash &&
          DateTime.now().difference(lastGetCashListTime).inSeconds >=
              dm.gettingCashListRefreshTime) {
        logger.i('start get cash list, phone: $phoneNumber');
        final cashList = await _getCashList(dataUpdated);

        if (cashList?.isNotEmpty ?? false) {
          await _sendingMoneys(cashList!, dataUpdated, onLogged);
        }

        lastGetCashListTime = DateTime.now();
        logger.i('end get cash list, phone: $phoneNumber');
      }

      if (dm.openRechargeTransfer &&
          !disableRechargeTransfer &&
          DateTime.now().difference(lastRechargeTransferTime).inSeconds >=
              dm.rechargeTransferRefreshTime) {
        logger.i('start get recharge transfer list, phone: $phoneNumber');
        final transferList = await _getRechargeTransferList(dataUpdated);
        if (transferList.isNotEmpty) {
          final needUpdateBalance = await _transferMoneys(
            transferList,
            dataUpdated,
            onLogged,
          );

          if (needUpdateBalance) {
            await Future.delayed(const Duration(milliseconds: 600));
            lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
          }
        }

        lastRechargeTransferTime = DateTime.now();
        logger.i('end get recharge transfer list, phone: $phoneNumber');
      }

      if (DateTime.now().difference(lastUpdateBalanceTime).inMinutes >= 30) {
        await _updateBalance(dataUpdated, onLogged);
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

  bool _isFirstGetTransOrders() {
    return _lasttransDate == null;
  }

  bool _updatingOrder = false;
  _updateOrder(
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    logger.i('start update order.phone: $phoneNumber');
    dataUpdated?.call();

    _updatingOrder = true;
    try {
      final waitReportList = <HistoriesResponseResponseMapTnxHistoryList>[];
      final isFirst = _isFirstGetTransOrders();

      // do {
      // todo
      // if (false) break;
      // if (isFirst) {
      //   final ret = await getOrders(
      //     waitReportList,
      //     offset: 0,
      //     limit: 20,
      //     onLogged: onLogged,
      //   );
      //   if (!ret.item1) break;

      //   if (waitReportList.isEmpty) {
      //     _lasttransDate = DateTime.fromMicrosecondsSinceEpoch(0);
      //     _lastTransId = '-1';
      //   } else {
      //     waitReportList.sort((a, b) => a.compareTo(b));
      //     final cell = waitReportList.last;
      //     _lastTransId = cell.transId;
      //     _lasttransDate = cell.toDateTime();
      //   }
      // } else {}
      // } while (false);

      // const limitCnt = 40;
      const limitCnt = 20;
      var offset = 0;
      var isSuccess = false;
      while (!isWmtMfsInvalid) {
        final ret = await getOrders(
          waitReportList,
          offset: offset,
          limit: limitCnt,
          onLogged: onLogged,
        );
        isSuccess = ret.item1;
        if (!ret.item2) break;
        // offset += limitCnt - 5;
        offset += limitCnt;
        await Future.delayed(const Duration(milliseconds: 300));
      }

      if (isSuccess) {
        waitReportList.sort((a, b) => a.compareTo(b));
        if (isFirst) {
          if (waitReportList.isEmpty) {
            _lasttransDate = DateTime.fromMicrosecondsSinceEpoch(0);
            _lastTransId = '-1';
          } else {
            final cell = waitReportList.last;
            _lastTransId = cell.transId;
            _lasttransDate = cell.toDateTime();
          }
          logger.i(
            'report: init last date time: $_lasttransDate, $_lastTransId',
          );
          onLogged(
            LogItem(
              type: LogItemType.info,
              platformName: platformName,
              platformKey: platformKey,
              phone: phoneNumber,
              time: DateTime.now(),
              content:
                  'get last order info. time : $_lasttransDate, id: $_lastTransId',
            ),
          );
        } else {
          final ids = <String>{};
          final needReportList = waitReportList
              .where((cell) {
                if (cell.transId == null) return false;
                if (ids.contains(cell.transId)) return false;
                ids.add(cell.transId!);
                return true;
              })
              .map((cell) {
                logger.i(
                  'report: phone: $phoneNumber id: ${cell.transId}, '
                  'amount: ${cell.amount}, time: ${cell.transDate}',
                );
                return cell;
              })
              .toList();
          logger.i(
            'report: cnt: ${needReportList.length}, phone: $phoneNumber',
          );

          if (needReportList.isNotEmpty) {
            final lastCell = needReportList.last;
            _lastTransId = lastCell.transId!;
            _lasttransDate = lastCell.toDateTime();

            _reports(needReportList, dataUpdated, onLogged);

            _updatingOrder = false;
            if (DataManager().autoUpdateBalance) {
              _updateBalance(dataUpdated, onLogged);
            }
          }
        }
      }

      // waitReportList.clear();

      logger.i('end update order.phone: $phoneNumber');
      lastUpdateTime = DateTime.now();
      dataUpdated?.call();
    } catch (e) {
      logger.e('e: $e');
    } finally {
      _updatingOrder = false;
    }
  }

  Future<String?> _generateToken() async {
    logger.i('get token start.');
    logger.i('Phone number: $phoneNumber');
    final url = Uri.https(Config.host, 'wmt-mfs-otp/security-token', {
      'msisdn': phoneNumber,
    });
    // final url = Uri.https(
    //     Config.host, 'security-sys/get-security-token');
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          // 'user-agent': 'okhttp/4.9.0',
          'user-agent': 'Dart/3.6.0 (dart:io)',
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
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
          resBody.message ?? 'err code: ${response.statusCode}',
        );
        // EasyLoading.dismiss();
        return null;
      }
      // EasyLoading.showInfo('send auth code success.');
      logger.i('get token success.');
      return resBody.responseMap?.securityCounter;
    } catch (e, stackTrace) {
      logger.e('get token err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'get token err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return null;
    }
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
      withdrawalsId: cell.withdrawalsId!,
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
    onLogged(
      LogItem(
        type: LogItemType.send,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'dest phone number: ${cell.cashAccount}, amount: ${cell.money}'
            ', report ret: $ret',
      ),
    );
  }

  String? _senderName;
  _reportTransferSuccess(
    GetRechargeTransferListData cell,
    bool isSuccess,
    String orderId,
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
      orderId: orderId,
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
    onLogged(
      LogItem(
        type: LogItemType.transfer,
        platformName: platformName,
        platformKey: platformKey,
        phone: phoneNumber,
        time: DateTime.now(),
        content:
            'dest phone number: ${cell.inCardNum}, amount: ${cell.money}'
            ', report ret: $ret',
      ),
    );
  }

  final withdrawalsIds = <String>{};
  final withdrawalsIdSeq = <String>[];
  // final transferIds = <int>{};
  // final transferIdSeq = <int>[];

  static const withdrawalsIdsMaxLen = 1024;
  final _rand = Random();

  // isSuccess, errMsg
  Future<Tuple2<bool, String?>> sendingMoney({
    required String account,
    required String money,
    required ValueChanged<LogItem> onLogged,
    VoidCallback? dataUpdated,
  }) async {
    if (_senderName == null) {
      var ret = await _getAccountName(phoneNumber);
      if (ret.item1 == false) {
        return const Tuple2(false, 'get sender name fail.');
      }
      _senderName = ret.item2;
    }

    final receiverNameRet = await _getAccountName(account);
    if (receiverNameRet.item1 == false) {
      return const Tuple2(false, 'get receiver name fail.');
    }
    var receiverName = receiverNameRet.item2;

    final url = Uri.https(Config.host, 'v2/mfs-customer/send-money-ma');
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          // 'Content-Type': 'application/x-www-form-urlencoded',
          'user-agent': 'Dart/3.6.0 (dart:io)',
          Config.wmtMfsKey: wmtMfs,
        });

    final token = await _generateToken();
    if (token == null) {
      return const Tuple2(false, 'generate token fail.');
    }
    final pin1 = RSAHelper.encrypt('$pin:$token', Config.rsaPublicKey1);

    final formData = {
      'receiverName': receiverName,
      'senderName': _senderName ?? '',
      'receiverMsisdn': account,
      'amount': money,
      'pin': pin1,
      'note': '',
    };

    logger.i('cash: $formData');

    final response = await Future.any([
      http.post(url, headers: headers, body: formData),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);

    if (response is! http.Response) {
      const errMsg = 'send money timeout';
      EasyLoading.showError(errMsg);
      logger.i(errMsg);
      return const Tuple2(false, errMsg);
    }

    wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
    logger.i('send money status: ${response.statusCode}');
    logger.i('send money body: ${response.body}, len: ${response.body.length}');
    logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

    if (response.statusCode != 200) {
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content:
              'send money err.receiverMsisdn: $account,'
              ' money: $money status code: ${response.statusCode},'
              ' body: ${response.body}',
        ),
      );
      logger.e(
        'cash err: ${response.statusCode}, dest num: $account',
        stackTrace: StackTrace.current,
      );
      final resBody = SendMoneyFailResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode == 400) {
        if (resBody.codeStatus == 'PL001' &&
            resBody.message == 'Not enough balance.') {
          // reportSendMoneySuccess(cell, false, dataUpdated, onLogged);
          // await Future.delayed(
          //     Duration(milliseconds: 2000 + _rand.nextInt(1500)));
          // continue;
          return const Tuple2(false, 'Not enough balance.');
        }
      }
      final errMsg =
          'send money err, code: ${response.statusCode}, msg: $resBody';
      EasyLoading.showToast(errMsg);
      if (response.statusCode == 401) {
        isWmtMfsInvalid = true;
      }
      return Tuple2(false, errMsg);
    }

    final resBody = SendMoneyResponse.fromJson(jsonDecode(response.body));
    if (resBody.isSuccess()) {
      return Tuple2(true, resBody.responseMap!.transactionId);
    }
    final errMsg =
        'cash err: ${resBody.statusCode}, ${resBody.message}, dest num: $money';
    return Tuple2(false, errMsg);
    // if (!resBody.isSuccess()) {
    //   // logger.e(
    //   //     'cash err: ${resBody.statusCode}, ${resBody.message}, dest num: ${cell.cashAccount!}',
    //   //     stackTrace: StackTrace.current);
    //   // EasyLoading.showToast(
    //   //     'cash err: ${resBody.statusCode}, ${resBody.message}');
    //   // reportSendMoneySuccess(cell, false, dataUpdated, onLogged);
    //   // await Future.delayed(
    //   //     Duration(milliseconds: 2000 + _rand.nextInt(1500)));
    //   // continue;
    //   return false;
    // }
    // return true;
    // reportSendMoneySuccess(cell, true, dataUpdated, onLogged);
  }

  Future<bool> _transferMoneys(
    List<GetRechargeTransferListData> cashList,
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    logger.i('start transfer. phone: $phoneNumber');
    dataUpdated?.call();

    var hasTransfer = false;
    try {
      for (final cell in cashList) {
        if (isWmtMfsInvalid) return false;
        if (double.parse(cell.money!) > balance!) continue;

        logger.i('transfer. phone: ${cell.inCardNum}, money: ${cell.money}');
        hasTransfer = true;
        final ret = await sendingMoney(
          account: cell.inCardNum!,
          money: cell.money!,
          onLogged: onLogged,
        );
        final isSuccess = ret.item1;
        final errMsg = ret.item2 ?? '';

        if (!isSuccess) {
          onLogged(_getLogItem(type: LogItemType.err, content: errMsg));
        }

        _reportTransferSuccess(
          cell,
          isSuccess,
          ret.item2!,
          dataUpdated,
          onLogged,
        );
        await Future.delayed(
          Duration(milliseconds: 2000 + _rand.nextInt(1500)),
        );
      }

      // if (DataManager().autoUpdateBalance) {
      //   _updateBalance(dataUpdated, onLogged);
      // }
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
    return hasTransfer;
  }

  _sendingMoneys(
    List<GetCashListResponseDataList> cashList,
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    logger.i('start sending cash.phone: $phoneNumber');
    dataUpdated?.call();

    try {
      for (final cell in cashList) {
        if (isWmtMfsInvalid) return;

        final withdrawalsId = cell.withdrawalsId!;
        if (withdrawalsId.isEmpty) continue;
        if (withdrawalsIds.contains(withdrawalsId)) continue;

        final ret = await sendingMoney(
          account: cell.cashAccount!,
          money: '${cell.money}',
          onLogged: onLogged,
        );
        final isSuccess = ret.item1;
        final errMsg = ret.item2 ?? '';

        if (!isSuccess) {
          onLogged(_getLogItem(type: LogItemType.err, content: errMsg));
        }

        withdrawalsIds.add(withdrawalsId);
        withdrawalsIdSeq.add(withdrawalsId);
        if (withdrawalsIdSeq.isNotEmpty &&
            withdrawalsIdSeq.length > withdrawalsIdsMaxLen) {
          final firstId = withdrawalsIds.first;
          withdrawalsIds.remove(firstId);
          withdrawalsIdSeq.removeAt(0);
        }

        _reportSendMoneySuccess(cell, isSuccess, dataUpdated, onLogged);
        await Future.delayed(
          Duration(milliseconds: 2000 + _rand.nextInt(1500)),
        );
      }

      // if (DataManager().autoUpdateBalance) {
      //   _updateBalance(dataUpdated, onLogged);
      // }
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
  Future<Tuple3<bool, bool, String?>> _report(
    VoidCallback? dataUpdated,
    HistoriesResponseResponseMapTnxHistoryList data,
    String payId,
  ) async {
    if (isWmtMfsInvalid) return const Tuple3(false, false, 'token invalid');
    final ret = await BackendSender.report(
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      remark: remark,
      token: token,
      orderId: '${data.transId}',
      payId: payId,
      platform: 'WavePay',
      type: '9002',
      amount: '${data.amount}',
      bankTime: '${data.transDate}',
      payCardNum: data.target(),
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
    if (ret.item4) {
      isAuthInvidWithReport = true;
    }
    return Tuple3(ret.item1, ret.item2, ret.item3);
  }

  _reports(
    List<HistoriesResponseResponseMapTnxHistoryList> reportList,
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    // final reportList = <HistoriesResponseResponseMapTnxHistoryList?>[];
    // reportList.addAll(list);

    String? errMsg;
    for (final cell in reportList) {
      var isFail = true;
      // 重试3次
      for (var i = 0; i < 3; ++i) {
        final ret = await _report(dataUpdated, cell, cell.transId!);
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
      onLogged(
        LogItem(
          type: LogItemType.receive,
          platformName: platformName,
          platformKey: platformKey,
          phone: phoneNumber,
          time: DateTime.now(),
          content:
              'transId: ${cell.transId}, amount: ${cell.amount}, '
              'transDate: ${cell.transDate}, report ret: ${!isFail}, '
              'err msg: ${errMsg ?? ''}',
        ),
      );
      if (isFail) {
        onLogged(
          LogItem(
            type: LogItemType.err,
            platformName: platformName,
            platformKey: platformKey,
            phone: phoneNumber,
            time: DateTime.now(),
            content:
                'transId: ${cell.transId}, amount: ${cell.amount}, '
                'transDate: ${cell.transDate}.',
          ),
        );
      }
      logger.i(
        'report: ret: ${!isFail}, phone: $phoneNumber, id: ${cell.transId}, '
        'amount: ${cell.amount}, date: ${cell.transDate}',
      );
      if (isFail) {
        reportFailCnt++;
      } else {
        reportSuccessCnt++;
      }
    }
    dataUpdated?.call();
  }

  Future<bool> _registeredDevices() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('registered-devices start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(
      myUid,
      myIvB64,
      Config.rsaPublicKey,
    );
    logger.i("cipher : $cipher");

    final url = Uri.https(Config.host, 'v3/mfs-customer/registered-devices');
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          "key": cipher,
          "user-agent": "okhttp/4.9.0",
          "Content-Type": "text/plain",
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('registered-devices timeout');
        logger.i('registered-devices timeout');
        return false;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(
        response.body,
        myUid,
        myIvB64,
      );
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}',
        );
        return false;
      }
      // EasyLoading.showInfo('registered-devices success.');
      logger.i('registered-devices success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _getKycInfo() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('get-kyc-info start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(
      myUid,
      myIvB64,
      Config.rsaPublicKey,
    );
    logger.i("cipher : $cipher");

    final url = Uri.https(Config.host, 'v3/mfs-customer/get-kyc-info');
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          "key": cipher,
          "user-agent": "okhttp/4.9.0",
          "Content-Type": "text/plain",
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get-kyc-info timeout');
        logger.i('get-kyc-info timeout');
        return false;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(
        response.body,
        myUid,
        myIvB64,
      );
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}',
        );
        return false;
      }
      // EasyLoading.showInfo('get-kyc-info success.');
      logger.i('get-kyc-info success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<Tuple2<bool, String>> _getAccountName(String msisdn) async {
    // EasyLoading.show(status: 'loading...');
    logger.i('get account name start');

    final body = {'msisdn': msisdn};
    final url = Uri.https(Config.host, 'v2/mfs-customer/check-mfs-beneficiary');
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          'user-agent': 'Dart/3.6.0 (dart:io)',
          "Content-Type": "application/json",
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.post(url, headers: headers, body: jsonEncode(body)),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get account name timeout');
        logger.i('get account name timeout');
        return const Tuple2(false, '');
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        // EasyLoading.showToast(
        //     resBody.message ?? 'err code: ${response.statusCode}');
        return const Tuple2(false, '');
      }
      // EasyLoading.showInfo('get account name success.');
      final body1 = jsonDecode(response.body);
      final name = body1['responseMap']['name'] as String;
      logger.i('get account name success, name: $name, id: $msisdn');
      return Tuple2(true, name);
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return const Tuple2(false, '');
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _getSubscriberProfile() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('get-subscriber-profile start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(
      myUid,
      myIvB64,
      Config.rsaPublicKey,
    );
    logger.i("cipher : $cipher");

    final url = Uri.https(
      Config.host,
      'v3/mfs-customer/get-subscriber-profile',
    );
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          "key": cipher,
          "user-agent": "okhttp/4.9.0",
          "Content-Type": "text/plain",
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get-subscriber-profile timeout');
        logger.i('get-subscriber-profile timeout');
        return false;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(
        response.body,
        myUid,
        myIvB64,
      );
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}',
        );
        return false;
      }
      // EasyLoading.showInfo('get-subscriber-profile success.');
      logger.i('get-subscriber-profile success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _selfAuthoriaztion() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('self-authorization-eligiblity start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(
      myUid,
      myIvB64,
      Config.rsaPublicKey,
    );
    logger.i("cipher : $cipher");

    final url = Uri.https(
      Config.host,
      'v3/mfs-customer/self-authorization-eligiblity',
    );
    final headers =
        Config.getHeaders(
          deviceid: deviceId,
          model: model,
          osversion: osVersion,
        )..addAll({
          "key": cipher,
          "user-agent": "okhttp/4.9.0",
          "Content-Type": "text/plain",
          Config.wmtMfsKey: wmtMfs,
        });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('self-authorization-eligiblity timeout');
        logger.i('self-authorization-eligiblity timeout');
        return false;
      }

      wmtMfs = response.headers[Config.wmtMfsKey] ?? wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(
        response.body,
        myUid,
        myIvB64,
      );
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}',
        );
        return false;
      }
      // EasyLoading.showInfo('self-authorization-eligiblity success.');
      logger.i('self-authorization-eligiblity success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  _updateBalance(
    VoidCallback? dataUpdated,
    ValueChanged<LogItem> onLogged,
  ) async {
    // if (!disableReport || _updatingOrder) {
    //   // 打开转账时不能更新
    //   return;
    // }
    if (_updatingOrder) {
      // 打开转账时不能更新
      return;
    }
    isUpdatingBalance = true;
    dataUpdated?.call();

    try {
      // {
      //   var ret = await sendingMoney(account: '09770288044', money: "5", onLogged: onLogged);
      //   logger.i('ret: ${ret.item1}, ${ret.item2}');
      //   return;
      // }
      // await _getAccountName('9795215613');
      // {
      //   final ret = await _selfAuthoriaztion();
      //   logger.i('get sub profile: $ret');
      // }

      final url = Uri.https(Config.host, 'v2/mfs-customer/wallet-balance');
      final headers = Config.getHeaders(
        deviceid: deviceId,
        model: model,
        osversion: osVersion,
      )..addAll({'user-agent': 'okhttp/4.9.0', Config.wmtMfsKey: wmtMfs});

      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
          const Duration(seconds: Config.httpRequestTimeoutSeconds),
        ),
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
        logger.e(
          'get wallet balance err: ${response.statusCode}',
          stackTrace: StackTrace.current,
        );
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
      _orderWmtMfs = null;
      final resBody = WalletBalanceResponse.fromJson(jsonDecode(response.body));
      balance = resBody.responseMap?.balance ?? 0;
      logger.i('update balance: $balance, acc: $phoneNumber');
      lastUpdateBalanceTime = DateTime.now();
      onLogged(
        LogItem(
          type: LogItemType.updateBalance,
          platformName: platformName,
          platformKey: platformKey,
          phone: phoneNumber,
          time: DateTime.now(),
          content: 'balance: $balance',
        ),
      );
    } catch (e, stackTrace) {
      logger.e('err: $e', stackTrace: stackTrace);
      EasyLoading.showError(
        'request err, code: $e',
        dismissOnTap: true,
        duration: const Duration(seconds: 60),
      );
      onLogged(
        _getLogItem(
          type: LogItemType.err,
          content: 'get order err.err: $e, stackTrace: $stackTrace',
        ),
      );
    } finally {
      isUpdatingBalance = false;
      lastUpdateBalanceTime = DateTime.now();
      dataUpdated?.call();
    }
  }

  updateBalance() {
    lastUpdateBalanceTime = DateTime.fromMicrosecondsSinceEpoch(0);
  }

  Future<List<GetCashListResponseDataList>?> _getCashList(
    VoidCallback? dataUpdated,
  ) async {
    return BackendSender.getCashList(
      payName: 'WavePay',
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
  }

  Future<List<GetRechargeTransferListData>> _getRechargeTransferList(
    VoidCallback? dataUpdated,
  ) async {
    return BackendSender.getRechargeTransferList(
      payName: 'WavePay',
      platformUrl: platformUrl,
      phoneNumber: phoneNumber,
      httpRequestTimeoutSeconds: Config.httpRequestTimeoutSeconds,
    );
  }

  @override
  String get getPhoneNumber => phoneNumber;

  @override
  String get getPlatformKey => platformKey;
}
