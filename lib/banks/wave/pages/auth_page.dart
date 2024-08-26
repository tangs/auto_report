import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:auto_report/banks/wave/config/config.dart';
import 'package:auto_report/banks/wave/data/account/account_data.dart';
import 'package:auto_report/banks/wave/data/proto/response/generate_otp_response.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:auto_report/widges/platform_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class AuthPage extends StatefulWidget {
  final List<GetPlatformsResponseData?>? platforms;
  final String? phoneNumber;
  final String? pin;
  final String? token;
  final String? remark;

  const AuthPage({
    super.key,
    required this.platforms,
    this.phoneNumber,
    this.pin,
    this.token,
    this.remark,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String? _phoneNumber;
  String? _pin;
  String? _otpCode;
  String? _token;
  String? _remark;

  String? _wmtMfs;

  GetPlatformsResponseData? _platformsResponseData;

  late String _deviceId;
  late String _model;
  late String _osVersion;

  final _modes = ['Pixel 5', 'Pixel 6', 'Pixel 5 pro'];
  final _osVersions = ['12', '13', '14'];

  bool _hasLogin = false;
  bool _hasAuth = false;

  @override
  void initState() {
    super.initState();

    _phoneNumber = widget.phoneNumber ?? '';
    _pin = widget.pin ?? '';

    // _token = widget.token ?? '';
    _token = '';
    _remark = widget.remark ?? '';

    if (_token!.isEmpty) {
      final sb = StringBuffer();
      final rand = Random();
      for (var i = 0; i < 32; ++i) {
        if (rand.nextBool()) {
          sb.write(String.fromCharCode(0x61 + rand.nextInt(26)));
        } else {
          sb.write(String.fromCharCode(0x30 + rand.nextInt(10)));
        }
      }
      _token = sb.toString();
    }
    init();
  }

  void init() async {
    EasyLoading.show();
    // generate device id
    var deviceId = '';
    final ran = Random.secure();
    for (var i = 0; i < 40; ++i) {
      final num = ran.nextInt(16);
      deviceId += num.toRadixString(16);
    }

    _model = _modes[ran.nextInt(_modes.length)];
    _osVersion = _osVersions[ran.nextInt(_osVersions.length)];
    _deviceId = deviceId;

    if (Platform.isAndroid) {
      final deviceInfoPlugin = await DeviceInfoPlugin().androidInfo;
      _model = deviceInfoPlugin.model;
      _osVersion = deviceInfoPlugin.version.release;
    }

    logger.i('device id: $_deviceId, model: $_model, os version: $_osVersion');
    EasyLoading.dismiss();
  }

  void _requestOtp() async {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }

    EasyLoading.show(status: 'loading...');
    logger.i('request auth code start');
    logger.i('Phone number: $_phoneNumber');

    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/generate-otp', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "user-agent": "okhttp/4.9.0",
        Config.wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return;
      }
      EasyLoading.showInfo('send auth code success.');
      logger.i('request auth code success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<String?> _generateToken() async {
    logger.i('get token start.');
    logger.i('Phone number: $_phoneNumber');
    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/security-token', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        'user-agent': 'okhttp/4.9.0',
        Config.wmtMfsKey: _wmtMfs ?? '',
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
      EasyLoading.showInfo('send auth code success.');
      logger.i('get token success.');
      return resBody.responseMap?.securityCounter;
    } catch (e, stackTrace) {
      logger.e('get token err: $e', stackTrace: stackTrace);
      EasyLoading.showError('get token err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return null;
    }
  }

  Future<bool> _confirmAuthCode() async {
    final url = Uri.https(Config.host, 'wmt-mfs-otp/confirm-otp');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        // 'Content-Type': 'application/x-www-form-urlencoded',
        "user-agent": "okhttp/4.9.0",
        Config.wmtMfsKey: _wmtMfs ?? '',
      });
    // final formData = [
    //   '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber ?? '')}',
    //   '${Uri.encodeQueryComponent('otp')}=${Uri.encodeQueryComponent(_otpCode ?? '')}',
    // ].join('&');

    final formData = {
      'msisdn': _phoneNumber!,
      'otp': _otpCode!,
    };

    logger.i('confim auth code start');
    logger.i('Phone number: $_phoneNumber');
    logger.i('auth code: $_otpCode');
    logger.i('form data: $formData');
    final response = await Future.any([
      http.post(url, headers: headers, body: formData),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);

    if (response is! http.Response) {
      EasyLoading.showError('firm auth timeout');
      logger.i('firm auth timeout');
      return false;
    }

    _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
    logger.i('Response status: ${response.statusCode}');
    logger.i('Response body: ${response.body}');
    logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

    final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
    if (response.statusCode != 200 || !resBody.isSuccess()) {
      logger.e('confim auth code errr: ${response.statusCode}',
          stackTrace: StackTrace.current);
      EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}');
      return false;
    }
    logger.i('confim auth code success');
    return true;
  }

  bool _checkInput({bool checkOtp = true}) {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return false;
    }
    if (_phoneNumber?.startsWith('0') ?? false) {
      EasyLoading.showToast('phone number must remove prefix 0.');
      return false;
    }
    if (_pin?.isEmpty ?? true) {
      EasyLoading.showToast('pin is empty.');
      return false;
    }
    if (checkOtp && (_otpCode?.isEmpty ?? true)) {
      EasyLoading.showToast('auth code is empty.');
      return false;
    }
    if (_token?.isEmpty ?? true) {
      EasyLoading.showToast('token is empty.');
      return false;
    }
    if (_remark?.isEmpty ?? true) {
      EasyLoading.showToast('remark is empty.');
      return false;
    }
    return true;
  }

  void _login() async {
    if (!_checkInput()) return;

    EasyLoading.show(status: 'loading...');
    try {
      // 验证验证码
      if (!await _confirmAuthCode()) {
        // EasyLoading.showError('confirm auth code fail.');
        return;
      }

      final token1 = await _generateToken();
      final token2 = await _generateToken();

      if (token1 == null || token2 == null) {
        EasyLoading.showError('get token timeout.');
        return;
      }

      final password = RSAHelper.encrypt('$_pin:$token1', Config.rsaPublicKey);
      final pin = RSAHelper.encrypt('$_pin:$token2', Config.rsaPublicKey);

      // var formData = [
      //   '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber!)}',
      //   '${Uri.encodeQueryComponent('password')}=${Uri.encodeQueryComponent(password)}',
      //   '${Uri.encodeQueryComponent('pin')}=${Uri.encodeQueryComponent(pin)}',
      // ].join('&');
      final formData = {
        'msisdn': _phoneNumber!,
        'password': password,
        'pin': pin,
      };

      logger.i('token1: $token1, token2: $token2');
      logger.i('Phone number: $_phoneNumber');
      logger.i('login wave start');
      logger.i('form data: $formData');

      final url = Uri.https(Config.host, 'v2/mfs-customer/login');
      final headers = Config.getHeaders(
          deviceid: _deviceId, model: _model, osversion: _osVersion)
        ..addAll({
          // 'Content-Type': 'application/x-www-form-urlencoded',
          'user-agent': 'okhttp/4.9.0',
          Config.wmtMfsKey: _wmtMfs ?? '',
        });

      final response = await Future.any([
        http.post(url, headers: headers, body: formData),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('login timeout');
        logger.i('login timeout');
        return;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      if (response.statusCode != 200) {
        logger.e('login wave err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        EasyLoading.showToast('login err: ${response.statusCode}');
        return;
      }

      logger.i('login wave success');
      setState(() => _hasLogin = true);
    } catch (e, stackTrace) {
      logger.e('err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  void _auth() async {
    if (!_checkInput(checkOtp: false)) return;

    try {
      EasyLoading.show(status: 'loading...');
      {
        final host = _platformsResponseData!.url!.replaceAll('http://', '');
        const path = 'api/pay/payinfo_apply';
        final url = Uri.http(host, path, {
          'token': _token,
          'phone': _phoneNumber,
          'platform': 'WavePay',
          'remark': _remark,
        });
        logger.i('url: ${url.toString()}');
        logger.i('host: $host, path: $path');
        final response = await Future.any([
          http.post(url),
          Future.delayed(
              const Duration(seconds: Config.httpRequestTimeoutSeconds)),
        ]);

        if (response is! http.Response) {
          EasyLoading.showError('auth timeout');
          logger.i('auth timeout');
          return;
        }

        final body = response.body;
        logger.i('res body: $body');

        final res = ReportGeneralResponse.fromJson(jsonDecode(body));
        if (res.status != 'T') {
          EasyLoading.showError(
              'auth fail. code: ${res.status}, msg: ${res.message}');
          return;
        }
      }
      EasyLoading.show(status: 'wait server auth');
      for (var i = 0; i < 30; ++i) {
        final host = _platformsResponseData!.url!.replaceAll('http://', '');
        const path = 'api/pay/payinfo_verify';
        final url = Uri.http(host, path, {
          'token': _token,
          'phone': _phoneNumber,
          'platform': 'WavePay',
        });
        logger.i('url: ${url.toString()}');
        logger.i('host: $host, path: $path');
        final response = await Future.any([
          http.post(url),
          Future.delayed(
              const Duration(seconds: Config.httpRequestTimeoutSeconds)),
        ]);

        if (response is! http.Response) {
          EasyLoading.showError('auth timeout');
          logger.i('auth timeout');
          return;
        }

        final body = response.body;
        logger.i('res body: $body');

        final res = ReportGeneralResponse.fromJson(jsonDecode(body));
        if (res.status == 'T') {
          EasyLoading.showInfo('auth success.');
          break;
        }
        if (res.status == 'F') {
          EasyLoading.showError(
              'auth fail. code: ${res.status}, msg: ${res.message}');
          break;
        }
        if (res.status == 'W') {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      setState(() => _hasAuth = true);
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    } finally {
      EasyLoading.dismiss();
    }
  }

  InputDecoration _buildInputDecoration(String hit, IconData icon) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, color: Colors.blue),
      labelText: hit,
      hintText: "Input $hit",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('auth'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: PlatformSelector(
                platforms: widget.platforms,
                onValueChangedCallback: (platform) =>
                    _platformsResponseData = platform,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _phoneNumber ?? "",
                onChanged: (value) => _phoneNumber = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("phone number", Icons.phone),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              child: TextFormField(
                controller: TextEditingController()..text = _pin ?? "",
                onChanged: (value) => _pin = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("pin", Icons.password),
              ),
            ),
            OutlinedButton(
                onPressed: _requestOtp, child: const Text('request otp code.')),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _otpCode ?? "",
                onChanged: (value) => _otpCode = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("otp code", Icons.security),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _remark ?? "",
                onChanged: (value) => _remark = value,
                // validator: _validator,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration("remark", Icons.tag),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 15)),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _hasLogin ? null : _login,
                  child: Text(_hasLogin ? 'logined wave' : 'login wave'),
                ),
                const Padding(padding: EdgeInsets.only(left: 15, right: 15)),
                OutlinedButton(
                  onPressed: _hasAuth ? null : _auth,
                  child: Text(_hasAuth ? 'login report' : 'login report'),
                ),
                const Spacer(),
              ],
            ),
            const Padding(padding: EdgeInsets.fromLTRB(0, 15, 0, 0)),
            OutlinedButton(
              onPressed: (!_hasAuth || !_hasLogin)
                  ? null
                  : () async {
                      if (!context.mounted) return;
                      if (!_checkInput()) return;
                      Navigator.pop(
                        context,
                        AccountData(
                          token: _token!,
                          remark: _remark!,
                          platformName: _platformsResponseData!.name!,
                          platformUrl: _platformsResponseData!.url!,
                          platformKey: _platformsResponseData!.key!,
                          platformMark: _platformsResponseData!.mark!,
                          phoneNumber: _phoneNumber!,
                          pin: _pin!,
                          authCode: _otpCode!,
                          wmtMfs: _wmtMfs!,
                          isWmtMfsInvalid: false,
                          deviceId: _deviceId,
                          model: _model,
                          osVersion: _osVersion,
                        ),
                      );
                    },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
