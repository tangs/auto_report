import 'dart:async';
import 'dart:collection';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/data/account/account_data.dart';
import 'package:auto_report/banks/kbz/data/account/accounts.dart';
import 'package:auto_report/banks/kbz/data/log/log_item.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/pages/file_page.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/main.dart';
import 'package:auto_report/banks/kbz/pages/accounts_page.dart';
import 'package:auto_report/banks/kbz/pages/log_page.dart';
import 'package:auto_report/pages/setting_page.dart';
import 'package:flutter/material.dart';

typedef OnLogCallback = void Function(LogItem item);

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
  final _logs = LinkedList<LogItem>();

  late PageController _pageViewController;

  var _isDark = DataManager().isDark;

  @override
  void initState() {
    super.initState();
    _pageViewController = PageController();
    logger.i('initState');
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      for (final info in accounts.accountsData) {
        info.update(() {
          if (!mounted) return;
          setState(() => accounts.accountsData = accounts.accountsData);
        }, addLog);
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

  void newAccount({
    String? phoneNumber = '',
    String? pin = '',
    String? id = '',
    String? token,
    String? remark,
  }) async {
    final result =
        await Navigator.of(context).pushNamed("/kbz/auth", arguments: {
      'phoneNumber': phoneNumber ?? '',
      'pin': pin ?? '',
      'id': id ?? '',
      'token': token ?? '',
      'remark': remark ?? '',
      'platforms': widget.platforms,
    });
    if (result == null) {
      logger.i('cancel login.');
      return;
    }
    if (result is AccountData) {
      logger.i('add accout $result');
      setState(() => accounts.add(result, true));
      addLog(
        LogItem(
          type: LogItemType.newAccount,
          platformName: result.platformName,
          platformKey: result.platformKey,
          phone: result.phoneNumber,
          time: DateTime.now(),
          content: 'add account.',
        ),
      );
    }
  }

  void addLog(LogItem item) {
    if (!mounted) return;

    if (_logs.length > Config.logCountMax) {
      _logs.remove(_logs.first);
    }
    if (DataManager().autoRefreshLog) {
      setState(() => _logs.add(item));
    } else {
      _logs.add(item);
    }
    logger.i(item.toString());
  }

  @override
  Widget build(BuildContext context) {
    accounts.save();
    // final TextTheme textTheme = Theme.of(context).textTheme;
    return Theme(
      data: _isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          title: Text(widget.title),
          centerTitle: true,
        ),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            PageView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _pageViewController,
              onPageChanged: (index) => setState(() => _navIndex = index),
              children: <Widget>[
                AccountsPage(
                  accountsData: accounts.accountsData,
                  platforms: widget.platforms,
                  onRemoved: (account) {
                    setState(() => accounts.update());
                    addLog(
                      LogItem(
                        type: LogItemType.deleteAccount,
                        platformName: account.platformName,
                        platformKey: account.platformKey,
                        phone: account.phoneNumber,
                        time: DateTime.now(),
                        content: 'delete account.',
                      ),
                    );
                  },
                  onReLogin: ({
                    String? phoneNumber,
                    String? pin,
                    String? id,
                    String? token,
                    String? remark,
                  }) =>
                      newAccount(
                    phoneNumber: phoneNumber,
                    pin: pin,
                    id: id,
                    token: token,
                    remark: remark,
                  ),
                  onLogged: addLog,
                ),
                LogsPage(
                  logs: _logs,
                  platforms: widget.platforms,
                  accountsData: accounts.accountsData,
                ),
                const FilesPage(),
                SettingsPage(
                  onThemeInvalid: () => setState(
                    () => _isDark = DataManager().isDark,
                  ),
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
              icon: Icon(Icons.document_scanner),
              label: 'Logs',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.file_open),
              label: 'Files',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Setting',
            ),
          ],
          currentIndex: _navIndex,
          selectedItemColor: Colors.amber[800],
          unselectedItemColor: Colors.blue,
          onTap: (index) {
            setState(() => _navIndex = index);
            _pageViewController.jumpToPage(_navIndex);
          },
        ),
      ),
    );
  }
}
