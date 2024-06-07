import 'package:auto_report/data/account/account_data.dart';
import 'package:flutter/material.dart';

const cityNames = <String, List<String>>{
  '北京': ['东城区', '西城区', '海淀区', '朝阳区', '石景山区', '顺义区'],
  '上海': ['黄浦区', '徐汇区', '长宁区', '静安区', '普陀区', '闸北区'],
  '广州': ['越秀', '海珠', '荔湾', '天河', '白云', '黄埔', '南沙'],
  '深圳': ['南山', '福田', '罗湖', '盐田', '龙岗', '宝安', '龙华'],
  '杭州': ['上城区', '下城区', '江干区', '拱墅区', '西湖区', '滨江区'],
  '苏州': ['姑苏区', '吴中区', '相城区', '高新区', '虎丘区', '工业园区', '吴江区'],
};

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
        _buildSub('auth code', data.authCode),
        _buildSub('pin', data.pin),
        _buildSub('wmt mfs', data.wmtMfs),
        _buildSub('last update time', data.lastUpdateTime.toString()),
      ],
    );
  }

  Widget _buildSub(String title, String value) {
    //可以设置撑满宽度的盒子 称之为百分百布局
    return FractionallySizedBox(
      //宽度因子 1为百分百撑满
      widthFactor: 1,
      // child: Container(
      //   height: 50,
      //   margin: const EdgeInsets.only(bottom: 5),
      //   decoration: const BoxDecoration(color: Colors.lightBlueAccent),
      //   child: Text(value),
      // ),
      child: Text('$title: $value'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: _buildList(),
    );
  }
}
