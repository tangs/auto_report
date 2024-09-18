import 'dart:async';
import 'dart:collection';

import 'package:auto_report/banks/kbiz/data/account/account_data.dart';
import 'package:auto_report/banks/kbiz/data/account/accounts.dart';
import 'package:auto_report/banks/kbiz/pages/accounts_page.dart';
import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:auto_report/model/pages/log_page.dart';
import 'package:auto_report/pages/file_page.dart';
import 'package:auto_report/pages/setting_page.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

typedef OnLogCallback = void Function(LogItem item);

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.title,
  });

  final String title;

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

    // Sender.test();

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

  // todo
  void newAccount({
    String? account,
    String? password,
  }) async {
    if (kDebugMode) {
      account ??= 'Suminta41';
      password ??= 'May88990#';
    }
    // BackendCenterSender.test();
    // BankSender.test();
    final result =
        await Navigator.of(context).pushNamed("/kbiz/auth", arguments: {
      'account': account ?? '',
      'password': password ?? '',
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
          platformName: '',
          platformKey: '',
          phone: result.account,
          time: DateTime.now(),
          content: 'add account.',
        ),
      );
    }
  }

  void addLog(LogItem item) {
    if (!mounted) return;

    if (_logs.length > GlobalConfig.logCountMax) {
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
    // accounts.save();
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
                  onRemoved: (account) {
                    setState(() => accounts.update());
                    addLog(
                      LogItem(
                        type: LogItemType.deleteAccount,
                        platformName: '',
                        platformKey: '',
                        phone: account.account,
                        time: DateTime.now(),
                        content: 'delete account.',
                      ),
                    );
                  },
                  onReLogin: ({
                    String? account,
                    String? password,
                  }) =>
                      newAccount(account: account, password: password),
                  onLogged: addLog,
                ),
                LogsPage(
                  logs: _logs,
                  platforms: const [],
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
