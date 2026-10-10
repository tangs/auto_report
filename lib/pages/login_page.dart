import 'dart:convert';

import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/banks/wave/config/config.dart';
import 'package:auto_report/network/statistical_sender.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:auto_report/widges/bank_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.title});

  final String title;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // String? _platform = '4e70ffa82fbe886e3c4ac00ac374c29b';
  String? _platform = '';
  bool _logging = false;
  // String? _platform;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      setState(() => _platform = '528c87bb4063166c1e2eee978f044dd1');
    }

    autoJumpPage();
  }

  void autoJumpPage() async {
    await Future.delayed(const Duration(microseconds: 10));

    if (!mounted) return;
    if (!GlobalConfig.bankType.needLogin) {
      final homePath = GlobalConfig.bankType.homePath;
      Navigator.of(context).pushReplacementNamed(homePath);
    }
  }

  bool get _useLocalTestBackend =>
      _platform?.trim().toLowerCase() == GlobalConfig.localTestPlatform;

  String get _localPlatformName {
    switch (GlobalConfig.bankType) {
      case BankType.wave:
        return 'WavePay';
      case BankType.kbz:
        return 'KBZPay';
      case BankType.kbiz:
        return 'KBZ';
      case BankType.aya:
        return 'AYA';
    }
  }

  Future<GetPlatformsResponse?> _getLocalTestPlatform() async {
    const backendUrl = GlobalConfig.localTestBackendUrl;
    try {
      final response = await http
          .get(Uri.parse('$backendUrl/health'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw Exception('health check returned ${response.statusCode}');
      }

      StatisticalSender.host = backendUrl;
      logger.i('using local test backend: $backendUrl');
      return GetPlatformsResponse(
        status: true,
        msg: 'success',
        logUrl: backendUrl,
        data: [
          GetPlatformsResponseData(
            name: _localPlatformName,
            url: backendUrl,
            key: GlobalConfig.localTestPlatform,
            mark: GlobalConfig.localTestPlatform,
          ),
        ],
      );
    } catch (e, stackTrace) {
      logger.e('local test backend unavailable: $e', stackTrace: stackTrace);
      EasyLoading.showError('local test backend unavailable.');
      return null;
    }
  }

  Future<GetPlatformsResponse?> getPlatformUrl() async {
    if (_useLocalTestBackend) {
      return _getLocalTestPlatform();
    }

    // final url = Uri.http('www.diyibuyu.com', 'api/getPlatformUrl');
    // final url = Uri.http('www.diyibuyu.com', 'api/getAllPlatformUrl');
    final url = Uri.http('www.diyibuyu.com', 'api/getGamePlatformUrl');

    final response = await Future.any([
      http.post(url, body: {
        'platform': '$_platform',
      }),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);

    if (response is! http.Response) {
      EasyLoading.showError('timeout');
      logger.i('timeout');
      return null;
    }

    final body = response.body.replaceAll(RegExp('[\\\\"]'), '');
    logger.i('res body: $body');

    final decodeStr = RSAHelper.decrypt(body, Config.rsaPrivateKeyReport);
    logger.i('decode str: $decodeStr');
    final json = jsonDecode(decodeStr);
    logger.i('data: $json');

    final resData = GetPlatformsResponse.fromJson(json);
    if (resData.status != true || resData.msg != 'success') {
      EasyLoading.showToast(
          'login err. status: ${resData.status}, msg: ${resData.msg}');
      return null;
    }

    if (resData.logUrl?.isEmpty ?? true) {
      EasyLoading.showToast('log url is empty.');
      return null;
    }
    StatisticalSender.host = resData.logUrl!;

    return resData;
  }

  void login() async {
    if (_platform?.isEmpty ?? true) {
      EasyLoading.showToast('platform must not empty.');
    }

    setState(() => _logging = true);

    try {
      GetPlatformsResponse? resData;
      if (GlobalConfig.bankType.needLogin) {
        resData = await getPlatformUrl();
        if (resData == null) return;
      }

      if (!mounted) return;

      final homePath = GlobalConfig.bankType.homePath;
      Navigator.of(context).pushReplacementNamed(
        homePath,
        arguments: resData?.data,
      );
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
      EasyLoading.showToast('login fail.');
    } finally {
      setState(() => _logging = false);
    }
  }

  InputDecoration _buildInputDecoration(String hit, IconData icon) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      prefixIcon: Icon(
        icon,
        color: Colors.blue,
      ),
      labelText: hit,
      hintText: "Input $hit",
    );
  }

  @override
  Widget build(BuildContext context) {
    // final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextFormField(
              controller: TextEditingController()..text = _platform ?? "",
              onChanged: (value) => _platform = value,
              // validator: _validator,
              keyboardType: TextInputType.text,
              decoration: _buildInputDecoration("platform", Icons.login_sharp),
            ),
          ),
          Visibility(
            visible: kDebugMode,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 0, 20),
              child: BankSelector(
                onValueChangedCallback: (bank) => GlobalConfig.bankType = bank,
              ),
            ),
          ),
          Center(
            child: OutlinedButton(
              onPressed: _logging ? null : login,
              child: Text(_logging ? 'logging' : 'login'),
            ),
          ),
        ],
      ),
    );
  }
}
