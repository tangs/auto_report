import 'dart:async';

import 'package:auto_report/data/account/account_data.dart';
import 'package:auto_report/data/account/accounts.dart';
import 'package:auto_report/data/proto/response/get_platforms_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/pages/accounts_page.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
    required this.platforms,
  });

  final String title;
  final List<GetPlatformsResponseData?>? platforms;

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
        info.update(() {
          if (!mounted) return;
          setState(() => accounts.accountsData = accounts.accountsData);
        });
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
      'platforms': widget.platforms,
    });
    if (result == null) {
      logger.i('cancel login.');
      return;
    }
    if (result is AccountData) {
      logger.i('add accout $result');
      setState(() {
        accounts.add(result, true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                platforms: widget.platforms,
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
