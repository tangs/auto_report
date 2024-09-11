import 'dart:convert';

import 'package:auto_report/banks/kbiz/data/account/account_data.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:localstorage/localstorage.dart';

class Accounts {
  List<AccountData> accountsData = [];

  String _lastRestoreStr = '';

  Accounts() {
    restore();
  }

  void add(AccountData account, bool removeDuplicated) {
    if (removeDuplicated) {
      removeByPhoneNumber(account.account, true);
    }
    accountsData.add(account);
    save();
  }

  void removeByPhoneNumber(String account, bool skipRestore) {
    accountsData.removeWhere((accountData) => accountData.account == account);
    if (skipRestore) return;
    save();
  }

  AccountData getAccountByPhoneNumber(String account) {
    return accountsData
        .firstWhere((accountData) => accountData.account == account);
  }

  void update() {
    accountsData.removeWhere((acc) => acc.needRemove);
  }

  void save() {
    var data = accountsData.map((acc) => acc.restore()).toList();
    var str = jsonEncode(data);
    if (str == _lastRestoreStr) return;
    if (accountsData.isNotEmpty && str.isEmpty) return;

    logger.i('restore accounts data.');
    // logger.i('restore: $str');
    localStorage.setItem('kbiz_accounts', str);
    _lastRestoreStr = str;
  }

  void restore() {
    var str = localStorage.getItem('kbiz_accounts');
    if (str == null) return;

    try {
      var data = jsonDecode(str) as List<dynamic>;
      accountsData = data.map((acc) => AccountData.fromJson(acc)).toList();
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    }
  }
}
