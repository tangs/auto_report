import 'dart:convert';
import 'package:crypto/crypto.dart';

class ShaHelper {
  static String hashMacSha256(String str, String key) {
    final keyBytes = utf8.encode(key);
    final dataBytes = utf8.encode(str);

    final hmacSha256 = Hmac(sha256, keyBytes);
    final digest = hmacSha256.convert(dataBytes);

    return digest.toString();
  }
}
