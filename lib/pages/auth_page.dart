import 'dart:convert';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/proto/response/generate_otp_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:rsa_encrypt/rsa_encrypt.dart';

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
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }
    EasyLoading.show(status: 'loading...');
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

      logger.i('auto');
      logger.i('Phone number: $_phoneNumber');
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || resBody.statusCode != 'Success') {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        // EasyLoading.dismiss();
        return;
      }
      EasyLoading.showInfo('send auth code success.');
    } catch (e) {
      logger.e('auth err: $e');
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<String?> getAuthCode() async {
    final url = Uri.https(
        Config.host, 'wmt-mfs-otp/security-token', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders()
      ..addAll({
        'user-agent': 'okhttp/4.9.0',
        wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await http.get(url, headers: headers);
      print('Phone number: $_phoneNumber');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || resBody.statusCode != 'Success') {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        // EasyLoading.dismiss();
        return null;
      }
      EasyLoading.showInfo('send auth code success.');
      return resBody.responseMap?.securityCounter;
    } catch (e) {
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return null;
    }
  }

  Future<bool> confirmAuthCode() async {
    final url = Uri.https(Config.host, 'wmt-mfs-otp/confirm-otp');
    final headers = Config.getHeaders()
      ..addAll({
        "user-agent": "okhttp/4.9.0",
        wmtMfsKey: _wmtMfs ?? '',
      });

    final response = await http.post(
      url,
      headers: headers,
      body: {
        'msisdn': _phoneNumber,
        'otp': _authCode,
      },
    );
    _wmtMfs = response.headers[wmtMfsKey] ?? _wmtMfs;

    print('Phone number: $_phoneNumber');
    print('auth code: $_authCode');
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    print('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

    final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
    if (response.statusCode != 200 || resBody.statusCode != 'Success') {
      EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}');
      return false;
    }
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
      print('confirm auth code success.');

      var token1 = await getAuthCode();
      var token2 = await getAuthCode();

      print('token1: $token1, token2: $token2');

      var helper = RsaKeyHelper();
      var publicKey = helper.parsePublicKeyFromPem(Config.rsaPublicKey);
      var password =
          base64Encode(utf8.encode(encrypt('$_pin:$token1', publicKey)));
      var pin = base64Encode(utf8.encode(encrypt('$_pin:$token2', publicKey)));

      final url = Uri.https(Config.host, 'v2/mfs-customer/login');
      final headers = Config.getHeaders()
        ..addAll({
          "user-agent": "okhttp/4.9.0",
          wmtMfsKey: _wmtMfs ?? '',
        });

      final response = await http.post(
        url,
        headers: headers,
        body: {
          'msisdn': _phoneNumber,
          'password': password,
          'pin': pin,
        },
      );
      _wmtMfs = response.headers[wmtMfsKey] ?? _wmtMfs;

      print('Phone number: $_phoneNumber');
      // print('auth code: $_authCode');
      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');
      print('$wmtMfsKey: ${response.headers[wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || resBody.statusCode != 'Success') {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return;
      }

      // print(base64);
    } catch (e) {
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
