import 'package:auto_report/pages/auth_page.dart';

class AccountData {
  String phoneNumber;
  String pin;
  String authCode;
  String wmtMfs;

  bool isWmtMfsInvalid;

  DateTime lastUpdateTime = DateTime.fromMicrosecondsSinceEpoch(0);

  AccountData({
    required this.phoneNumber,
    required this.pin,
    required this.authCode,
    required this.wmtMfs,
    required this.isWmtMfsInvalid,
  });

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }

  updateOrder() async {
    var seconds = DateTime.now().difference(lastUpdateTime).inSeconds;
    logger.i('seconds: $seconds');
  }
}
