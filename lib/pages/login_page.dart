import 'dart:convert';

import 'package:auto_report/config/config.dart';
import 'package:auto_report/data/proto/response/get_platforms_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
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

  void login() async {
    if (_platform?.isEmpty ?? true) {
      EasyLoading.showToast('platform must not empty.');
    }

    setState(() => _logging = true);

    try {
      final url = Uri.http('www.diyibuyu.com', 'api/getPlatformUrl');
      // final response = await http.post(url, body: {
      //   'platform': '$_platform',
      // });

      final response = await Future.any([
        http.post(url, body: {
          'platform': '$_platform',
        }),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('timeout');
        logger.i('timeout');
        return;
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
        return;
      }

      for (var cell in resData.data!) {
        logger.i('cell: ${cell!.key}, ${cell.name}, ${cell.url}, ${cell.mark}');
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        "/home",
        arguments: resData.data,
      );
    } catch (e) {
      logger.e('e: $e', stackTrace: StackTrace.current);
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
              keyboardType: TextInputType.number,
              decoration: _buildInputDecoration("platform", Icons.login_sharp),
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
