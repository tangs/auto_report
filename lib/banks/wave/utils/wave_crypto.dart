import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/asymmetric/api.dart';

class WaveCrypto {
  /// 1. 随机生成 UID (模拟 App 内部生成的 8 位或 16 位 16 进制标识)
  static String generateRandomUid({int length = 8}) {
    const chars = 'abcdef0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  /// 2. 随机生成 IV 的 Base64 字符串 (AES-128 需要 16 字节)
  static String generateRandomIvB64() {
    // 生成 16 字节的随机数
    final rnd = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(16, (i) => rnd.nextInt(256)),
    );
    // 转换为 Base64 (对应 Java 的 Base64.encodeToString(..., 2))
    return base64.encode(bytes);
  }

  /// 3. 密钥派生: SHA-1(uid) 取前 16 字节 (对应 je.b 方法)
  static encrypt.Key _deriveKey(String uid) {
    var bytes = utf8.encode(uid);
    var digest = sha1.convert(bytes);
    // 取哈希结果的前 16 字节
    Uint8List keyBytes = Uint8List.fromList(digest.bytes.sublist(0, 16));
    return encrypt.Key(keyBytes);
  }

  /// 4. 加密函数 (对应 cl.b 方法)
  static String encryptRequest(String plainText, String uid, String ivB64) {
    try {
      final key = _deriveKey(uid);
      final iv = encrypt.IV.fromBase64(ivB64);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      final encrypted = encrypter.encrypt(plainText, iv: iv);
      return encrypted.base64;
    } catch (e) {
      return "加密失败: $e";
    }
  }

  /// 5. 解密函数 (对应 cl.a 方法)
  static String decryptResponse(String cipherB64, String uid, String ivB64) {
    try {
      final key = _deriveKey(uid);
      final iv = encrypt.IV.fromBase64(ivB64);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.cbc, padding: 'PKCS7'),
      );

      return encrypter.decrypt64(cipherB64, iv: iv);
    } catch (e) {
      return "解密失败: $e";
    }
  }

  static String encryptKeyHeader(String uid, String ivB64, String publicKeyPem) {
    try {
      // 1. 拼接文本: uid:ivB64
      final String plainText = "$uid:$ivB64";

      // 2. 解析公钥 (encrypt 库会自动处理 PEM 的头尾清理)
      final parser = encrypt.RSAKeyParser();
      final RSAPublicKey publicKey = parser.parse(publicKeyPem) as RSAPublicKey;

      // 3. 配置 RSA 加密器
      // 注意: Java 代码中是 PKCS1Padding，对应 Dart 中的 RSAEncoding.PKCS1
      final encrypter = encrypt.Encrypter(
        encrypt.RSA(
          publicKey: publicKey, 
          encoding: encrypt.RSAEncoding.PKCS1
        )
      );

      // 4. 执行加密并返回 Base64
      final encrypted = encrypter.encrypt(plainText);
      
      // 对应 Java 的 Base64.encodeToString(..., 2) 即 NO_WRAP
      return encrypted.base64;
    } catch (e) {
      return "RSA加密失败: ${e.toString()}";
    }
  }
}