import 'package:auto_report/data/account/account_data.dart';
import 'package:flutter/material.dart';

class AccountsPage extends StatefulWidget {
  final List<AccountData> accountsData;

  const AccountsPage({super.key, required this.accountsData});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  List<Widget> _buildList() {
    return widget.accountsData.map((data) => _item1(data)).toList();
  }

  Widget _item1(AccountData data) {
    final isUpdatingBalance = data.isUpdatingBalance;
    return ExpansionTile(
      title: Row(
        children: [
          const Icon(Icons.phone_android_sharp),
          Text(
            data.phoneNumber,
            style: const TextStyle(color: Colors.black54, fontSize: 20),
          ),
        ],
      ),
      children: [
        _buildSub(
            'balance',
            data.balance?.toString() ?? '暂未获取',
            isUpdatingBalance ? 'updating' : 'update',
            isUpdatingBalance
                ? null
                : () => data.updateBalance(() => setState(() => data = data))),
        _buildSub('balance update time', data.lastUpdateBalanceTime.toString(),
            null, null),
        _buildSub('auth code', data.authCode, null, null),
        _buildSub('pin', data.pin, null, null),
        _buildSub('wmt mfs', data.wmtMfs, null, null),
        _buildSub('deviceId', data.deviceId, null, null),
        _buildSub('model', data.model, null, null),
        _buildSub('os version', data.osVersion, null, null),
        _buildSub(
            'orders update time', data.lastUpdateTime.toString(), null, null),
      ],
    );
  }

  Widget _buildSub(
      String title, String value, String? button, VoidCallback? callback) {
    //可以设置撑满宽度的盒子 称之为百分百布局
    return Row(
      children: [
        Text(
          '$title: $value',
        ),
        const Spacer(),
        Visibility(
          visible: button != null,
          child: OutlinedButton(
            onPressed: callback,
            child: Text(button ?? ''),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: _buildList(),
    );
  }
}
