import 'dart:convert';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/proto/response/generate_otp_response.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  static const wmtMfsKey = 'wmt-mfs';

  String? _phoneNumber;
  String? _pin;
  String? _authCode;

  String? _wmtMfs;

  void auth() async {
    // var encryptStr = RSAHelper.encrypt(
    //     '123456:0d63104e-de16-49b7-8c07-aee6ef8d53f8', Config.rsaPublicKey);
    // logger.i('message: $encryptStr');
    // return;
    // var password = RSAHelper.encrypt(
    //     '123456:0d63104e-de16-49b7-8c07-aee6ef8d53f8', Config.rsaPublicKey);
    // var pin = RSAHelper.encrypt(
    //     '123456:0d63104e-de16-49b7-8c07-abc6ef8d53f8', Config.rsaPublicKey);

    // var formData = [
    //   '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber ?? '')}',
    //   '${Uri.encodeQueryComponent('password')}=${Uri.encodeQueryComponent(password)}',
    //   '${Uri.encodeQueryComponent('pin')}=${Uri.encodeQueryComponent(pin)}',
    // ].join('&');

    // logger.i('data: $formData');
    // return;
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }

    EasyLoading.show(status: 'loading...');
    logger.i('request auth code start');
    logger.i('Phone number: $_phoneNumber');

    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/generate-otp', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders()
      ..addAll({
        "user-agent": "okhttp/4.9.0",
        wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await http.get(url, headers: headers);
      _wmtMfs = response.headers[wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return;
      }
      EasyLoading.showInfo('send auth code success.');
      logger.i('request auth code success');
    } catch (e) {
      logger.e('auth err: $e');
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<String?> getToken() async {
    logger.i('get token start.');
    logger.i('Phone number: $_phoneNumber');
    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/security-token', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders()
      ..addAll({
        'user-agent': 'okhttp/4.9.0',
        wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await http.get(url, headers: headers);
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
    } catch (e) {
      logger.e('get token err: $e');
      EasyLoading.showError('get token err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return null;
    }
  }

  Future<bool> confirmAuthCode() async {
    final url = Uri.https(Config.host, 'wmt-mfs-otp/confirm-otp');
    final headers = Config.getHeaders()
      ..addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
        "user-agent": "okhttp/4.9.0",
        wmtMfsKey: _wmtMfs ?? '',
      });
    var formData = [
      '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber ?? '')}',
      '${Uri.encodeQueryComponent('otp')}=${Uri.encodeQueryComponent(_authCode ?? '')}',
    ].join('&');

    logger.i('confim auth code start');
    logger.i('Phone number: $_phoneNumber');
    logger.i('auth code: $_authCode');
    logger.i('form data: $formData');
    final response = await http.post(
      url,
      headers: headers,
      body: formData,
    );
    _wmtMfs = response.headers[wmtMfsKey] ?? _wmtMfs;
    logger.i('Response status: ${response.statusCode}');
    logger.i('Response body: ${response.body}');
    logger.i('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

    final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
    if (response.statusCode != 200 || !resBody.isSuccess()) {
      logger.e('confim auth code errr: ${response.statusCode}');
      EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}');
      return false;
    }
    logger.i('confim auth code success');
    return true;
  }

  void login() async {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }
    if (_pin?.isEmpty ?? true) {
      EasyLoading.showToast('password is empty.');
      return;
    }
    if (_authCode?.isEmpty ?? true) {
      EasyLoading.showToast('auth code is empty.');
      return;
    }

    EasyLoading.show(status: 'loading...');

    try {
      // 验证验证码
      if (!await confirmAuthCode()) {
        EasyLoading.showError('confirm auth code fail.');
        return;
      }

      var token1 = await getToken();
      var token2 = await getToken();

      // const codec = Utf8Codec(allowMalformed: true);
      // var helper = RsaKeyHelper();
      // var publicKey = helper.parsePublicKeyFromPem(Config.rsaPublicKey);
      // var password =
      //     base64Encode(codec.encode(encrypt('$_pin:$token1', publicKey)));
      // var pin = base64Encode(codec.encode(encrypt('$_pin:$token2', publicKey)));
      var password = RSAHelper.encrypt('$_pin:$token1', Config.rsaPublicKey);
      var pin = RSAHelper.encrypt('$_pin:$token2', Config.rsaPublicKey);

      var formData = [
        '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber ?? '')}',
        '${Uri.encodeQueryComponent('password')}=${Uri.encodeQueryComponent(password)}',
        '${Uri.encodeQueryComponent('pin')}=${Uri.encodeQueryComponent(pin)}',
      ].join('&');

      logger.i('token1: $token1, token2: $token2');
      logger.i('Phone number: $_phoneNumber');
      logger.i('login start');
      logger.i('form data: $formData');

      final url = Uri.https(Config.host, 'v2/mfs-customer/login');
      final headers = Config.getHeaders()
        ..addAll({
          'Content-Type': 'application/x-www-form-urlencoded',
          'user-agent': 'okhttp/4.9.0',
          wmtMfsKey: _wmtMfs ?? '',
        });

      final response = await http.post(
        url,
        headers: headers,
        body: formData,
      );
      _wmtMfs = response.headers[wmtMfsKey] ?? _wmtMfs;
      // logger.i('auth code: $_authCode');
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        logger.e('login err: ${response.statusCode}');
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return;
      }

      logger.i('login success');
      // logger.i(base64);
    } catch (e) {
      logger.e('err: $e');
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  InputDecoration buildInputDecoration(String hit, IconData icon) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      prefixIcon: Icon(
        icon,
        color: Colors.blue,
      ),
      labelText: hit,
      hintText: "Input $hit",
      // suffix: Text(
      //   unit,
      //   style: TextStyle(color: Colors.grey.shade200),
      // ),
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
            child: TextFormField(
              controller: TextEditingController()..text = _phoneNumber ?? "",
              onChanged: (value) => _phoneNumber = value,
              // validator: _validator,
              keyboardType: TextInputType.number,
              decoration: buildInputDecoration("phone number", Icons.phone),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: TextFormField(
              controller: TextEditingController()..text = _pin ?? "",
              onChanged: (value) => _pin = value,
              // validator: _validator,
              keyboardType: TextInputType.number,
              decoration: buildInputDecoration("pin", Icons.password),
            ),
          ),
          OutlinedButton(
              onPressed: auth, child: const Text('request auth code.')),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: TextFormField(
              controller: TextEditingController()..text = _authCode ?? "",
              onChanged: (value) => _authCode = value,
              // validator: _validator,
              keyboardType: TextInputType.number,
              decoration: buildInputDecoration("auth code", Icons.security),
            ),
          ),
          OutlinedButton(onPressed: login, child: const Text('login')),
        ],
      ),
    );
  }
}
