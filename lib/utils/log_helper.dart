import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

String? logsDirPath;

class MyFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) {
    return true;
  }
}

class _LogOutputIns extends LogOutput {
  final eventsCache = <OutputEvent>[];

  String appVersion = '';

  _LogOutputIns() {
    initState();
  }

  void initState() async {
    final packageInfo = await PackageInfo.fromPlatform();
    appVersion = packageInfo.version;
  }

  String _getCurrentDate() {
    final DateTime now = DateTime.now();
    return '${now.year}_${now.month.toString().padLeft(2, '0')}_${now.day}'
        '__${now.hour.toString().padLeft(2, '0')}';
  }

  void _writeLogs() async {
    var size = eventsCache.length;
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      if (size > 20 || size == eventsCache.length) {
        final file = File('$logsDirPath/${_getCurrentDate()}.log.txt');
        final sb = StringBuffer();
        sb.writeln("app ver: $appVersion");
        for (final event in eventsCache) {
          sb.writeln(event.lines.join('\n'));
        }
        await file.writeAsString(sb.toString(), mode: FileMode.writeOnlyAppend);
        eventsCache.clear();
        break;
      }
      size = eventsCache.length;
    }
  }

  @override
  void output(OutputEvent event) {
    // print('${event.level}: ${event.lines.join('\n')}');
    final isNotEmpty = eventsCache.isNotEmpty;
    eventsCache.add(event);
    if (isNotEmpty) return;

    _writeLogs();
  }
}

final logger = Logger(
  printer: PrettyPrinter(
    // printTime: true,
    dateTimeFormat: DateTimeFormat.dateAndTime,
    printEmojis: true,
    colors: true,
  ),
  // output: (kDebugMode && Platform.isMacOS) ? null : _LogOutputIns(),
  output: kDebugMode ? null : _LogOutputIns(),
  // output: _LogOutputIns(),
  level: Level.all,
  filter: MyFilter(),
);

initLogger() async {
  Logger.level = Level.all;

  final tmpDir = await getApplicationCacheDirectory();
  final logsDir = Directory('${tmpDir.path}/logs');
  debugPrint('logs dir: $logsDir');
  logsDirPath = logsDir.path;

  if (!await logsDir.exists()) {
    await logsDir.create();
  }
}
