class AccountData {
  String phoneNumber;
  String pin;
  String authCode;
  String wmtMfs;

  DateTime lastUpdateTime = DateTime.now();

  AccountData({
    required this.phoneNumber,
    required this.pin,
    required this.authCode,
    required this.wmtMfs,
  });

  @override
  String toString() {
    return 'phone number: $phoneNumber, pin: $pin, auth code: $authCode, wmt mfs: $wmtMfs';
  }
}
