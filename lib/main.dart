import 'package:auto_report/data/proto/response/get_platforms_response.dart';
import 'package:auto_report/pages/auth_page.dart';
import 'package:auto_report/pages/home_page.dart';
import 'package:auto_report/pages/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:localstorage/localstorage.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

var logger = Logger(
  printer: PrettyPrinter(),
);

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
      title: 'Wave auto report',
      routes: {
        '/auth': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>;
          return AuthPage(
            platforms: data['platforms'],
            phoneNumber: data['phoneNumber'],
            pin: data['pin'],
            token: data['token'],
            remark: data['remark'],
          );
        },
        '/home': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as List<GetPlatformsResponseData?>?;
          return HomePage(
            title: 'Wave auto report',
            platforms: data,
          );
        },
      },
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // home: const HomePage(title: 'Wave auto reporter'),
      home: const LoginPage(title: 'Wave auto reporter'),
      builder: EasyLoading.init(),
    );
  }
}
