import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/account/account_data.dart';
import 'package:auto_report/banks/kbz/network/sender.dart';
import 'package:auto_report/banks/kbz/utils/aes_key_generator.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/widges/platform_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AuthPage extends StatefulWidget {
  final List<GetPlatformsResponseData?>? platforms;
  final String? phoneNumber;
  final String? id;
  final String? token;
  final String? remark;

  const AuthPage({
    super.key,
    required this.platforms,
    this.phoneNumber,
    this.id,
    this.token,
    this.remark,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String? _phoneNumber;
  String? _id;
  String? _otpCode;

  String? _token;
  String? _remark;

  GetPlatformsResponseData? _platformsResponseData;

  late Sender _sender;

  final _models = ['Pixel 5', 'Pixel 6', 'Pixel 5 pro'];
  // final _osVersions = ['12', '13', '14'];

  bool _hasLogin = false;
  bool _hasAuth = false;

  @override
  void initState() {
    super.initState();

    _phoneNumber = widget.phoneNumber ?? '';
    _id = widget.id ?? '';

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

    // generate device id
    var deviceId = '';
    final ran = Random.secure();
    for (var i = 0; i < 16; ++i) {
      final num = ran.nextInt(16);
      deviceId += num.toRadixString(16);
    }

    final model = _models[ran.nextInt(_models.length)];
    // _osVersion = _osVersions[ran.nextInt(_osVersions.length)];
    // final deviceId = deviceId;
    final uuid = const Uuid().v4();

    logger.i('device id: $deviceId, model: $model, uuid: $uuid');
    logger.i('time: ${DateTime.now().toUtc().millisecondsSinceEpoch}');

    final aesKey = AesKeyGenerator.generateRandomKey();
    final ivKey = AesKeyGenerator.getRandom(16);

    _sender = Sender(
        aesKey: aesKey,
        ivKey: ivKey,
        deviceId: deviceId,
        uuid: uuid,
        model: model);

    logger.i('aes key: $aesKey, iv: $ivKey');
  }

  void _requestOtp() async {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }

    final phoneNumber = _phoneNumber!;

    EasyLoading.show(status: 'loading...');
    logger.i('request auth code start');
    logger.i('Phone number: $_phoneNumber');

    try {
      {
        final ret = await _sender.geustLoginMsg();

        if (!ret) {
          EasyLoading.showToast('guest login fail.');
          return;
        }
      }
      {
        final ret = await _sender.requestOtpMsg(phoneNumber);

        if (!ret) {
          EasyLoading.showToast('request opt fail.');
          return;
        }
      }

      // logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      // final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      // if (response.statusCode != 200 || !resBody.isSuccess()) {
      //   EasyLoading.showToast(
      //       resBody.message ?? 'err code: ${response.statusCode}');
      //   return;
      // }
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

  bool _checkInput({bool checkOtp = true}) {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return false;
    }
    // if (_phoneNumber?.startsWith('0') ?? false) {
    //   EasyLoading.showToast('phone number must remove prefix 0.');
    //   return false;
    // }
    if (_id?.isEmpty ?? true) {
      EasyLoading.showToast('id is empty.');
      return false;
    }
    if (checkOtp && (_otpCode?.isEmpty ?? true)) {
      EasyLoading.showToast('auth code is empty.');
      return false;
    }
    // if (_token?.isEmpty ?? true) {
    //   EasyLoading.showToast('token is empty.');
    //   return false;
    // }
    // if (_remark?.isEmpty ?? true) {
    //   EasyLoading.showToast('remark is empty.');
    //   return false;
    // }
    return true;
  }

  void _login() async {
    if (!_checkInput()) return;

    final phoneNumber = _phoneNumber!;
    final id = _id!;
    final otpCode = _otpCode!;

    EasyLoading.show(status: 'loading...');
    try {
      {
        final ret = await _sender.loginMsg(phoneNumber, otpCode);
        if (!ret.item1) {
          EasyLoading.showToast('login fail.msg: ${ret.item2}');
          logger.i('login fail.msg: ${ret.item2}');
          return;
        }

        final res = ret.item3!;

        if (res.nrcVerifyEnable == '1') {
          // 新设备
          _sender.token = res.userInfo!.token;

          // 验证身份证
          {
            final ret = await _sender.identityVerificationMsg(phoneNumber, id);
            if (!ret) {
              EasyLoading.showToast('identity verification fail.');
              logger.i('identity verification fail.');
              return;
            }
          }

          // 新设备登录
          {
            final ret = await _sender.newAutoLoginMsg(phoneNumber, false);
            if (!ret) {
              EasyLoading.showToast('new login fail.');
              logger.i('new login fail.');
              return;
            }
          }
        } else {
          _sender.token = res.token;
        }

        // // 获取余额
        // {
        //   final ret = await _sender.queryCustomerBalanceMsg(phoneNumber);
        //   if (!ret) {
        //     EasyLoading.showToast('query customer balance fail.');
        //     logger.i('query customer balance fail.');
        //     return;
        //   }
        // }
      }
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
          'platform': 'KBZ',
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

      final host = _platformsResponseData!.url!.replaceAll('http://', '');
      const path = 'api/pay/payinfo_verify';
      final url = Uri.http(host, path, {
        'token': _token,
        'phone': _phoneNumber,
        'platform': 'KBZ',
      });
      logger.i('url: ${url.toString()}');
      logger.i('host: $host, path: $path');
      for (var i = 0; i < 100; ++i) {
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
                controller: TextEditingController()..text = _id ?? "",
                onChanged: (value) => _id = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("id", Icons.password),
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
                  child: Text(_hasLogin ? 'logined kbz' : 'login kbz'),
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
                          sender: _sender,
                          token: _token!,
                          remark: _remark!,
                          platformName: _platformsResponseData!.name!,
                          platformUrl: _platformsResponseData!.url!,
                          platformKey: _platformsResponseData!.key!,
                          platformMark: _platformsResponseData!.mark!,
                          phoneNumber: _phoneNumber!,
                          pin: _id!,
                          authCode: _otpCode!,
                          isWmtMfsInvalid: false,
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
