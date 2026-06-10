import 'dart:async';
import 'dart:convert';

import 'package:auto_report/banks/wave/data/account/account_data.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef ReLoginCallback = void Function(
    {String phoneNumber, String pin, String token, String remark});

class WaveTnxHistoryWebClient {
  static const _baseUrl = 'https://api.wavemoney.io:8100/v2/wave-tnx-history/';
  static WebViewController? _attachedController;
  static Completer<void>? _readyCompleter;
  static int _bridgeSeq = 0;
  static final _pendingRequests = <int, Completer<Map<String, dynamic>>>{};

  static void attachController(WebViewController controller) {
    _attachedController = controller;
    _readyCompleter = Completer<void>();
  }

  static void markReady() {
    final completer = _readyCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  static Future<Map<String, dynamic>> fetchTnxHistories({
    required String deviceId,
    required String model,
    required String osVersion,
    required int limit,
    required int offset,
    required String wmtMfs,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final controller = _attachedController;
    if (controller == null) {
      throw StateError(
        'WaveTnxHistoryWebClient.attachController(controller) must be called '
        'with a WebViewController that is attached to a WebViewWidget first.',
      );
    }

    final readyCompleter = _readyCompleter;
    if (readyCompleter != null && !readyCompleter.isCompleted) {
      await readyCompleter.future.timeout(timeout);
    }

    return fetchTnxHistoriesWithController(
      controller,
      deviceId: deviceId,
      model: model,
      osVersion: osVersion,
      limit: limit,
      offset: offset,
      wmtMfs: wmtMfs,
      timeout: timeout,
    );
  }

  static Future<Map<String, dynamic>> fetchTnxHistoriesWithController(
    WebViewController controller, {
    required String deviceId,
    required String model,
    required String osVersion,
    required int limit,
    required int offset,
    required String wmtMfs,
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final completer = Completer<Map<String, dynamic>>();
    final requestId = ++_bridgeSeq;
    _pendingRequests[requestId] = completer;
    await controller.runJavaScript(_buildFetchJs(
      bridgeName: 'TnxBridge',
      requestId: requestId,
      deviceId: deviceId,
      model: model,
      osVersion: osVersion,
      limit: limit,
      offset: offset,
      wmtMfs: wmtMfs,
    ));
    return completer.future.timeout(timeout, onTimeout: () {
      _pendingRequests.remove(requestId);
      throw TimeoutException('Wave WebView request timeout', timeout);
    });
  }

  static bool handleBridgeMessage(String message) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map) {
        return false;
      }
      final requestId = decoded['requestId'];
      if (requestId is! int) {
        return false;
      }
      final completer = _pendingRequests.remove(requestId);
      if (completer == null) {
        return false;
      }
      if (!completer.isCompleted) {
        completer.complete(_decodeBridgeMessage(message));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static Map<String, dynamic> _decodeBridgeMessage(String message) {
    final decoded = jsonDecode(message);
    if (decoded is! Map) {
      return {'body': decoded};
    }

    final result = Map<String, dynamic>.from(decoded);
    final body = result['body'];
    if (body is String && body.trim().isNotEmpty) {
      try {
        result['body'] = jsonDecode(body);
      } catch (_) {
        result['body'] = body;
      }
    }
    return result;
  }

  static String _jsString(String value) {
    return value
        .trim()
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
  }

  static String _buildFetchJs({
    String bridgeName = 'TnxBridge',
    int requestId = 0,
    required String deviceId,
    required String model,
    required String osVersion,
    required int limit,
    required int offset,
    required String wmtMfs,
  }) {
    final cleanDeviceId = _jsString(deviceId);
    final cleanModel = _jsString(model);
    final cleanOsVersion = _jsString(osVersion);
    final cleanWmtMfs = _jsString(wmtMfs);

    return '''
(function () {
  async function main() {
    const requestId = $requestId;
    const headers = {
      "accept": "*/*",
      "content-type": "application/json",
      "fingerprint": "87EC104C0FFBB8E749CD59D9C64851441B38D1C13C9746DC124BB9E71E66DCB9",
      "appId": "mm.com.wavemoney.wavepay",
      "userLanguage": "en",
      "versionCode": "1470",
      "appVersion": "2.6.1",
      "deviceId": "$cleanDeviceId",
      "device": "",
      "product": "redfin",
      "cpuAbi": "arm64-v8a,armeabi-v7a,armeabi",
      "manufacturer": "Google",
      "model": "$cleanModel",
      "osVersion": "$cleanOsVersion",
      "x-requested-with": "mm.com.wavemoney.wavepay",
      "wmt-mfs": "$cleanWmtMfs"
    };

    try {
      const targetUrl = "/merchant-app/tnxhistory-utility/v2/tnx-histories?limit=$limit&offset=$offset";
      const fetchPromise = fetch(targetUrl, {
        method: "GET",
        headers,
        credentials: "include",
        cache: "no-store"
      });
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error("fetch timeout after 25s")), 25000);
      });
      const res = await Promise.race([fetchPromise, timeoutPromise]);
      const text = await res.text();

      $bridgeName.postMessage(JSON.stringify({
        requestId: requestId,
        ok: res.ok,
        status: res.status,
        statusText: res.statusText,
        nextWmtMfs: res.headers.get("wmt-mfs"),
        body: text
      }));
    } catch (e) {
      $bridgeName.postMessage(JSON.stringify({
        requestId: requestId,
        ok: false,
        error: String(e && e.stack ? e.stack : e),
        origin: location.origin,
        href: location.href
      }));
    }
  }

  main();
})();
''';
  }
}

class AccountsPage extends StatefulWidget {
  final List<AccountData> accountsData;
  final List<GetPlatformsResponseData?>? platforms;

  final ValueChanged<AccountData> onRemoved;
  final ReLoginCallback onReLogin;
  final ValueChanged<LogItem> onLogged;

  const AccountsPage({
    super.key,
    required this.accountsData,
    required this.platforms,
    required this.onRemoved,
    required this.onReLogin,
    required this.onLogged,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _platformsCheckboxResults = <String, bool>{};
  final logger = Logger();

  late final WebViewController controller;
  final TextEditingController wmtMfsController = TextEditingController();
  String resultText = '';
  bool pageReady = false;
  bool loading = false;
  int _tnxRequestId = 0;
  
  @override
  void initState() {
    super.initState();
    const testHtml = '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
  <h3>Wave request test page</h3>
  <pre id="log">ready</pre>

  <script>
    document.getElementById("log").textContent =
      "origin=" + location.origin + "\\n" +
      "href=" + location.href + "\\n" +
      "cookie=" + (document.cookie || "(empty)");
  </script>
</body>
</html>
''';

    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'TnxBridge',
        onMessageReceived: (JavaScriptMessage message) {
          if (WaveTnxHistoryWebClient.handleBridgeMessage(message.message)) {
            return;
          }
          logger.i(message.message);
          setState(() {
            resultText = message.message;
            loading = false;
          });
        },
      )
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; Pixel 5 Build/RD1A.200810.022.A4; wv) '
        'AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 '
        'Chrome/147.0.7727.137 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            debugPrint('page finished: $url');
            WaveTnxHistoryWebClient.markReady();
            setState(() => pageReady = true);
          },
          onWebResourceError: (error) {
            debugPrint('web error: ${error.description}');
          },
        ),
      )
      // ..loadRequest(Uri.parse(
      //   'https://api.wavemoney.io:8100/v2/wave-tnx-history/?mixpanel_source=Home+Screen',
      // ));
      ..loadHtmlString(
        testHtml,
        baseUrl: 'https://api.wavemoney.io:8100/v2/wave-tnx-history/',
      );
    WaveTnxHistoryWebClient.attachController(controller);
  }

  @override
  void dispose() {
    wmtMfsController.dispose();
    super.dispose();
  }

  String _cleanJsString(String value) {
    return value
        .replaceAll('\r', '')
        .replaceAll('\n', '')
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"');
  }

  Future<void> runTnxTest() async {
    final wmtMfs = _cleanJsString(wmtMfsController.text.trim());
    final requestId = ++_tnxRequestId;

    if (wmtMfs.isEmpty) {
      setState(() => resultText = 'wmt-mfs 不能为空');
      return;
    }

    setState(() {
      loading = true;
      resultText = 'requesting...';
    });

    final js = '''
(function () {
  async function main() {
    const requestId = $requestId;
    const headers = {
      "accept": "*/*",
      "content-type": "application/json",
      "fingerprint": "87EC104C0FFBB8E749CD59D9C64851441B38D1C13C9746DC124BB9E71E66DCB9",
      "appId": "mm.com.wavemoney.wavepay",
      "userLanguage": "en",
      "versionCode": "1470",
      "appVersion": "2.6.1",
      "deviceId": "45c5815443d57a7c7d43463dcd8d3e46d188769b",
      "device": "",
      "product": "redfin",
      "cpuAbi": "arm64-v8a,armeabi-v7a,armeabi",
      "manufacturer": "Google",
      "model": "Pixel 6",
      "osVersion": "14",
      "x-requested-with": "mm.com.wavemoney.wavepay",
      "wmt-mfs": "$wmtMfs"
    };

    try {
      const targetUrl = "/merchant-app/tnxhistory-utility/v2/tnx-histories?limit=20&offset=20";
      const fetchPromise = fetch(targetUrl, {
        method: "GET",
        headers,
        credentials: "include",
        cache: "no-store"
      });
      const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error("fetch timeout after 25s")), 25000);
      });
      const res = await Promise.race([fetchPromise, timeoutPromise]);

      const responseHeaders = {};
      res.headers.forEach((v, k) => responseHeaders[k] = v);

      const text = await res.text();
      let output = text;
      try {
        output = JSON.stringify(JSON.parse(text), null, 2);
      } catch (_) {}

      TnxBridge.postMessage(output);
    } catch (e) {
      TnxBridge.postMessage(JSON.stringify({
        requestId: requestId,
        error: String(e && e.stack ? e.stack : e),
        origin: location.origin,
        href: location.href,
        cookie: document.cookie || ""
      }));
    }
  }

  main();
})();
''';

    try {
      await controller.runJavaScript(js);
      Future.delayed(const Duration(seconds: 30), () {
        if (!mounted || !loading || requestId != _tnxRequestId) {
          return;
        }
        setState(() {
          resultText =
              'request timeout in Flutter after 30s. JS did not post a result. origin should be https://api.wavemoney.io:8100.';
          loading = false;
        });
      });
    } catch (e) {
      setState(() {
        resultText = 'inject js failed v2: $e';
        loading = false;
      });
    }
  }

  String _formatTnxResult(String rawMessage) {
    try {
      final decoded = jsonDecode(rawMessage);
      if (decoded is! Map) {
        return const JsonEncoder.withIndent('  ').convert(decoded);
      }

      final result = Map<String, dynamic>.from(decoded);
      final body = result['body'];
      Object? formattedBody = body;
      if (body is String && body.trim().isNotEmpty) {
        try {
          formattedBody = _normalizeJsonStrings(jsonDecode(body));
        } catch (_) {
          formattedBody = body;
        }
      }

      return const JsonEncoder.withIndent('  ').convert(formattedBody);
    } catch (_) {
      return rawMessage;
    }
  }

  Object? _normalizeJsonStrings(Object? value) {
    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(key, _normalizeJsonStrings(item)),
      );
    }
    if (value is List) {
      return value.map(_normalizeJsonStrings).toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      final looksLikeJson = (trimmed.startsWith('{') && trimmed.endsWith('}')) ||
          (trimmed.startsWith('[') && trimmed.endsWith(']'));
      if (looksLikeJson) {
        try {
          return _normalizeJsonStrings(jsonDecode(trimmed));
        } catch (_) {
          return value;
        }
      }
    }
    return value;
  }

  List<Widget> _buildList() {
    return widget.accountsData
        .where((data) => _platformsCheckboxResults[data.platformKey] ?? true)
        .map((data) => _item1(data))
        .toList();
  }

  List<Widget> _buildDetails(AccountData data) {
    return [
      _buildSub('auth code', data.authCode, null, null),
      _buildSub('pin', data.pin, null, null),
      _buildSub('wmt mfs', data.wmtMfs, null, null),
      _buildSub('deviceId', data.deviceId, null, null),
      _buildSub('model', data.model, null, null),
      _buildSub('os version', data.osVersion, null, null),
      _buildSub('platform name', data.platformName, null, null),
      _buildSub('platform url', data.platformUrl, null, null),
      _buildSub('platform key', data.platformKey, null, null),
      _buildSub('platform mark', data.platformMark, null, null),
    ];
  }

  Widget _item1(AccountData data) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isUpdatingBalance = data.isUpdatingBalance;
    final invalid = data.isWmtMfsInvalid || data.isAuthInvidWithReport;
    final showDetail = data.showDetail;
    final state = !invalid
        ? 'normal'
        : data.isWmtMfsInvalid
            ? 'Wave invalid'
            : 'Report invalid';
    return ExpansionTile(
      title: Row(
        children: [
          Row(
            children: [
              Text(
                '${data.remark}[${data.platformName}]',
                style: const TextStyle(fontSize: 16),
              ),
              const Padding(padding: EdgeInsets.only(left: 10)),
              Text(
                style: TextStyle(color: invalid ? Colors.red : Colors.blue),
                state,
              )
            ],
          )
        ],
      ),
      children: [
        Row(
          children: [
            const Icon(Icons.phone_android_sharp),
            Text(data.phoneNumber),
            const Spacer(),
            Text('Balance: ${data.balance?.toString() ?? '??'}'),
            const Padding(padding: EdgeInsets.only(left: 10)),
            // OutlinedButton(
            //   onPressed: (isUpdatingBalance || invalid)
            //       ? null
            //       : () => data.updateBalance(
            //           () => setState(() => data = data), widget.onLogged),
            //   child: Text(isUpdatingBalance ? 'updating' : 'update'),
            // )
            OutlinedButton(
              onPressed: (isUpdatingBalance || invalid)
                  ? null
                  : () => data.updateBalance(),
              child: Text(isUpdatingBalance ? 'updating' : 'update'),
            ),
          ],
        ),
        Row(
          children: [
            RichText(
              text: TextSpan(
                text: 'Report',
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '    succ: ${data.reportSuccessCnt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  TextSpan(
                    text: '    fail: ${data.reportFailCnt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Text('Receive money:'),
            Switch(
              value: !data.disableReport,
              activeColor: Colors.red,
              onChanged: (bool value) {
                setState(() => data.disableReport = !value);
                if (!value) {
                  data.reopenReport();
                }
                widget.onLogged(LogItem(
                  type: LogItemType.info,
                  platformName: data.platformName,
                  platformKey: data.platformKey,
                  phone: data.phoneNumber,
                  time: DateTime.now(),
                  content: '${value ? 'open' : 'close'} receive money.',
                ));
              },
            ),
          ],
        ),
        // Row(
        //   children: [
        //     RichText(
        //       text: TextSpan(
        //         text: 'Cash',
        //         style: DefaultTextStyle.of(context).style,
        //         children: [
        //           TextSpan(
        //             text: '    succ: ${data.cashSuccessCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.blue,
        //             ),
        //           ),
        //           TextSpan(
        //             text: '    fail: ${data.cashFailCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.red,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //     const Spacer(),
        //     const Text('Send money:'),
        //     Switch(
        //       value: !data.disableCash,
        //       activeColor: Colors.red,
        //       onChanged: (bool value) {
        //         setState(() => data.disableCash = !value);
        //         widget.onLogged(LogItem(
        //           type: LogItemType.info,
        //           platformName: data.platformName,
        //           platformKey: data.platformKey,
        //           phone: data.phoneNumber,
        //           time: DateTime.now(),
        //           content: '${value ? 'open' : 'close'} send money.',
        //         ));
        //       },
        //     ),
        //   ],
        // ),
        // Row(
        //   children: [
        //     RichText(
        //       text: TextSpan(
        //         text: 'Transfer',
        //         style: DefaultTextStyle.of(context).style,
        //         children: [
        //           TextSpan(
        //             text: '    succ: ${data.transferSuccessCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.blue,
        //             ),
        //           ),
        //           TextSpan(
        //             text: '    fail: ${data.transferFailCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.red,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //     const Spacer(),
        //     const Text('Recharge transfer:'),
        //     Switch(
        //       value: !data.disableRechargeTransfer,
        //       activeColor: Colors.red,
        //       onChanged: (bool value) {
        //         setState(() => data.disableRechargeTransfer = !value);
        //         widget.onLogged(LogItem(
        //           type: LogItemType.info,
        //           platformName: data.platformName,
        //           platformKey: data.platformKey,
        //           phone: data.phoneNumber,
        //           time: DateTime.now(),
        //           content: '${value ? 'open' : 'close'} recharge transfer.',
        //         ));
        //       },
        //     ),
        //   ],
        // ),
        Visibility(
          visible: DataManager().devMode,
          child: Row(
            children: [
              const Text('Show detail:'),
              const Spacer(),
              Switch(
                value: data.showDetail,
                activeColor: Colors.red,
                onChanged: (bool value) =>
                    setState(() => data.showDetail = value),
              ),
            ],
          ),
        ),
        // _buildSub(
        //     'Balance',
        //     data.balance?.toString() ?? 'never updated',
        //     isUpdatingBalance ? 'updating' : 'update',
        //     isUpdatingBalance || invalid
        //         ? null
        //         : () => data.updateBalance(() => setState(() => data = data))),
        _buildSub(
            'Balance update time',
            data.lastUpdateBalanceTime.millisecondsSinceEpoch == 0
                ? 'never updated'
                : dateFormat.format(data.lastUpdateBalanceTime),
            null,
            null),
        _buildSub(
            'Orders update time',
            data.lastUpdateTime.microsecondsSinceEpoch == 0
                ? 'never updated'
                : dateFormat.format(data.lastUpdateTime),
            null,
            null),
        Visibility(
          visible: showDetail,
          child: Column(
            children: _buildDetails(data),
          ),
        ),
        // Visibility(
        //   visible: !invalid,
        //   child: OutlinedButton(
        //     onPressed: data.isUpdatingOrders || invalid
        //         ? null
        //         : () =>
        //             data.updateOrder(() => setState(() => data = data), (log) {
        //               // todo.
        //             }),
        //     child: Text(
        //         data.isUpdatingOrders ? 'Updating orders' : 'Update orders'),
        //   ),
        // ),
        Row(
          children: [
            Text('state: ${data.isUpdating ? 'Updating' : 'Waiting'}')
          ],
        ),
        Visibility(
          visible: invalid,
          child: OutlinedButton(
            onPressed: () => widget.onReLogin(
              phoneNumber: data.phoneNumber,
              pin: data.pin,
              token: data.token,
              remark: data.remark,
            ),
            child: const Text('ReLogin'),
          ),
        ),
        Column(
          children: [
            Center(
              child: IconButton(
                color: Colors.red,
                icon: const Icon(Icons.delete_forever),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Icon(Icons.delete_forever),
                        content: const Text('delete this account?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              setState(() => data.needRemove = true);
                              widget.onRemoved(data);
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSub(
      String title, String value, String? button, VoidCallback? callback) {
    //可以设置撑满宽度的盒子 称之为百分百布局
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text(overflow: TextOverflow.fade, '$title: $value'),
          const Spacer(),
          Visibility(
            visible: button != null,
            child: OutlinedButton(
              onPressed: callback,
              child: Text(button ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckbox(GetPlatformsResponseData? data) {
    final key = data!.key!;
    final value = _platformsCheckboxResults[key] ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Text(data.name!),
          Checkbox(
            value: value,
            onChanged: (value) => setState(() {
              _platformsCheckboxResults[key] = value!;
            }),
          ),
        ],
      ),
    );
  }

  bool _isAllPlatformsSelected() {
    return !widget.platforms!.any((platform) =>
        (_platformsCheckboxResults[platform!.key] ?? true) == false);
  }

  Widget _buildFilter() {
    final widgets = widget.platforms
            ?.map((platform) => _buildCheckbox(platform))
            .toList() ??
        [];
    widgets.insert(
        0,
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
          child: Row(
            children: [
              const Text('ALL'),
              Checkbox(
                  value: _isAllPlatformsSelected(),
                  onChanged: (value) => setState(() {
                        for (var platform in widget.platforms!) {
                          _platformsCheckboxResults[platform!.key!] = value!;
                        }
                      })),
            ],
          ),
        ));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        
        _buildFilter(),
        Visibility(
          child: TextField(
            controller: wmtMfsController,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'wmt-mfs',
              border: OutlineInputBorder(),
            ),
          ),
          visible: false,
        ),
        // const SizedBox(height: 8),
        // ElevatedButton(
        //   onPressed: pageReady && !loading ? runTnxTest : null,
        //   child: Text(loading ? '请求中...' : '运行请求'),
        // ),
        // const SizedBox(height: 8),
        SizedBox(
          height: 25,
          width: double.infinity,
          child: WebViewWidget(controller: controller),
        ),
        const SizedBox(height: 8),
        // SelectableText(resultText),
        Flexible(child: ListView(children: _buildList())),
      ],
    );
  }
}
