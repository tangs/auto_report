import 'dart:convert';
import 'dart:typed_data';
import 'package:basic_utils/basic_utils.dart';
import 'package:pointycastle/export.dart';

class RSAHelper1 {
  
  /// 对应 Java 的 encrypt 方法
  /// [str]: 需要加密的明文
  /// [publicKeyStr]: 公钥字符串 (PEM 格式或 Base64)
  static String encrypt(String str, String publicKeyStr) {
    try {
      // 1. 解析公钥
      RSAPublicKey publicKey = CryptoUtils.rsaPublicKeyFromPem(publicKeyStr);

      // 2. 初始化加密引擎
      // 修正点：OAEPEncoding 构造函数不再接收 Digest 参数。
      // 先实例化，使用默认的 RSAEngine
      // final cipher = OAEPEncoding(RSAEngine());
      
      // // 3. 配置具体的 Hash 算法
      // // 对应 Java: RSA/ECB/OAEPWithSHA-256AndMGF1Padding
      // // 主哈希设置 (SHA-256)
      // cipher.hash = SHA256Digest();
      // // MGF1 哈希设置 (SHA-1) - Java 的默认 MGF1 通常使用 SHA-1，即使主哈希是 SHA-256
      // cipher.mgf1Hash = SHA1Digest();

      final cipher = OAEPEncoding.withSHA256(RSAEngine());

      // 2. 【核心修复】手动覆盖 MGF1 哈希
      // PointyCastle 默认会将 MGF1 哈希设为与主哈希相同(即 SHA-256)。
      // 但你的 Java 代码指定了 MGF1 为 SHA-1，所以这里必须手动强转！
      cipher.mgf1Hash = SHA512Digest();

      // 4. 初始化
      // true 表示加密模式
      cipher.init(true, PublicKeyParameter<RSAPublicKey>(publicKey));

      // 5. 执行加密
      final inputBytes = utf8.encode(str);
      final encryptedBytes = cipher.process(inputBytes);

      // 6. Base64 编码返回
      return base64Encode(encryptedBytes);
      
    } catch (e) {
      print("Encryption error: $e");
      return "";
    }
  }

  static String? decrypt(String encryptedStr, String privateKeyPem) {
    try {
      // 1. 清洗并解码 (防止换行符干扰)
      String cleanStr = encryptedStr.replaceAll(RegExp(r'\s+'), '');
      final encryptedBytes = base64Decode(cleanStr);

      // 2. 解析私钥
      RSAPrivateKey privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);

      // -------------------------------------------------------------
      // 3. 核心配置：完全对标 Java 截图中的 "OAEPWithSHA-256AndMGF1Padding"
      // -------------------------------------------------------------
      
      // 步骤 A: 对应 "SHA-256" (主哈希)
      // 使用 withCustomDigest 是最稳妥的，防止 PointyCastle 内部工厂的默认干扰
      final Uint8List emptyLabel = Uint8List(0); 

      final cipher = OAEPEncoding.withCustomDigest(
        () => SHA256Digest(), 
        RSAEngine(),
        emptyLabel // <--- 传在这里
      );

      // 步骤 B: 对应 "MGF1Padding"
      // 在 Android/Java 标准中，即使主Hash是256，MGF1 默认依然是 SHA-1
      // 且你的 Java 代码显式写了 MGF1ParameterSpec.SHA1
      cipher.mgf1Hash = SHA1Digest(); 

      // -------------------------------------------------------------

      // 4. 初始化 (false = 解密)
      cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      // 5. 执行
      final decryptedBytes = cipher.process(encryptedBytes);
      return utf8.decode(decryptedBytes);

    } catch (e) {
      print("解密失败: $e");
      // 如果还报 decoding error，那只剩下一种可能：Key不对。
      return null;
    }
  }

}