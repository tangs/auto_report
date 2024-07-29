import 'dart:io';

import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/banks/wave/pages/auth_page.dart' as wave_auth;
import 'package:auto_report/banks/wave/pages/home_page.dart' as wave_home;
import 'package:auto_report/banks/kbz/pages/auth_page.dart' as kbz_auth;
import 'package:auto_report/banks/kbz/pages/home_page.dart' as kbz_home;
import 'package:auto_report/pages/login_page.dart';
import 'package:auto_report/widges/bank_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:localstorage/localstorage.dart';
import 'package:logger/logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:path_provider/path_provider.dart';

// RLogger? rLogger;
String? _logsDirPath;

class LogOutputIns extends LogOutput {
  final eventsCache = <OutputEvent>[];

  String _getCurrentDate() {
    final DateTime now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  void writeLogs() async {
    var size = eventsCache.length;
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      if (size > 20 || size == eventsCache.length) {
        final file = File('$_logsDirPath/${_getCurrentDate()}.log');
        final sb = StringBuffer();
        for (final event in eventsCache) {
          sb.writeln(event.lines.join('\n'));
        }
        await file.writeAsString(sb.toString(), mode: FileMode.append);
        eventsCache.clear();
        break;
      }
      size = eventsCache.length;
    }
  }

  @override
  void output(OutputEvent event) {
    final isNotEmpty = eventsCache.isNotEmpty;
    eventsCache.add(event);
    if (isNotEmpty) return;

    writeLogs();
  }
}

final logger = Logger(
    printer: PrettyPrinter(
      printTime: true,
      printEmojis: true,
      colors: kDebugMode,
    ),
    output: LogOutputIns());

// const _title = 'Auto report';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initLocalStorage();
  WakelockPlus.enable();

  final tmpDir = await getApplicationCacheDirectory();
  final logsDir = Directory('${tmpDir.path}/logs');
  debugPrint('logs dir: $logsDir');
  _logsDirPath = logsDir.path;

  if (!await logsDir.exists()) {
    await logsDir.create();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final title = GlobalConfig.bankType == BankType.kbz ? 'KBZ' : 'Wave';
    return MaterialApp(
      title: title,
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
          return wave_home.HomePage(title: title, platforms: data);
        },
        '/kbz/auth': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as Map<String, dynamic>;
          return kbz_auth.AuthPage(
            platforms: data['platforms'],
            phoneNumber: data['phoneNumber'],
            id: data['id'],
            pin: data['pin'],
            token: data['token'],
            remark: data['remark'],
          );
        },
        '/kbz/home': (context) {
          final data = ModalRoute.of(context)?.settings.arguments
              as List<GetPlatformsResponseData?>?;
          return kbz_home.HomePage(title: title, platforms: data);
        },
      },
      // theme: ThemeData.light(),
      home: LoginPage(title: title),
      builder: EasyLoading.init(),
    );
  }
}
