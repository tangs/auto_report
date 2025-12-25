import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:basic_utils/basic_utils.dart';

// 你提供的私钥
const String privateKeyPem = '''-----BEGIN PRIVATE KEY-----
MIICdgIBADANBgkqhkiG9w0BAQEFAASCAmAwggJcAgEAAoGBAIwHIC/L/K0vx4rP
8QUuqDg/b+q6LjxnmApZmQXLGnlsPW2NROv7pRKU/FLP0zGS5r7SCSQIjnja0L7Z
SLjO6pTqY3o7Rb3Mf/HlmHTQmuMgGV7VHI6b2IbKeXr2sV3b/Vf97vaVf7wGQGoY
imi89tgPXUheHcn5+q8PkHiyDxu7AgMBAAECgYAOKVpT+yleyoo/u7AAeiuBJMlI
z/OFIGT8Bvu23kebKBs+TR8/Tn/vVSn/pg0R4m17tvo9rq/aASdDZe444pROu3qK
7as2WUDnRxxQsvPp1aTQ4fouJMU/gn3yrZK/tbzV4ZlOPK0OEnrXeWsCicESIq/y
w2dtOGJtnGNqMnCZwQJBAPi75oq+w/AI+pywYNf+Ak5gM+yLoYMWz4bFANRlpOy1
efIxQe0CKJMRwvaTtPauVxFX2ZGRG01vcEG2mvqqDzkCQQCQHkqa0KuDgPzYmodA
5LA/UCrM8pAhbpYOz5+KXvwfJ0iN268snK2T5m1+39apQMiIhhJvdVRNFDTOvQeq
7U6TAkEAm7P8GERcoWjtgKKErRDr3qYoOt4Zh9cCp+mwoETUnfzoTmz5SOU+Avpu
Yi6KbJUsGcY1gwMj5TBqRCiMEXfdOQJAKk86R8kLEUhE8rIrEvoQZAX9Cr4LYkU8
+IwrokvQaLT3r+3Wt5onu0viyWSdeIL0XGA/+UjQvvA3sJn+LkgM0QJATUfI2uiv
YQvjI7pNiR5pyeT9bC304Ho+R+00kASGvCpZALvOYOQ62c797rTiqaNOh8WRwX8i
hfqkU1SnxYTFyw==
-----END PRIVATE KEY-----''';

// 你提供的 Java 加密密文
const String javaCipherBase64 = 
    "SMnuGHqVeKzjA7Lgo/lHcvQAHYntYx3gqjUDLUULem9y7LQtA4HRAZVyaP4s7gjZj4IXWItmDeBJtjqOw+SPfOa62y/tdB2WCnVtdK2SnDgi2Tgd3pIfSm4a24wHnPmPnxYwRKJv7xYQPVXtSqOTNsEPp8sGEbgkZV2+EGjzSCI=";

void main() {
  print("=== 开始 RSA OAEP 暴力匹配测试 ===");
  
  // 1. 准备私钥
  RSAPrivateKey privateKey;
  try {
    privateKey = CryptoUtils.rsaPrivateKeyFromPem(privateKeyPem);
  } catch (e) {
    print("❌ 私钥解析失败，请检查格式");
    return;
  }

  // 2. 准备密文
  Uint8List encryptedBytes;
  try {
    encryptedBytes = base64Decode(javaCipherBase64);
    print("密文长度: ${encryptedBytes.length} (预期 128)");
  } catch (e) {
    print("❌ Base64 解码失败");
    return;
  }

  // 3. 定义 4 种可能的组合
  final combinations = [
    _Config("方案1 (标准 Java)", SHA256Digest(), SHA1Digest()),   // Main: SHA-256, MGF1: SHA-1
    _Config("方案2 (Dart 默认)", SHA256Digest(), SHA256Digest()), // Main: SHA-256, MGF1: SHA-256
    _Config("方案3 (旧版标准)", SHA1Digest(), SHA1Digest()),       // Main: SHA-1,   MGF1: SHA-1
    _Config("方案4 (混合)", SHA1Digest(), SHA256Digest()),         // Main: SHA-1,   MGF1: SHA-256
  ];

  bool success = false;

  // 4. 循环尝试
  for (var config in combinations) {
    print("\n---------------------------------------------------");
    print("尝试 [${config.name}]");
    print("Main Hash: ${config.mainHash.algorithmName}");
    print("MGF1 Hash: ${config.mgf1Hash.algorithmName}");

    try {
      // 构建引擎
      // 注意：这里使用 withCustomDigest 来确保完全控制，不依赖工厂方法的默认行为
      OAEPEncoding cipher = OAEPEncoding.withCustomDigest(
        () => config.mainHash, // Main Hash 工厂
        RSAEngine(),
      );
      
      // 强制设置 MGF1
      cipher.mgf1Hash = config.mgf1Hash;

      // 初始化
      cipher.init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));

      // 解密
      Uint8List decrypted = cipher.process(encryptedBytes);
      String result = utf8.decode(decrypted);

      print("✅✅✅ 解密成功！！！ ✅✅✅");
      print("正确内容: $result");
      print(">>> 请使用 [${config.name}] 的配置修改你的代码 <<<");
      success = true;
      break; // 找到后直接退出
    } catch (e) {
      print("❌ 失败: $e");
    }
  }

  if (!success) {
    print("\n===================================================");
    print("💀 最终结论：所有可能的算法组合均失败 💀");
    print("这意味着：Java端使用的公钥 与 Dart端使用的私钥 【根本不是一对】。");
    print("请不要怀疑代码了，请重新生成一对密钥，并确保两端更新。");
    print("===================================================");
  }
}

class _Config {
  final String name;
  final Digest mainHash;
  final Digest mgf1Hash;
  _Config(this.name, this.mainHash, this.mgf1Hash);
}