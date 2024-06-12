import 'dart:convert';
import 'dart:math';

import 'package:pointycastle/export.dart';

import 'package:encrypt/encrypt.dart';

class RSAHelper {
  static String encrypt(String plaintext, String publicKey) {
    var parser = RSAKeyParser();
    final encrypter =
        Encrypter(RSA(publicKey: parser.parse(publicKey) as RSAPublicKey));
    return encrypter.encrypt(plaintext).base64;
  }

  static String decrypt(String plaintext, String privateKey) {
    final bytes = base64Decode(plaintext);
    final bytesLen = bytes.length;
    final key = RSAKeyParser().parse(privateKey) as RSAPrivateKey;
    final chunkSize = (key.n!.bitLength + 7) ~/ 8;
    final encrypter = Encrypter(RSA(privateKey: key));

    final sb = StringBuffer();
    var start = 0;
    while (start < bytesLen) {
      final end = min(bytesLen, start + chunkSize);
      final data = bytes.sublist(start, min(bytesLen, start + chunkSize));
      start = end;
      sb.write(encrypter.decrypt(Encrypted(data)));
    }
    final ret = sb.toString();
    return ret;
  }
}
