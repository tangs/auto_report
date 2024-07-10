import 'dart:convert';

import 'package:auto_report/banks/kbz/data/account/account_data.dart';
import 'package:auto_report/main.dart';
import 'package:localstorage/localstorage.dart';

class Accounts {
  List<AccountData> accountsData = [];

  String _lastRestoreStr = '';

  Accounts() {
    restore();
  }

  void add(AccountData account, bool removeDuplicated) {
    if (removeDuplicated) {
      removeByPhoneNumber(account.phoneNumber, true);
    }
    accountsData.add(account);
    save();
  }

  void removeByPhoneNumber(String phoneNumber, bool skipRestore) {
    accountsData.removeWhere((account) => account.phoneNumber == phoneNumber);
    if (skipRestore) return;
    save();
  }

  AccountData getAccountByPhoneNumber(String phoneNumber) {
    return accountsData
        .firstWhere((account) => account.phoneNumber == phoneNumber);
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
    localStorage.setItem('accounts', str);
    _lastRestoreStr = str;
  }

  void restore() {
    var str = localStorage.getItem('accounts');
    if (str == null) return;

    try {
      var data = jsonDecode(str) as List<dynamic>;
      accountsData = data.map((acc) => AccountData.fromJson(acc)).toList();
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    }
  }
}
