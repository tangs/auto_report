import 'dart:convert';

import 'package:auto_report/banks/kbz/config/config.dart';
import 'package:auto_report/banks/kbz/utils/aes_helper.dart';
import 'package:auto_report/banks/kbz/utils/sha_helper.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:http/http.dart' as http;

class Sender {
  final String aesKey;
  final String ivKey;

  Sender({required this.aesKey, required this.ivKey});

  Future post({required Map body, required Map<String, String> header}) async {
    final timestamp = '${DateTime.now().toUtc().millisecondsSinceEpoch}';
    final url = Uri.https(Config.host, 'api/interface/version1.1/customer');
    final encryptKey = RSAHelper.encrypt(aesKey, Config.rsaPublicKey);
    final encryptIV = RSAHelper.encrypt(ivKey, Config.rsaPublicKey);

    final bodyConetnt = jsonEncode(body);
    final sign =
        ShaHelper.hashMacSha256(timestamp + ivKey + bodyConetnt, aesKey);

    final encryptBody = AesHelper.encrypt(bodyConetnt, aesKey, ivKey);
    final headers = Config.getHeaders()
      ..addAll(header)
      ..addAll({
        'Authorization': encryptKey,
        'IvKey': encryptIV,
        'Sign': sign,
        "Timestamp": timestamp,
      });

    return await Future.any([
      http.post(url, headers: headers, body: encryptBody),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);
  }
}
