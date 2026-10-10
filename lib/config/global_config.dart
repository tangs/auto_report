import 'package:auto_report/widges/bank_selector.dart';

class GlobalConfig {
  static BankType bankType = BankType.wave;

  static const localTestPlatform = 'local_test';
  static const localTestBackendUrl = 'http://127.0.0.1:18080';

  static const logCountMax = 1024;

  static const httpRequestTimeoutSeconds = 50;
}
