import 'package:auto_report/data/manager/data_manager.dart';
import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDark = false;
  double _orderRefreshTime = DataManager().orderRefreshTime;

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
                              setState(() {
                                _isDark = value;
                              });
                            })),
                    _CustomListTile(
                      title: "Order refresh seconds",
                      icon: Icons.notifications_none_rounded,
                      trailing: Text('${_orderRefreshTime.toInt()}'),
                    ),
                    Slider(
                      value: _orderRefreshTime,
                      min: 20,
                      max: 100,
                      divisions: 8,
                      label: '${_orderRefreshTime.toInt()}',
                      onChanged: (double value) {
                        setState(() {
                          _orderRefreshTime = value;
                        });
                        final dm = DataManager();
                        dm.orderRefreshTime = value;
                        dm.save();
                      },
                    ),
                    // const _CustomListTile(
                    //     title: "Security Status",
                    //     icon: CupertinoIcons.lock_shield),
                  ],
                ),
                const Divider(),
                // const _SingleSection(
                //   title: "Organization",
                //   children: [
                //     _CustomListTile(
                //         title: "Profile", icon: Icons.person_outline_rounded),
                //     _CustomListTile(
                //         title: "Messaging", icon: Icons.message_outlined),
                //     _CustomListTile(
                //         title: "Calling", icon: Icons.phone_outlined),
                //     _CustomListTile(
                //         title: "People", icon: Icons.contacts_outlined),
                //     _CustomListTile(
                //         title: "Calendar", icon: Icons.calendar_today_rounded)
                //   ],
                // ),
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
  const _CustomListTile(
      {required this.title, required this.icon, this.trailing});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      leading: Icon(icon),
      trailing: trailing,
      onTap: () {},
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
