import 'package:auto_report/data/account/account_data.dart';
import 'package:auto_report/data/log/log_item.dart';
import 'package:auto_report/data/manager/data_manager.dart';
import 'package:auto_report/data/proto/response/get_platforms_response.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

typedef ReLoginCallback = void Function(
    {String phoneNumber, String pin, String token, String remark});

class AccountsPage extends StatefulWidget {
  final List<AccountData> accountsData;
  final List<GetPlatformsResponseData?>? platforms;

  final ValueChanged<AccountData> onRemoved;
  final ReLoginCallback onReLogin;
  final ValueChanged<LogItem> onLogged;

  const AccountsPage({
    super.key,
    required this.accountsData,
    required this.platforms,
    required this.onRemoved,
    required this.onReLogin,
    required this.onLogged,
  });

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _platformsCheckboxResults = <String, bool>{};

  List<Widget> _buildList() {
    return widget.accountsData
        .where((data) => _platformsCheckboxResults[data.platformKey] ?? true)
        .map((data) => _item1(data))
        .toList();
  }

  Widget _item1(AccountData data) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final isUpdatingBalance = data.isUpdatingBalance;
    final invalid = data.isWmtMfsInvalid || data.isAuthInvidWithReport;
    final showDetail = data.showDetail;
    final state = !invalid
        ? 'normal'
        : data.isWmtMfsInvalid
            ? 'Wave invalid'
            : 'Report invalid';
    return ExpansionTile(
      title: Row(
        children: [
          Row(
            children: [
              Text(
                '${data.remark}[${data.platformName}]',
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
            const Icon(Icons.phone_android_sharp),
            Text(data.phoneNumber),
            const Spacer(),
            Text('Balance: ${data.balance?.toString() ?? 'never updated'}'),
            const Padding(padding: EdgeInsets.only(left: 10)),
            OutlinedButton(
              onPressed: (isUpdatingBalance || invalid)
                  ? null
                  : () => data.updateBalance(() => setState(() => data = data)),
              child: Text(isUpdatingBalance ? 'updating' : 'update'),
            )
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
            const Text('Disable Report:'),
            Switch(
              value: data.pauseReport,
              activeColor: Colors.red,
              onChanged: (bool value) {
                setState(() => data.pauseReport = value);
                if (value) {
                  data.reopenReport();
                }
                widget.onLogged(LogItem(
                  type: LogItemType.info,
                  platformName: data.platformName,
                  platformKey: data.platformKey,
                  phone: data.phoneNumber,
                  time: DateTime.now(),
                  content: '${!value ? 'open' : 'close'} receive money report.',
                ));
              },
            ),
          ],
        ),
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
            children: [
              _buildSub('auth code', data.authCode, null, null),
              _buildSub('pin', data.pin, null, null),
              _buildSub('wmt mfs', data.wmtMfs, null, null),
              _buildSub('deviceId', data.deviceId, null, null),
              _buildSub('model', data.model, null, null),
              _buildSub('os version', data.osVersion, null, null),
              _buildSub('platform name', data.platformName, null, null),
              _buildSub('platform url', data.platformUrl, null, null),
              _buildSub('platform key', data.platformKey, null, null),
              _buildSub('platform mark', data.platformMark, null, null),
            ],
          ),
        ),
        Visibility(
          visible: !invalid,
          child: OutlinedButton(
            onPressed: data.isUpdatingOrders || invalid
                ? null
                : () =>
                    data.updateOrder(() => setState(() => data = data), (log) {
                      // todo.
                    }),
            child: Text(
                data.isUpdatingOrders ? 'Updating orders' : 'Update orders'),
          ),
        ),
        Visibility(
          visible: invalid,
          child: OutlinedButton(
            onPressed: () => widget.onReLogin(
              phoneNumber: data.phoneNumber,
              pin: data.pin,
              token: data.token,
              remark: data.remark,
            ),
            child: const Text('ReLogin'),
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
          Text(
            overflow: TextOverflow.fade,
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
      ),
    );
  }

  Widget _buildCheckbox(GetPlatformsResponseData? data) {
    final key = data!.key!;
    final value = _platformsCheckboxResults[key] ?? true;
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Text(data.name!),
          Checkbox(
              value: value,
              onChanged: (value) =>
                  setState(() => _platformsCheckboxResults[key] = value!)),
        ],
      ),
    );
  }

  bool _isAllPlatformsSelected() {
    return !widget.platforms!.any((platform) =>
        (_platformsCheckboxResults[platform!.key] ?? true) == false);
  }

  Widget _buildFilter() {
    final widgets = widget.platforms
            ?.map((platform) => _buildCheckbox(platform))
            .toList() ??
        [];
    widgets.insert(
        0,
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
          child: Row(
            children: [
              const Text('ALL'),
              Checkbox(
                  value: _isAllPlatformsSelected(),
                  onChanged: (value) => setState(() {
                        for (var platform in widget.platforms!) {
                          _platformsCheckboxResults[platform!.key!] = value!;
                        }
                      })),
            ],
          ),
        ));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: widgets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // return ListView(children: _buildList());
    return Column(
      children: [
        _buildFilter(),
        Flexible(child: ListView(children: _buildList())),
      ],
    );
  }
}
