import 'package:auto_report/config/config.dart';
import 'package:pointycastle/export.dart';

import 'package:encrypt/encrypt.dart';

class RSAHelper {
  static String encrypt(String plaintext, String publicKey) {
    var parser = RSAKeyParser();
    final encrypter = Encrypter(
        RSA(publicKey: parser.parse(Config.rsaPublicKey) as RSAPublicKey));
    return encrypter.encrypt(plaintext).base64;
  }
}
