import 'package:auto_report/manager/data_manager.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onThemeInvalid});

  final VoidCallback onThemeInvalid;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _orderRefreshTime = DataManager().orderRefreshTime;
  double _sendMoneyRefreshTime = DataManager().gettingCashListRefreshTime;
  double _rechargeTransferRefreshTime =
      DataManager().rechargeTransferRefreshTime;
  bool _devMode = DataManager().devMode;
  bool _devModeSwich = DataManager().devMode;
  bool _isDark = DataManager().isDark;
  bool _openRechargeTransfer = DataManager().openRechargeTransfer;
  bool _autoUpdateBalance = DataManager().autoUpdateBalance;

  int _clickTime = 0;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _isDark ? ThemeData.dark() : ThemeData.light(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings"),
        ),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: ListView(
              children: [
                _SingleSection(
                  title: "General",
                  children: [
                    _CustomListTile(
                      title: "Dark Mode",
                      icon: Icons.dark_mode_outlined,
                      trailing: Switch(
                        value: _isDark,
                        onChanged: (value) {
                          final dm = DataManager();
                          dm.isDark = value;
                          dm.save();
                          setState(() {
                            _isDark = value;
                          });
                          widget.onThemeInvalid();
                        },
                      ),
                    ),
                    _CustomListTile(
                      title: "Auto Update Balance",
                      icon: Icons.autorenew,
                      trailing: Switch(
                        value: _autoUpdateBalance,
                        onChanged: (value) {
                          final dm = DataManager();
                          dm.autoUpdateBalance = value;
                          dm.save();
                          setState(() {
                            _autoUpdateBalance = value;
                          });
                        },
                      ),
                    ),
                    _CustomListTile(
                      title: "Open Recharge Transfer",
                      icon: Icons.send,
                      trailing: Switch(
                        value: _openRechargeTransfer,
                        onChanged: (value) {
                          final dm = DataManager();
                          dm.openRechargeTransfer = value;
                          dm.save();
                          setState(() {
                            _openRechargeTransfer = value;
                          });
                        },
                      ),
                    ),
                    _CustomListTile(
                      title: "Receive money refresh seconds",
                      icon: Icons.refresh,
                      trailing: Text(
                        '${_orderRefreshTime.toInt()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: _orderRefreshTime,
                      min: 50,
                      max: 120,
                      divisions: 7,
                      label: '${_orderRefreshTime.toInt()}',
                      onChanged: (double value) {
                        setState(() => _orderRefreshTime = value);
                        final dm = DataManager();
                        dm.orderRefreshTime = value;
                        dm.save();
                      },
                    ),
                    _CustomListTile(
                      title: "Send money refresh seconds",
                      icon: Icons.refresh,
                      trailing: Text(
                        '${_sendMoneyRefreshTime.toInt()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: _sendMoneyRefreshTime,
                      min: 1,
                      max: 20,
                      divisions: 19,
                      label: '${_sendMoneyRefreshTime.toInt()}',
                      onChanged: (double value) {
                        setState(() {
                          _sendMoneyRefreshTime = value;
                        });
                        final dm = DataManager();
                        dm.gettingCashListRefreshTime = value;
                        dm.save();
                      },
                    ),
                    _CustomListTile(
                      title: "Recharge transfer refresh seconds",
                      icon: Icons.refresh,
                      trailing: Text(
                        '${_rechargeTransferRefreshTime.toInt()}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Slider(
                      value: _rechargeTransferRefreshTime,
                      min: 5,
                      max: 65,
                      divisions: 12,
                      label: '${_rechargeTransferRefreshTime.toInt()}',
                      onChanged: (double value) {
                        setState(() {
                          _rechargeTransferRefreshTime = value;
                        });
                        final dm = DataManager();
                        dm.rechargeTransferRefreshTime = value;
                        dm.save();
                      },
                    ),
                    _CustomListTile(
                      title: 'Version',
                      icon: Icons.code,
                      trailing: Text(
                        DataManager().appVersion ?? '',
                        style: const TextStyle(fontSize: 14),
                      ),
                      callback: () {
                        if (++_clickTime > 5) {
                          setState(() => _devModeSwich = true);
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),
                Visibility(
                  visible: _devModeSwich,
                  child: _SingleSection(
                    title: "Developer Tools",
                    children: [
                      _CustomListTile(
                        title: "Dev Mode",
                        icon: Icons.developer_mode,
                        trailing: Switch(
                          value: _devMode,
                          onChanged: (value) {
                            setState(() {
                              _devMode = value;
                              DataManager().devMode = value;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // const Divider(),
                // const _SingleSection(
                //   children: [
                //     _CustomListTile(
                //         title: "Help & Feedback",
                //         icon: Icons.help_outline_rounded),
                //     _CustomListTile(
                //         title: "About", icon: Icons.info_outline_rounded),
                //     _CustomListTile(
                //         title: "Sign out", icon: Icons.exit_to_app_rounded),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomListTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? callback;

  const _CustomListTile({
    required this.title,
    required this.icon,
    this.trailing,
    this.callback,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: trailing,
      onTap: () => callback?.call(),
    );
  }
}

class _SingleSection extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _SingleSection({
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              title!,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        Column(
          children: children,
        ),
      ],
    );
  }
}
