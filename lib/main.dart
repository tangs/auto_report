import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/banks/wave/pages/auth_page.dart' as wave_auth;
import 'package:auto_report/banks/wave/pages/home_page.dart' as wave_home;
import 'package:auto_report/banks/kbz/pages/auth_page.dart' as kbz_auth;
import 'package:auto_report/banks/kbz/pages/home_page.dart' as kbz_home;
import 'package:auto_report/pages/login_page.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:auto_report/widges/bank_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:localstorage/localstorage.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// String? logsDirPath;

// class MyFilter extends LogFilter {
//   @override
//   bool shouldLog(LogEvent event) {
//     return true;
//   }
// }

// class _LogOutputIns extends LogOutput {
//   final eventsCache = <OutputEvent>[];

//   String appVersion = '';

//   _LogOutputIns() {
//     initState();
//   }

//   void initState() async {
//     final packageInfo = await PackageInfo.fromPlatform();
//     appVersion = packageInfo.version;
//   }

//   String _getCurrentDate() {
//     final DateTime now = DateTime.now();
//     return '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day}'
//         '__${now.hour.toString().padLeft(2, '0')}';
//   }

//   void _writeLogs() async {
//     var size = eventsCache.length;
//     while (true) {
//       await Future.delayed(const Duration(seconds: 5));
//       if (size > 20 || size == eventsCache.length) {
//         final file = File('$logsDirPath/${_getCurrentDate()}.log.txt');
//         final sb = StringBuffer();
//         sb.writeln("app ver: $appVersion");
//         for (final event in eventsCache) {
//           sb.writeln(event.lines.join('\n'));
//         }
//         await file.writeAsString(sb.toString(), mode: FileMode.writeOnlyAppend);
//         eventsCache.clear();
//         break;
//       }
//       size = eventsCache.length;
//     }
//   }

//   @override
//   void output(OutputEvent event) {
//     // print('${event.level}: ${event.lines.join('\n')}');
//     final isNotEmpty = eventsCache.isNotEmpty;
//     eventsCache.add(event);
//     if (isNotEmpty) return;

//     _writeLogs();
//   }
// }

// final logger = Logger(
//   printer: PrettyPrinter(
//     // printTime: true,
//     dateTimeFormat: DateTimeFormat.dateAndTime,
//     printEmojis: true,
//     colors: true,
//   ),
//   // output: (kDebugMode && Platform.isMacOS) ? null : _LogOutputIns(),
//   output: kDebugMode ? null : _LogOutputIns(),
//   // output: _LogOutputIns(),
//   level: Level.all,
//   filter: MyFilter(),
// );

// const _title = 'Auto report';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initLocalStorage();
  await WakelockPlus.enable();
  await initLogger();

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
          return wave_home.HomePage(
            title: GlobalConfig.bankType == BankType.kbz ? 'KBZ' : 'Wave',
            platforms: data,
          );
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
          return kbz_home.HomePage(
            title: GlobalConfig.bankType == BankType.kbz ? 'KBZ' : 'Wave',
            platforms: data,
          );
        },
      },
      // theme: ThemeData.light(),
      home: LoginPage(title: title),
      builder: EasyLoading.init(),
    );
  }
}
