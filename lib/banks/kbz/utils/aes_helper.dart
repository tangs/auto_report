import 'dart:convert';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';

import 'package:auto_report/main.dart';

class AesHelper {
  static String encrypt(String content, String aesKey, String ivKey) {
    try {
      final key = Key.fromBase64(aesKey);
      final iv = IV.fromUtf8(ivKey);

      if (iv.bytes.length != 16) {
        logger.e("IV length is not equal to 16");
        return "";
      }

      final encrypter =
          Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

      final encrypted = encrypter.encrypt(content, iv: iv);
      return encrypted.base64;
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      return "";
    }
  }

  static Uint8List pkcs7UnPadding(Uint8List data) {
    // final length = data.length;
    // final unPadding = data[length - 1];
    // return data.sublist(0, length - unPadding);
    return data;
  }

  static String decrypt(String cipherTextBase64, String keyBase64, String iv) {
    try {
      final key = Key.fromBase64(keyBase64);
      final ivBytes = IV.fromUtf8(iv);

      if (ivBytes.bytes.length != 16) {
        throw ArgumentError("IV length is not equal to 16");
      }

      final encrypter =
          Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

      final encryptedBytes = base64.decode(cipherTextBase64);

      final decryptedBytes =
          encrypter.decryptBytes(Encrypted(encryptedBytes), iv: ivBytes);

      final unpaddedDecryptedBytes =
          pkcs7UnPadding(Uint8List.fromList(decryptedBytes));

      return utf8.decode(unpaddedDecryptedBytes);
    } catch (e, s) {
      logger.e(e, stackTrace: s);
      return "";
    }
  }
}
