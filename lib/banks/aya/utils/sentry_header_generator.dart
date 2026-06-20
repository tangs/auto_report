import 'dart:convert';
import 'dart:math';

class SentryHeaderGenerator {
  static const String _alphanumericChars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static const String _hexChars = '0123456789abcdef';
  static final Random _random = Random();

  /// 生成指定长度的随机字符串（大小写字母+数字）
  static String _generateRandomString(int length) {
    return List.generate(
            length,
            (index) =>
                _alphanumericChars[_random.nextInt(_alphanumericChars.length)])
        .join();
  }

  /// 生成指定长度的十六进制字符串
  static String _generateHex(int length) {
    return List.generate(length, (index) => _hexChars[_random.nextInt(16)])
        .join();
  }

  /// 一键生成整套模拟 Headers
  static Map<String, String> generateFullMockHeaders() {
    // 1. 生成 Sentry 相关 ID
    String traceId = _generateHex(32);
    String spanId = _generateHex(16);

    // 2. 生成 Authorization 凭证 (32位随机字符串)
    String authCredentials = _generateRandomString(32);

    return {
      // Sentry 链路追踪
      'Sentry-Trace': '$traceId-$spanId-1',

      // Baggage 上下文 (trace_id 必须与上面一致)
      'Baggage':
          'sentry-environment=production,sentry-public_key=dc90897854163b60850b69daf43b68e6,sentry-trace_id=$traceId,sentry-org_id=1016539',

      // 身份认证
      'Authorization': 'Basic $authCredentials',

      // 其他常见的固定 Header (可选)
      'Content-Type': 'application/json',
      'Accept': '*/*',
    };
  }

  static Map<String, String> generateSentryHeaders(
      String username, String password) {
    // 1. 生成 Authorization (Basic Auth)
    // 格式：Basic base64(username:password)
    String authString = '$username:$password';
    String encodedAuth = base64Encode(utf8.encode(authString));
    String authorization = 'Basic $encodedAuth';

    // 辅助函数：生成指定长度的随机十六进制字符串
    String generateHex(int length) {
      final random = Random();
      const chars = '0123456789abcdef';
      return List.generate(
          length, (index) => chars[random.nextInt(chars.length)]).join();
    }

    // 2. 生成 sentry-trace
    // 格式：trace_id(32位) - span_id(16位) - sampled(1)
    String traceId = generateHex(32);
    String spanId = generateHex(16);
    String sentryTrace = '$traceId-$spanId-1';

    // 3. 生成 baggage
    // 其中的 trace_id 必须与 sentry-trace 中的一致
    // 注意：sentry-public_key 通常是你的 DSN 中的 Key 部分
    String baggage = 'sentry-environment=production,'
        'sentry-release=1.0.0,'
        'sentry-public_key=your_public_key_here,'
        'sentry-trace_id=$traceId,'
        'sentry-sample_rate=1.0';

    return {
      'Authorization': authorization,
      'sentry-trace': sentryTrace,
      'baggage': baggage,
      'Content-Type': 'application/json', // 通常配合 JSON 请求使用
    };
  }
}

// void main() {
//   // 生成并打印
//   var headers = SentryHeaderGenerator.generateSentryHeaders();

//   print("Generated Headers:");
//   headers.forEach((key, value) {
//     print("$key: $value");
//   });

//   // 验证 Trace ID 是否匹配
//   String traceInSentryTrace = headers['Sentry-Trace']!.split('-')[0];
//   bool isMatched = headers['Baggage']!.contains(traceInSentryTrace);
//   print("\nTrace ID 匹配验证: ${isMatched ? '✅ 通过' : '❌ 失败'}");
// }
