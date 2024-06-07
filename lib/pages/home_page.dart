import 'dart:async';

import 'package:auto_report/data/account/account_data.dart';
import 'package:auto_report/pages/accounts_page.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // int _counter = 0;
  int _navIndex = 0;

  List<AccountData> accountsData = [];

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
      for (final info in accountsData) {
        info.updateOrder();
      }
      logger.i('update');
    });
  }

  @override
  void dispose() {
    super.dispose();
    _pageViewController.dispose();
    logger.i('dispose');
  }

  @override
  Widget build(BuildContext context) {
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
                accountsData: accountsData,
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
          onPressed: () async {
            var result = await Navigator.of(context).pushNamed("/auth");
            if (result == null) {
              logger.i('cancel login.');
              return;
            }
            if (result is AccountData) {
              logger.i('add accout $result');
              setState(() {
                accountsData.removeWhere(
                    (data) => data.phoneNumber == result.phoneNumber);
                accountsData.add(result);
              });
            }
          },
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
