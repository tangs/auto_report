import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String? _phoneNumber;
  String? _passoword;

  void auth() async {
    // EasyLoading.show(status: 'loading...');

    var url = Uri.https('api.wavemoney.io:8100', 'wmt-mfs-otp/generate-otp',
        {'msisdn': '$_phoneNumber'});
    var response = await http.get(url, headers: {
      "fingerprint":
          "87EC104C0FFBB8E749CD59D9C64851441B38D1C13C9746DC124BB9E71E66DCB9",
      "appid": "mm.com.wavemoney.wavepay",
      "userlanguage": "en",
      "accept-encoding": "gzip, deflate, br",
      "versioncode": "1460",
      "appversion": "2.2.0",
      "user-agent": "okhttp/4.9.0",
      // 以下是模拟Pixel 5的设备
      "deviceid":
          "fd701ebcc3dcc6342ab647f5b9800f76ba3a7b5a", // 随机生成40位的uuid,用于确定是否当前登录设备
      "device": "redfin", // 设备驱动名称
      "product": "redfin", // 产品的名称
      "cpuabi": "arm64-v8a,armeabi-v7a,armeabi", // 设备指令集名称（CPU的类型）
      "manufacturer": "Google", // 设备制造商
      "model": "Pixel 5", // 手机的型号 设备名称
      "osversion": "11", // OS系统版本
    });
    print('Response status: ${response.statusCode}');
    print('Response body: ${response.body}');
    if (response.statusCode == 200) {}
  }

  InputDecoration buildInputDecoration(String hit, IconData icon) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      prefixIcon: Icon(
        icon,
        color: Colors.blue,
      ),
      labelText: hit,
      hintText: "Input $hit",
      // suffix: Text(
      //   unit,
      //   style: TextStyle(color: Colors.grey.shade200),
      // ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('auth'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
            child: TextFormField(
              controller: TextEditingController()..text = _phoneNumber ?? "",
              onChanged: (value) => _phoneNumber = value,
              // validator: _validator,
              keyboardType: TextInputType.number,
              decoration: buildInputDecoration("phone number", Icons.phone),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            child: TextFormField(
              controller: TextEditingController()..text = _passoword ?? "",
              onChanged: (value) => _passoword = value,
              // validator: _validator,
              keyboardType: TextInputType.number,
              decoration: buildInputDecoration("password", Icons.phone),
            ),
          ),
          OutlinedButton(
              onPressed: auth, child: const Text('request auth code.'))
        ],
      ),
    );
  }
}
