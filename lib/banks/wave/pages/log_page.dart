import 'dart:collection';

import 'package:auto_report/banks/wave/data/account/account_data.dart';
import 'package:auto_report/banks/wave/data/log/log_item.dart';
import 'package:auto_report/banks/wave/data/manager/data_manager.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LogsPage extends StatefulWidget {
  final LinkedList<LogItem> logs;
  final List<GetPlatformsResponseData?>? platforms;
  final List<AccountData> accountsData;

  const LogsPage({
    super.key,
    required this.logs,
    required this.platforms,
    required this.accountsData,
  });

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  final _platformsCheckboxResults = <String, bool>{};
  final _accountsCheckboxResults = <String, bool>{};
  final _typeFilterResults = <LogItemType, bool>{};

  bool _autoRefresh = DataManager().autoRefreshLog;

  bool isPlatformSelected(String platformKey) {
    return _platformsCheckboxResults[platformKey] ?? true;
  }

  bool _isAllPlatformsSelected() {
    return !widget.platforms!
        .any((platform) => !isPlatformSelected(platform!.key!));
  }

  bool isAccountSelected(String phoneNumber) {
    return _accountsCheckboxResults[phoneNumber] ?? true;
  }

  bool _isAllAccountsSelected() {
    return !widget.accountsData
        .any((account) => !isAccountSelected(account.phoneNumber));
  }

  bool isTypeSelected(LogItemType type) {
    return _typeFilterResults[type] ?? true;
  }

  bool _isAllTypesSelected() {
    return !LogItemType.values.any((type) => !isTypeSelected(type));
  }

  Widget _buildCheckbox(
      String title, bool value, ValueChanged<bool?> callback) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: Row(
        children: [
          Text(title),
          Checkbox(
            value: value,
            onChanged: callback,
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformCheckbox(GetPlatformsResponseData? data) {
    final key = data!.key!;
    final value = isPlatformSelected(key);
    return _buildCheckbox(
      data.name!,
      value,
      (value) => setState(() => _platformsCheckboxResults[key] = value!),
    );
  }

  Widget _buildAccountCheckbox(AccountData data) {
    final key = data.phoneNumber;
    final value = isAccountSelected(key);
    return _buildCheckbox(
      key,
      value,
      (value) => setState(() => _accountsCheckboxResults[key] = value!),
    );
  }

  Widget _buildTypeCheckbox(LogItemType type) {
    final key = type;
    final value = isTypeSelected(key);
    return _buildCheckbox(
      key.toString().replaceFirst('LogItemType.', ''),
      value,
      (value) => setState(() => _typeFilterResults[key] = value!),
    );
  }

  Widget _buildAllCheckbox(bool value, ValueChanged<bool?> callback) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 0, 10),
      child: Row(
        children: [
          const Text('ALL'),
          Checkbox(value: value, onChanged: callback),
        ],
      ),
    );
  }

  Widget _buildPlatformFilter() {
    final widgets = widget.platforms
            ?.map((platform) => _buildPlatformCheckbox(platform))
            .toList() ??
        [];
    widgets.insert(
      0,
      _buildAllCheckbox(
        _isAllPlatformsSelected(),
        (value) => setState(() {
          for (var platform in widget.platforms!) {
            _platformsCheckboxResults[platform!.key!] = value!;
          }
        }),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }

  Widget _buildAccountsFilter() {
    final widgets = widget.accountsData
        .where((account) => isPlatformSelected(account.platformKey))
        .map((account) => _buildAccountCheckbox(account))
        .toList();
    widgets.insert(
      0,
      _buildAllCheckbox(
        _isAllAccountsSelected(),
        (value) => setState(() {
          for (var account in widget.accountsData) {
            _accountsCheckboxResults[account.phoneNumber] = value!;
          }
        }),
      ),
    );

    return Visibility(
      visible: widget.accountsData.isNotEmpty,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: widgets),
      ),
    );
  }

  Widget _buildTypesFilter() {
    final widgets =
        LogItemType.values.map((type) => _buildTypeCheckbox(type)).toList();
    widgets.insert(
      0,
      _buildAllCheckbox(
        _isAllTypesSelected(),
        (value) => setState(() {
          for (var type in LogItemType.values) {
            _typeFilterResults[type] = value!;
          }
        }),
      ),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: widgets),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          Row(children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() {}),
            ),
            IconButton(
              onPressed: () async {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Icon(Icons.delete_forever),
                      content: const Text('delete all logs?'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() => widget.logs.clear());
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
              icon: const Icon(Icons.delete_forever),
            ),
            // const Icon(Icons.refresh),
            const Text('auto refresh'),
            Switch(
              value: _autoRefresh,
              onChanged: (value) {
                setState(() => _autoRefresh = value);
                DataManager().autoRefreshLog = value;
              },
            )
          ])
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(child: _buildPlatformFilter()),
          SizedBox(child: _buildAccountsFilter()),
          SizedBox(child: _buildTypesFilter()),
          Flexible(
            child: ListView(
              children: ListTile.divideTiles(
                context: context,
                tiles: widget.logs
                    .where((log) =>
                        isPlatformSelected(log.platformKey) &&
                        isAccountSelected(log.phone) &&
                        isTypeSelected(log.type))
                    .map((log) => _LogCell(log: log))
                    .toList()
                    .reversed,
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCell extends StatelessWidget {
  final LogItem log;

  const _LogCell({required this.log});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return Column(children: [
      ListTile(
        title: Text('${log.phone}[${log.platformName}]'),
        leading: const Icon(Icons.phone),
      ),
      ListBody(
        children: [
          Text('type: ${log.getType()}'),
          Text('time: ${dateFormat.format(log.time)}'),
          Text('content: ${log.content}'),
        ],
      )
    ]);
  }
}
