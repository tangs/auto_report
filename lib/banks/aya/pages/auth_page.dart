import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:auto_report/banks/aya/config/aeskey_getter.dart';
import 'package:auto_report/banks/aya/config/config.dart';
import 'package:auto_report/banks/aya/data/account/account_data.dart';
import 'package:auto_report/banks/aya/network/sender.dart';
import 'package:auto_report/banks/aya/pages/qr_data.dart';
import 'package:auto_report/banks/aya/utils/sentry_header_generator.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:auto_report/widges/platform_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class AuthPage extends StatefulWidget {
  final List<GetPlatformsResponseData?>? platforms;
  final String? phoneNumber;
  final String? id;
  final String? pin;
  final String? token;
  final String? remark;

  const AuthPage({
    super.key,
    required this.platforms,
    this.phoneNumber,
    this.id,
    this.pin,
    this.token,
    this.remark,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String? _phoneNumber;
  String? _id;
  String? _pin;
  String? _otpCode;

  String? _token;
  String? _remark;

  GetPlatformsResponseData? _platformsResponseData;

  late Sender _sender;

  final _models = ['google Pixel 5', 'google Pixel 6', 'google Pixel 5 pro', 'google Pixel 7', 'google Pixel 8', 'google Pixel 9'];
  // final _osVersions = ['12', '13', '14'];

  bool _hasLogin = false;
  bool _hasAuth = false;

  @override
  void initState() {
    super.initState();

    _phoneNumber = widget.phoneNumber ?? '';
    _id = widget.id ?? '';
    _pin = widget.pin ?? '';

    // _token = widget.token ?? '';
    _token = '';
    _remark = widget.remark ?? '';

    final ran = Random.secure();

    final headers = SentryHeaderGenerator.generateSentryHeaders("Win Kyi", "125923");
    final firebaseToken = generateFirebaseTokenLikeExample();
    final deviceId = generateRandomDeviceId();

    final authorization = headers['Authorization'] ?? '';
    final sentryTrace = headers['Sentry-Trace'] ?? '';
    final baggage = headers['Baggage'] ?? '';
    final model = _models[ran.nextInt(_models.length)];

    logger.i("Authorization: $authorization");
    logger.i("Sentry-Trace: $sentryTrace");
    logger.i("Baggage: $baggage");

    logger.i("firebaseToken: $firebaseToken");
    logger.i("deviceId: $deviceId");

    _sender = Sender(
      firebase: firebaseToken,
      deviceId: deviceId,
      deviceName: model,
      authorization: authorization,
      sentryTrace: sentryTrace,
      baggage: baggage,
    );
  }

  String generateRandomDeviceId() {
    final Random random = Random();
    const String hexChars = '0123456789abcdef';

    // 循环 16 次，每次从 hexChars 中随机取一个字符
    return List.generate(16, (index) => hexChars[random.nextInt(16)]).join();
  }


  String generateFirebaseTokenLikeExample() {
    final Random random = Random();
    
    // Firebase Token 标准字符集
    const String chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_';

    // 内部辅助函数：生成指定长度的随机字符串
    String getRandomString(int length) {
      return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
    }

    // 1. 生成第一部分：22位随机字符
    String part1 = getRandomString(22);

    // 2. 生成第二部分：总长 140 位
    // 前缀固定为 "APA91b" (6位)
    String prefix2 = "APA91b";
    // 剩余需要生成的长度 = 140 - 6 = 134 位
    String body2 = getRandomString(134);
    
    String part2 = "$prefix2$body2";

    // 3. 用冒号拼接
    return "$part1:$part2";
  }

  void _requestOtp() async {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }

    final phoneNumber = _phoneNumber!;

    EasyLoading.show(status: 'loading...');
    // logger.i('request auth code start');
    // logger.i('Phone number: $_phoneNumber');

    try {
      
      await _sender.sendDeviceInfo();
      // {
      //   final ret = await _sender.geustLoginMsg();

      //   if (!ret) {
      //     EasyLoading.showToast('guest login fail.');
      //     return;
      //   }
      // }
      // {
      //   await _sender.queryLoginMode(phoneNumber);
      // }
      // {
      //   final ret = await _sender.requestOtpMsg(phoneNumber);

      //   if (!ret) {
      //     EasyLoading.showToast('request opt fail.');
      //     return;
      //   }
      // }

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
    if (_pin?.isEmpty ?? true) {
      EasyLoading.showToast('pin is empty.');
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

  String qrSerialNo = '';
  String businessUniqueId = '';
  
  void _login() async {
    if (!_checkInput()) return;

    final phoneNumber = _phoneNumber!;
    final id = _id!.toUpperCase();
    final otpCode = _otpCode!;

    EasyLoading.show(status: 'loading...');
    try {
      {

        // var needVerifyNrc = false;
        // {
        //   final ret1 = await _sender.finishQRCode(
        //       phoneNumber, qrSerialNo, businessUniqueId);
        //   logger.i('finish qrcode ret: ${ret1.item1}');

        //   needVerifyNrc = ret1.item3?.nextVerifyType == 'NRC';

        //   if (!ret1.item1) return;
        // }

        // if (needVerifyNrc) {
        //   final ret1 =
        //       await _sender.verifyNrc(phoneNumber, businessUniqueId, id);
        //   logger.i('verify nrc ret: ${ret1.item1}');
        //   if (!ret1.item1) return;
        // }

        // {
        //   final ret =
        //       await _sender.loginMsg(phoneNumber, otpCode, businessUniqueId);
        //   if (!ret.item1) {
        //     EasyLoading.showToast('login fail.msg: ${ret.item2}');
        //     logger.i('login fail.msg: ${ret.item2}');
        //     return;
        //   }
        // }

        // {
        //   final ret1 =
        //       await _sender.verifyNrc(phoneNumber, businessUniqueId, id);
        //   logger.i('verify nrc ret: ${ret1.item1}');
        //   if (!ret1.item1) return;
        // }

        // 验证身份证
        // {
        //   final ret = await _sender.identityVerificationMsg(phoneNumber, id);
        //   if (!ret) {
        //     EasyLoading.showToast('identity verification fail.');
        //     logger.i('identity verification fail.');
        //     return;
        //   }
        // }

        // 新设备登录
        // {
        //   final ret = await _sender.newAutoLoginMsg(
        //       phoneNumber, businessUniqueId, false);
        //   if (!ret) {
        //     EasyLoading.showToast('new login fail.');
        //     logger.i('new login fail.');
        //     return;
        //   }
        // }

        // {
        //   final ret2 =
        //       await _sender.loginMsg1(phoneNumber, otpCode, businessUniqueId);
        //   if (!ret2.item1) {
        //     EasyLoading.showToast('login fail 1.');
        //     logger.i('login fail 1.');
        //     return;
        //   }
        //   // res1 = ret2.item3!;
        // }

        // 验证身份证
        // {
        //   final ret = await _sender.identityVerificationMsg(phoneNumber, id);
        //   if (!ret) {
        //     EasyLoading.showToast('identity verification fail.');
        //     logger.i('identity verification fail.');
        //     return;
        //   }
        // }

        // final ret2 = await _sender.newAutoLoginMsg(
        //     phoneNumber, res.businessUniqueId!, false);
        // if (res1?.nrcVerifyEnable == '1') {
        //   // 新设备
        //   _sender.token = res1?.userInfo!.token;

        //   // 验证身份证
        //   {
        //     final ret = await _sender.identityVerificationMsg(phoneNumber, id);
        //     if (!ret) {
        //       EasyLoading.showToast('identity verification fail.');
        //       logger.i('identity verification fail.');
        //       return;
        //     }
        //   }

        //   // // 新设备登录
        //   // {
        //   //   final ret = await _sender.newAutoLoginMsg(phoneNumber, false);
        //   //   if (!ret) {
        //   //     EasyLoading.showToast('new login fail.');
        //   //     logger.i('new login fail.');
        //   //     return;
        //   //   }
        //   // }
        // }

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
        // const path = 'api/pay/payinfo_apply';
        // const path = 'api/pay/tool_apply';
        const path = 'api/pay/purview_apply';
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
      // const path = 'api/pay/payinfo_verify';
      // const path = 'api/pay/tool_verify';
      const path = 'api/pay/purview_verify';
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
                onChanged: (value) => _phoneNumber = value.trim(),
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("phone number", Icons.phone),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              child: TextFormField(
                controller: TextEditingController()..text = _id ?? "",
                onChanged: (value) => _id = value.trim(),
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("id", Icons.password),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
              child: TextFormField(
                controller: TextEditingController()..text = _pin ?? "",
                onChanged: (value) => _pin = value.trim(),
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
                onChanged: (value) => _otpCode = value.trim(),
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("otp code", Icons.security),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _remark ?? "",
                onChanged: (value) => _remark = value.trim(),
                // validator: _validator,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration("remark", Icons.tag),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 15)),
            Row(
              children: [
                const Spacer(),
                // OutlinedButton(
                //   onPressed: _questQrCode,
                //   // onPressed: _login,
                //   child: const Text('request qr code'),
                // ),
                const Padding(padding: EdgeInsets.only(left: 15, right: 15)),
                OutlinedButton(
                  onPressed: _hasLogin ? null : _login,
                  // onPressed: _login,
                  child: Text(_hasLogin ? 'logined aya' : 'login aya'),
                ),
                const Padding(padding: EdgeInsets.only(left: 15, right: 15)),
                OutlinedButton(
                  onPressed: _hasAuth ? null : _auth,
                  // onPressed: _auth,
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
                          pin: _pin!,
                          id: _id!,
                          authCode: _otpCode!,
                          // isWmtMfsInvalid: false,
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
