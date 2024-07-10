import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/banks/wave/pages/auth_page.dart' as wave_auth;
import 'package:auto_report/banks/wave/pages/home_page.dart' as wave_home;
import 'package:auto_report/banks/kbz/pages/auth_page.dart' as kbz_auth;
import 'package:auto_report/banks/kbz/pages/home_page.dart' as kbz_home;
import 'package:auto_report/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:localstorage/localstorage.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

final logger = Logger(
  printer: PrettyPrinter(),
);

const _title = 'Auto report';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalStorage();
  WakelockPlus.enable();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: _title,
      routes: {
        '/wave/auth': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>;
          return wave_auth.AuthPage(
            platforms: data['platforms'],
            phoneNumber: data['phoneNumber'],
            pin: data['pin'],
            token: data['token'],
            remark: data['remark'],
          );
        },
        '/wave/home': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as List<GetPlatformsResponseData?>?;
          return wave_home.HomePage(title: _title, platforms: data);
        },
        '/kbz/auth': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>;
          return kbz_auth.AuthPage(
            platforms: data['platforms'],
            phoneNumber: data['phoneNumber'],
            pin: data['pin'],
            token: data['token'],
            remark: data['remark'],
          );
        },
        '/kbz/home': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as List<GetPlatformsResponseData?>?;
          return kbz_home.HomePage(title: _title, platforms: data);
        },
      },
      // theme: ThemeData.light(),
      home: const LoginPage(title: _title),
      builder: EasyLoading.init(),
    );
  }
}
