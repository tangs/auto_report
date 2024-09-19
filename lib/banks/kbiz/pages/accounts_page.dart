import 'package:auto_report/banks/kbiz/data/account/account_data.dart';
import 'package:auto_report/manager/data_manager.dart';
import 'package:auto_report/model/data/log/log_item.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef ReLoginCallback = void Function({String account, String password});

class AccountsPage extends StatefulWidget {
  final List<AccountData> accountsData;

  final ValueChanged<AccountData> onRemoved;
  final ReLoginCallback onReLogin;
  final ValueChanged<LogItem> onLogged;

  const AccountsPage({
    super.key,
    required this.accountsData,
    required this.onRemoved,
    required this.onReLogin,
    required this.onLogged,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  // final _platformsCheckboxResults = <String, bool>{};

  List<Widget> _buildAccountsList() {
    return widget.accountsData
        // .where((data) => _platformsCheckboxResults[data.platformKey] ?? true)
        .map((data) => _buildAccountItem(data))
        .toList();
  }

  List<Widget> _buildDetails(AccountData data) {
    return [
      _buildSub('password', data.password, null, null),
    ];
  }

  Widget _buildAccountItem(AccountData data) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isUpdatingBalance = data.isUpdatingBalance;
    final invalid = data.invalid();
    final showDetail = data.showDetail;
    final state = data.state();
    return ExpansionTile(
      title: Row(
        children: [
          Row(
            children: [
              Text(
                data.account,
                style: const TextStyle(fontSize: 16),
              ),
              const Padding(padding: EdgeInsets.only(left: 10)),
              Text(
                style: TextStyle(color: invalid ? Colors.red : Colors.blue),
                state,
              )
            ],
          )
        ],
      ),
      children: [
        Row(
          children: [
            const Icon(Icons.account_box),
            Text(data.account),
            const Spacer(),
            Text('Balance: ${data.balance?.toString() ?? 'never updated'}'),
            const Padding(padding: EdgeInsets.only(left: 10)),
            OutlinedButton(
              onPressed: (isUpdatingBalance || invalid)
                  ? null
                  : () => data.updateBalance(),
              child: Text(isUpdatingBalance ? 'updating' : 'update'),
            ),
          ],
        ),
        Row(
          children: [
            RichText(
              text: TextSpan(
                text: 'Report',
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '    succ: ${data.reportSuccessCnt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  TextSpan(
                    text: '    fail: ${data.reportFailCnt}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            const Text('Receive money:'),
            Switch(
              value: !data.disableReport,
              activeColor: Colors.red,
              onChanged: (bool value) {
                setState(() => data.disableReport = !value);
                if (!value) {
                  data.reopenReport();
                }
                widget.onLogged(LogItem(
                  type: LogItemType.info,
                  platformName: '',
                  platformKey: '',
                  phone: data.account,
                  time: DateTime.now(),
                  content: '${value ? 'open' : 'close'} receive money.',
                ));
              },
            ),
          ],
        ),
        // Row(
        //   children: [
        //     RichText(
        //       text: TextSpan(
        //         text: 'Cash',
        //         style: DefaultTextStyle.of(context).style,
        //         children: [
        //           TextSpan(
        //             text: '    succ: ${data.cashSuccessCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.blue,
        //             ),
        //           ),
        //           TextSpan(
        //             text: '    fail: ${data.cashFailCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.red,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //     const Spacer(),
        //     const Text('Send money:'),
        //     Switch(
        //       value: !data.disableCash,
        //       activeColor: Colors.red,
        //       onChanged: (bool value) {
        //         setState(() => data.disableCash = !value);
        //         widget.onLogged(LogItem(
        //           type: LogItemType.info,
        //           platformName: '',
        //           platformKey: '',
        //           phone: data.account,
        //           time: DateTime.now(),
        //           content: '${value ? 'open' : 'close'} send money.',
        //         ));
        //       },
        //     ),
        //   ],
        // ),
        // Row(
        //   children: [
        //     RichText(
        //       text: TextSpan(
        //         text: 'Transfer',
        //         style: DefaultTextStyle.of(context).style,
        //         children: [
        //           TextSpan(
        //             text: '    succ: ${data.transferSuccessCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.blue,
        //             ),
        //           ),
        //           TextSpan(
        //             text: '    fail: ${data.transferFailCnt}',
        //             style: const TextStyle(
        //               fontWeight: FontWeight.bold,
        //               color: Colors.red,
        //             ),
        //           ),
        //         ],
        //       ),
        //     ),
        //     const Spacer(),
        //     const Text('Recharge transfer:'),
        //     Switch(
        //       value: !data.disableRechargeTransfer,
        //       activeColor: Colors.red,
        //       onChanged: (bool value) {
        //         setState(() => data.disableRechargeTransfer = !value);
        //         widget.onLogged(LogItem(
        //           type: LogItemType.info,
        //           platformName: '',
        //           platformKey: '',
        //           phone: data.account,
        //           time: DateTime.now(),
        //           content: '${value ? 'open' : 'close'} recharge transfer.',
        //         ));
        //       },
        //     ),
        //   ],
        // ),
        Visibility(
          visible: DataManager().devMode,
          child: Row(
            children: [
              const Text('Show detail:'),
              const Spacer(),
              Switch(
                value: data.showDetail,
                activeColor: Colors.red,
                onChanged: (bool value) =>
                    setState(() => data.showDetail = value),
              ),
            ],
          ),
        ),
        // _buildSub(
        //     'Balance',
        //     data.balance?.toString() ?? 'never updated',
        //     isUpdatingBalance ? 'updating' : 'update',
        //     isUpdatingBalance || invalid
        //         ? null
        //         : () => data.updateBalance(() => setState(() => data = data))),
        _buildSub(
            'Balance update time',
            data.lastUpdateBalanceTime.millisecondsSinceEpoch == 0
                ? 'never updated'
                : dateFormat.format(data.lastUpdateBalanceTime),
            null,
            null),
        _buildSub(
            'Orders update time',
            data.lastUpdateTime.microsecondsSinceEpoch == 0
                ? 'never updated'
                : dateFormat.format(data.lastUpdateTime),
            null,
            null),
        Visibility(
          visible: showDetail,
          child: Column(
            children: _buildDetails(data),
          ),
        ),
        Row(
          children: [
            Text('state: ${data.isUpdating ? 'Updating' : 'Waiting'}')
          ],
        ),
        Visibility(
          visible: invalid,
          child: OutlinedButton(
            onPressed: () => widget.onReLogin(
              account: data.account,
              password: data.password,
            ),
            child: const Text('ReLogin'),
          ),
        ),
        Visibility(
          visible: invalid,
          child: OutlinedButton(
            onPressed: () {
              data.authBackendSender();
            },
            child: const Text('Auth report server'),
          ),
        ),
        Column(
          children: [
            Center(
              child: IconButton(
                color: Colors.red,
                icon: const Icon(Icons.delete_forever),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Icon(Icons.delete_forever),
                        content: const Text('delete this account?'),
                        actions: [
                          TextButton(
                            onPressed: () {
                              setState(() => data.needRemove = true);
                              widget.onRemoved(data);
                              Navigator.of(context).pop();
                            },
                            child: const Text('OK'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSub(
      String title, String value, String? button, VoidCallback? callback) {
    //可以设置撑满宽度的盒子 称之为百分百布局
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: [
          Text(overflow: TextOverflow.fade, '$title: $value'),
          const Spacer(),
          Visibility(
            visible: button != null,
            child: OutlinedButton(
              onPressed: callback,
              child: Text(button ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(child: ListView(children: _buildAccountsList())),
      ],
    );
  }
}
