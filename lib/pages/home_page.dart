import 'dart:async';

import 'package:auto_report/data/account/account_data.dart';
import 'package:auto_report/data/account/accounts.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/pages/accounts_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // int _counter = 0;
  int _navIndex = 0;

  // List<AccountData> accountsData = [];
  final accounts = Accounts();

  late PageController _pageViewController;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    logger.i('initState');
    Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      for (final info in accounts.accountsData) {
        info.update(() =>
            setState(() => accounts.accountsData = accounts.accountsData));
      }
      // logger.i('update');
    });
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    logger.i('dispose');
  }

  void newAccount({String? phoneNumber = '', String? pin = ''}) async {
    var result = await Navigator.of(context).pushNamed("/auth", arguments: {
      'phoneNumber': phoneNumber ?? '',
      'pin': pin ?? '',
    });
    if (result == null) {
      logger.i('cancel login.');
      return;
    }
    if (result is AccountData) {
      logger.i('add accout $result');
      setState(() {
        // accounts.accountsData.removeWhere(
        //     (data) => data.phoneNumber == result.phoneNumber);
        // accounts.accountsData.add(result);
        accounts.add(result, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final plaintext =
    //     "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";
    // final ret = RSAHelper.decrypt(plaintext, Config.rsaPrivateKeyReport);
    accounts.restore();
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        centerTitle: true,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: <Widget>[
          PageView(
            controller: _pageViewController,
            onPageChanged: (index) => setState(() => _navIndex = index),
            children: <Widget>[
              AccountsPage(
                accountsData: accounts.accountsData,
                onRemoved: () => setState(() => accounts.update()),
                onReLogin: ({String? phoneNumber, String? pin}) => newAccount(
                  phoneNumber: phoneNumber,
                  pin: pin,
                ),
              ),
              Center(
                child: Text('Second Page', style: textTheme.titleLarge),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: Visibility(
        visible: _navIndex == 0,
        child: FloatingActionButton(
          onPressed: newAccount,
          tooltip: 'new account',
          child: const Icon(Icons.add),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_outlined),
            label: 'Accounts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
        currentIndex: _navIndex,
        selectedItemColor: Colors.amber[800],
        onTap: (index) {
          setState(() => _navIndex = index);
          _pageViewController.jumpToPage(_navIndex);
        },
      ),
    );
  }
}
