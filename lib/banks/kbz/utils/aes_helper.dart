import 'dart:convert';
import 'dart:typed_data';
import 'package:auto_report/utils/log_helper.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';

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

  static String encrypt1(String content, Key aesKey, IV ivKey) {
    try {
      final key = aesKey;
      final iv = ivKey;

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

  static String encryptGCM(
      String plaintext, String base64Key, String ivString) {
    try {
      // 1. Key (Base64 -> Bytes)
      final keyBytes = base64.decode(base64Key);

      // 2. IV (String -> Bytes UTF-8)
      // 保持与 JS Buffer.from(iv, 'utf8') 一致
      final ivBytes = utf8.encode(ivString);

      // 3. 数据
      final dataBytes = utf8.encode(plaintext);

      // 4. 配置 AES-GCM
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
          KeyParameter(keyBytes),
          128, // Mac Size (128 bits)
          Uint8List.fromList(ivBytes),
          Uint8List(0) // Associated Data
          );

      cipher.init(true, params);

      // 5. 准备输出缓冲区
      // getOutputSize 返回的大小可能包含填充，比实际结果大
      final out = Uint8List(cipher.getOutputSize(dataBytes.length));

      // 6. 加密处理
      // processBytes 返回实际写入密文的长度
      int len = cipher.processBytes(dataBytes, 0, dataBytes.length, out, 0);

      // 7. 追加 Tag
      // doFinal 返回实际写入 Tag 的长度
      int lenMac = cipher.doFinal(out, len);

      // 8. ★关键修正★：截取实际有效长度
      // 实际长度 = 密文长度 + Tag长度
      final actualBytes = out.sublist(0, len + lenMac);

      // 9. 转 Base64
      return base64.encode(actualBytes);
    } catch (e) {
      print("加密失败: $e");
      return "";
    }
  }

  static String decryptGCM(
      String ciphertextBase64, String base64Key, String ivString) {
    try {
      // 1. 解析 Key (Base64 -> Bytes)
      final keyBytes = base64.decode(base64Key);

      // 2. 解析 IV (UTF-8 -> Bytes)
      // 必须与加密时的逻辑保持一致
      final ivBytes = utf8.encode(ivString);

      // 3. 解析密文 (Base64 -> Bytes)
      // 此时 encryptedBytes 包含 [Ciphertext] + [Tag]
      final encryptedBytes = base64.decode(ciphertextBase64);

      // 4. 配置 AES-GCM
      final cipher = GCMBlockCipher(AESEngine());
      final params = AEADParameters(
          KeyParameter(keyBytes),
          128, // Mac Size (128 bits)
          Uint8List.fromList(ivBytes),
          Uint8List(0) // Associated Data
          );

      // ★关键点★: init 第一个参数为 false，表示解密
      cipher.init(false, params);

      // 5. 准备输出缓冲区
      // 解密时，输出大小 = 输入长度 - Tag长度
      final out = Uint8List(cipher.getOutputSize(encryptedBytes.length));

      // 6. 执行解密
      // PointyCastle 会自动处理末尾的 Tag
      int len =
          cipher.processBytes(encryptedBytes, 0, encryptedBytes.length, out, 0);

      // doFinal 会进行 Tag 校验。如果校验失败，这里会抛出异常。
      int lenMac = cipher.doFinal(out, len);

      // 7. 截取有效数据并转为 UTF-8 字符串
      // 解密后的数据不包含 Tag，所以总长度就是 len + lenMac (lenMac 在解密时通常为0，因为没有写入额外数据)
      final actualBytes = out.sublist(0, len + lenMac);

      return utf8.decode(actualBytes);
    } catch (e) {
      print("解密失败: $e");
      // 如果 Tag 校验失败，PointyCastle 会抛出 InvalidCipherTextException
      return "";
    }
  }

  // static String encrypt1(String content, String aesKey, Uint8 ivKey) {
  //   try {
  //     final key = Key.fromBase64(aesKey);
  //     final iv = IV.fromUtf8(ivKey);

  //     if (iv.bytes.length != 16) {
  //       logger.e("IV length is not equal to 16");
  //       return "";
  //     }

  //     final encrypter =
  //         Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

  //     final encrypted = encrypter.encrypt(content, iv: iv);
  //     return encrypted.base64;
  //   } catch (e, s) {
  //     logger.e(e, stackTrace: s);
  //     return "";
  //   }
  // }

  static Uint8List pkcs7UnPadding(Uint8List data) {
    // final length = data.length;
    // final unPadding = data[length - 1];
    // return data.sublist(0, length - unPadding);
    return data;
  }

  static String decrypt(String cipherTextBase64, String keyBase64, String iv) {
    return decryptGCM(cipherTextBase64, keyBase64, iv);
    // try {
    //   final key = Key.fromBase64(keyBase64);
    //   final ivBytes = IV.fromUtf8(iv);

    //   if (ivBytes.bytes.length != 16) {
    //     throw ArgumentError("IV length is not equal to 16");
    //   }

    //   final encrypter =
    //       Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

    //   final encryptedBytes = base64.decode(cipherTextBase64);

    //   final decryptedBytes =
    //       encrypter.decryptBytes(Encrypted(encryptedBytes), iv: ivBytes);

    //   final unpaddedDecryptedBytes =
    //       pkcs7UnPadding(Uint8List.fromList(decryptedBytes));

    //   return utf8.decode(unpaddedDecryptedBytes);
    // } catch (e, s) {
    //   logger.e(e, stackTrace: s);
    //   return "";
    // }
  }
}
