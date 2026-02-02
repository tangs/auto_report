import 'dart:math';

class SentryHeaderGenerator {
  static const String _hexChars = '0123456789abcdef';
  static final Random _random = Random();

  /// 生成指定长度的十六进制字符串
  static String _generateHex(int length) {
    return List.generate(length, (index) => _hexChars[_random.nextInt(16)]).join();
  }

  /// 生成 Sentry 相关的 Headers
  static Map<String, String> generateSentryHeaders({
    String environment = 'production',
    String publicKey = 'dc90897854163b60850b69daf43b68e6', // 建议换成你自己的
    String orgId = '1016539',
  }) {
    // 1. 生成核心 ID
    String traceId = _generateHex(32); // 32位 Trace ID
    String spanId = _generateHex(16);  // 16位 Span ID
    
    // 2. 构造 Sentry-Trace
    // 格式：traceid-spanid-sampled (sampled 通常设为 1 表示记录)
    String sentryTrace = "$traceId-$spanId-1";

    // 3. 构造 Baggage
    // 注意：sentry-trace_id 必须等于上面的 traceId
    String baggage = [
      'sentry-environment=$environment',
      'sentry-public_key=$publicKey',
      'sentry-trace_id=$traceId',
      'sentry-org_id=$orgId'
    ].join(',');

    return {
      'Sentry-Trace': sentryTrace,
      'Baggage': baggage,
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