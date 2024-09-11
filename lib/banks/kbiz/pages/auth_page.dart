import 'package:auto_report/banks/kbiz/data/account/account_data.dart';
import 'package:auto_report/banks/kbiz/network/bank_sender.dart';
import 'package:auto_report/network/backend_center_sender.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:logger/logger.dart';

class AuthPage extends StatefulWidget {
  final String? account;
  final String? password;

  const AuthPage({
    super.key,
    this.account,
    this.password,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _bankName = 'kbiz';

  String? _account;
  String? _password;

  final _sender = BankSender();
  final _backendSender = BackendCenterSender();

  bool _hasLogin = false;
  bool _hasAuth = false;

  @override
  void initState() {
    super.initState();

    _account = widget.account ?? '';
    _password = widget.password ?? '';

    logger.i('time: ${DateTime.now().toUtc().millisecondsSinceEpoch}');
  }

  bool _checkInput() {
    if (_account?.isEmpty ?? true) {
      EasyLoading.showToast('account is empty.');
      return false;
    }

    if (_password?.isEmpty ?? true) {
      EasyLoading.showToast('password is empty.');
      return false;
    }
    return true;
  }

  void _loginBank() async {
    if (!_checkInput()) return;

    final account = _account!;
    final password = _password!;

    EasyLoading.show(status: 'loading...');
    try {
      final result = await _sender.fullLogin(account, password);
      Logger().i('$_bankName full login result: $result');
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

  void _loginBackend() async {
    if (!_checkInput()) return;

    final account = _account!;

    EasyLoading.show(status: 'wait backend auth.');
    try {
      final ret = await _backendSender.authAndVerify(
          account: account, verfyWaitSeconds: 3, queryVerifyTimes: 100);
      if (!ret) return;

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
              child: TextFormField(
                controller: TextEditingController()..text = _account ?? "",
                onChanged: (value) => _account = value,
                // validator: _validator,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration("account", Icons.account_box),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              child: TextFormField(
                controller: TextEditingController()..text = _password ?? "",
                onChanged: (value) => _password = value,
                // validator: _validator,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration("password", Icons.password),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 15)),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _hasLogin ? null : _loginBank,
                  child: Text(
                      _hasLogin ? 'logined $_bankName' : 'login $_bankName'),
                ),
                const Padding(padding: EdgeInsets.only(left: 15, right: 15)),
                OutlinedButton(
                  onPressed: _hasAuth ? null : _loginBackend,
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
                          backendSender: _backendSender,
                          account: _account!,
                          password: _password!,
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
