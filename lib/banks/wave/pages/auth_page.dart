import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// import 'package:auto_report/banks/kbz/utils/aes_helper.dart';
import 'package:auto_report/banks/wave/config/config.dart';
import 'package:auto_report/banks/wave/data/account/account_data.dart';
import 'package:auto_report/banks/wave/data/proto/response/generate_otp_response.dart';
import 'package:auto_report/banks/wave/utils/wave_crypto.dart';
import 'package:auto_report/proto/report/response/get_platforms_response.dart';
import 'package:auto_report/proto/report/response/general_response.dart';
import 'package:auto_report/rsa/rsa_helper.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:auto_report/widges/platform_selector.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';

class AuthPage extends StatefulWidget {
  final List<GetPlatformsResponseData?>? platforms;
  final String? phoneNumber;
  final String? pin;
  final String? nrc;
  final String? token;
  final String? remark;

  const AuthPage({
    super.key,
    required this.platforms,
    this.phoneNumber,
    this.pin,
    this.nrc,
    this.token,
    this.remark,
  });

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  String? _phoneNumber;
  String? _pin;
  String? _nrc;
  String? _otpCode;
  String? _token;
  String? _remark;

  String? _wmtMfs;

  // String aesKey = AesKeyGenerator.generateRandomKey1();
  encrypt.IV ivKey = encrypt.IV.fromLength(16);
  String? aesKey;
  // IV? ivKey;

  GetPlatformsResponseData? _platformsResponseData;

  late String _deviceId;
  late String _model;
  late String _osVersion;

  // final _modes = ['Pixel 5', 'Pixel 6', 'Pixel 5 pro'];
  // final _osVersions = ['12', '13', '14'];
  final _modes = [
    // 'Pixel 5',
    // 'Pixel 6',
    // 'Pixel 6 Pro',
    // 'Pixel 7',
    // 'Pixel 7 Pro',
    // 'Pixel 8',
    // 'Pixel 8 Pro',
    'Xiaomi 11',
    'Xiaomi 12',
    'Xiaomi 13',
    'Xiaomi 14',
    'Redmi Note 10',
    'Redmi Note 11',
    'Redmi Note 12',
    'Redmi Note 13 Pro',
    'Redmi K40',
    'Redmi K50',
    'Redmi K60',
    'POCO X3 Pro',
    'POCO F4',
    'POCO F5',
    'Samsung Galaxy S21',
    'Samsung Galaxy S22',
    'Samsung Galaxy S23',
    'Samsung Galaxy A52',
    'Samsung Galaxy A54',
    'OPPO Reno8',
    'OPPO Reno10',
    'OnePlus 9',
    'OnePlus 11',
    'vivo V27',
    'vivo V29',
  ];

  final _osVersions = [
    '10',
    '11',
    '12',
    '13',
    '14',
    '15',
  ];

  bool _hasLogin = false;
  bool _hasAuth = false;

  static String generateSessionKey() {
      // 生成UUID并取前8个字符
    final uuid = _generateUUID();
    return uuid.substring(0, 8);
  }
  
  // 生成UUID的简化实现
  static String _generateUUID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    
    // 设置版本位 (version 4)
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    // 设置变体位
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    
    return [
      bytes.take(4).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      bytes.skip(4).take(2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      bytes.skip(6).take(2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      bytes.skip(8).take(2).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
      bytes.skip(10).take(6).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    ].join('-');
  }
  
  // 2. 生成IV（每次请求）
  // static String generateIV() {
  //   final random = Random.secure();
  //   final iv = List<int>.generate(16, (i) => random.nextInt(256));
  //   return base64Url.encode(iv);
  // }
  
  // 3. 将8字符Key转换为128位AES密钥
  static Uint8List _convertKeyToAESKey(String key) {
    // 1. 将8字符Key转换为字节数组
    final keyBytes = utf8.encode(key);
    
    // 2. 计算SHA-1哈希
    final hash = sha1.convert(keyBytes);
    
    // 3. 取前16字节（128位）
    return Uint8List.fromList(hash.bytes.take(16).toList());
  }

  @override
  void initState() {
    super.initState();

    _phoneNumber = widget.phoneNumber ?? '';
    _pin = widget.pin ?? '';
    _nrc = widget.nrc ?? '';

    // _token = widget.token ?? '';
    _token = '';
    _remark = widget.remark ?? '';

    if (_token!.isEmpty) {
      final sb = StringBuffer();
      final rand = Random();
      for (var i = 0; i < 32; ++i) {
        if (rand.nextBool()) {
          sb.write(String.fromCharCode(0x61 + rand.nextInt(26)));
        } else {
          sb.write(String.fromCharCode(0x30 + rand.nextInt(10)));
        }
      }
      _token = sb.toString();
    }
    init();
  }

  void init() async {
    EasyLoading.show();
    // generate device id
    var deviceId = '';
    final ran = Random.secure();
    for (var i = 0; i < 40; ++i) {
      final num = ran.nextInt(16);
      deviceId += num.toRadixString(16);
    }

    _model = _modes[ran.nextInt(_modes.length)];
    _osVersion = _osVersions[ran.nextInt(_osVersions.length)];
    _deviceId = deviceId;

    aesKey = generateSessionKey();

    if (Platform.isAndroid) {
      final deviceInfoPlugin = await DeviceInfoPlugin().androidInfo;
      _model = deviceInfoPlugin.model;
      _osVersion = deviceInfoPlugin.version.release;
    }

    logger.i('device id: $_deviceId, model: $_model, os version: $_osVersion');
    EasyLoading.dismiss();
  }

  void _requestOtp() async {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return;
    }

    EasyLoading.show(status: 'loading...');
    logger.i('request auth code start');
    logger.i('Phone number: $_phoneNumber');

    final url = Uri.https(
        Config.host, 'v3/wmt-mfs-otp/generate-otp', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "user-agent": "okhttp/4.9.0",
        Config.wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('request otp timeout');
        logger.i('request otp timeout');
        return;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return;
      }
      EasyLoading.showInfo('send auth code success.');
      logger.i('request auth code success');
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return;
    } finally {
      EasyLoading.dismiss();
    }
  }

  Future<String?> _generateToken() async {
    logger.i('get token start.');
    logger.i('Phone number: $_phoneNumber');
    // final url = Uri.https(
    //     Config.host, 'wmt-mfs-otp/security-token', {'msisdn': '$_phoneNumber'});
    final url = Uri.https(
        Config.host, 'v3/wmt-mfs-otp/security-token', {'msisdn': '$_phoneNumber'});
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        'user-agent': 'okhttp/4.9.0',
        Config.wmtMfsKey: _wmtMfs ?? '',
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        // EasyLoading.showError('get token timeout');
        logger.i('get token timeout');
        return null;
      }

      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200 || !resBody.isSuccess()) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        // EasyLoading.dismiss();
        return null;
      }
      EasyLoading.showInfo('send auth code success.');
      logger.i('get token success.');
      return resBody.responseMap?.securityCounter;
    } catch (e, stackTrace) {
      logger.e('get token err: $e', stackTrace: stackTrace);
      EasyLoading.showError('get token err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return null;
    }
  }

  Future<bool> _confirmAuthCode() async {
    // final url = Uri.https(Config.host, 'wmt-mfs-otp/confirm-otp');
    final url = Uri.https(Config.host, 'v3/wmt-mfs-otp/confirm-otp');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        // 'Content-Type': 'application/x-www-form-urlencoded',
        "user-agent": "okhttp/4.9.0",
        Config.wmtMfsKey: _wmtMfs ?? '',
      });
    // final formData = [
    //   '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber ?? '')}',
    //   '${Uri.encodeQueryComponent('otp')}=${Uri.encodeQueryComponent(_otpCode ?? '')}',
    // ].join('&');

    final formData = {
      'msisdn': _phoneNumber!,
      'otp': _otpCode!,
    };

    logger.i('confim auth code start');
    logger.i('Phone number: $_phoneNumber');
    logger.i('auth code: $_otpCode');
    logger.i('form data: $formData');
    final response = await Future.any([
      http.post(url, headers: headers, body: formData),
      Future.delayed(const Duration(seconds: Config.httpRequestTimeoutSeconds)),
    ]);

    if (response is! http.Response) {
      EasyLoading.showError('firm auth timeout');
      logger.i('firm auth timeout');
      return false;
    }

    _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
    logger.i('Response status: ${response.statusCode}');
    logger.i('Response body: ${response.body}');
    logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

    final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
    if (response.statusCode != 200 || !resBody.isSuccess()) {
      logger.e('confim auth code errr: ${response.statusCode}',
          stackTrace: StackTrace.current);
      EasyLoading.showToast(
          resBody.message ?? 'err code: ${response.statusCode}');
      return false;
    }
    logger.i('confim auth code success');
    return true;
  }

  String _getSelfAuthoirizedDeviceBody(String nrc, String msisdn) {
    // Parse NRC format: [前缀]/[区代码][国籍]([类型])[号码]
    // Example: 5/MaMaTa(N)028788
    
    // Extract prefix (before the first '/')
    final prefix = nrc.split('/').first;
    
    // Extract the part after '/' and before the last ')'
    final afterSlash = nrc.split('/').last;
    
    // Find the last '(' to get the type
    final lastOpenParenIndex = afterSlash.lastIndexOf('(');
    final lastCloseParenIndex = afterSlash.lastIndexOf(')');
    
    if (lastOpenParenIndex == -1 || lastCloseParenIndex == -1) {
      throw FormatException('Invalid NRC format: $nrc');
    }
    
    // Extract type (between last '(' and ')')
    // final type = afterSlash.substring(lastOpenParenIndex + 1, lastCloseParenIndex);
    
    // Extract number (after the last ')')
    final number = afterSlash.substring(lastCloseParenIndex + 1);
    
    // Extract township code and citizenship (before the last '(')
    final beforeLastParen = afterSlash.substring(0, lastOpenParenIndex);
    
    // Find the citizenship character (should be the last character before '(')
    String citizenship = '';
    String townshipCode = '';
    
    if (beforeLastParen.isNotEmpty) {
      citizenship = beforeLastParen.substring(beforeLastParen.length - 1);
      townshipCode = beforeLastParen.substring(0, beforeLastParen.length - 1);
    }
    
    // Create the identification object
    final identification = {
      "msisdn": msisdn,
      "citizenship": citizenship,
      "number": number,
      "idNumber": nrc,  // Complete NRC number
      "prefix": prefix,
      "townshipCode": townshipCode,
      "type": "NRC"
    };
    
    // Return as JSON string
    return jsonEncode({
      "identification": identification
    });
  }

  String _getKeyAndIV() {
    // final keyBase64 = base64.encode(utf8.encode(aesKey));
    final ivBase64 = base64.encode(ivKey.bytes);
    final key = '$aesKey:$ivBase64';
    // final key1 = base64.encode(utf8.encode(key));
    final key1 = RSAHelper.encrypt(key, Config.rsaPublicKey);
    return key1;
  }

  printHaders(Map<String, String> header) {
    header.forEach((k, v) {logger.i('key: $k, val: $v');});
  }

  Future<bool> _registeredDevices() async {

    // EasyLoading.show(status: 'loading...');
    logger.i('registered-devices start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    logger.i("cipher : $cipher");

    final url = Uri.https(
        Config.host, 'v3/mfs-customer/registered-devices');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "key": cipher,
        "user-agent": "okhttp/4.9.0",
        "Content-Type": "text/plain",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
      // headers.remove("");
    // printHaders(headers);

    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('registered-devices timeout');
        logger.i('registered-devices timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(response.body, myUid, myIvB64);
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('registered-devices success.');
      logger.i('registered-devices success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _registeredDevice() async {

    // EasyLoading.show(status: 'loading...');
    logger.i('registered-device start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");

    logger.i('agent id: $_agentId, device id: $_deviceId');

    final body = {
      "agentId": _agentId,
      "pin": '',
      "deviceAuthorizationStatus": "1",
      "deviceIdToPatch": _deviceId,
    };
    final bodyStr = jsonEncode(body);
    logger.i("body str : $bodyStr");

    String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    String encodedData = Uri.encodeQueryComponent(cipher);
    logger.i("cipher : $cipher");
    logger.i("encodedData : $encodedData");

    var reqBody = {
      "data": encodedData
    };

    final url = Uri.https(
        Config.host, 'v3/mfs-customer/registered-devices');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "key": cipher,
        "user-agent": "okhttp/4.9.0",
        // "Content-Type": "application/json",
        "Accept-Encoding": "application/json",
        "Accept": "*/*",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
    try {
      final response = await Future.any([
        http.patch(url, headers: headers, body: reqBody),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('registered-device timeout');
        logger.i('registered-device timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(response.body, myUid, myIvB64);
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('registered-device success.');
      logger.i('registered-device success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _getBalance() async {
    final url = Uri.https(Config.host, 'v2/mfs-customer/wallet-balance');
      final headers = Config.getHeaders(
          deviceid: _deviceId, model: _model, osversion: _osVersion)
        ..addAll({
          'user-agent': 'okhttp/4.9.0',
          Config.wmtMfsKey: _wmtMfs ?? '',
        });

      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get wallet balance timeout');
        logger.i('get wallet balance timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');
      return true;
  }

  Future<bool> _saveNotificationToken() async {

    // EasyLoading.show(status: 'loading...');
    logger.i('save notification token start');

    // final String myUid = WaveCrypto.generateRandomUid();
    // final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    // logger.i("--- 生成的随机参数 ---");
    // logger.i("UID    : $myUid");
    // logger.i("IV B64 : $myIvB64");
    // final body = 'msisdn=$_phoneNumber&notificationToken=';
    final body = {
      'msisdn': _phoneNumber,
      'notificationToken': '',
    };
    // logger.i("txt : $txt");

    // String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    // logger.i("cipher : $cipher");

    final url = Uri.https(
        Config.host, 'v2/mfs-customer/save-notification-token');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        // "key": cipher,
        "user-agent": "okhttp/4.9.0",
        // "content-type": "application/json;charset=utf-8",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
    try {
      final response = await Future.any([
        http.post(url, headers: headers, body: body),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('save notification token timeout');
        logger.i('save notification token timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      final resBody = GeneralResponse.fromJson(jsonDecode(response.body));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('save notification token success.');
      logger.i('save notification token success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _getKycInfo() async {

    // EasyLoading.show(status: 'loading...');
    logger.i('get-kyc-info start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    logger.i("cipher : $cipher");

    final url = Uri.https(
        Config.host, 'v3/mfs-customer/get-kyc-info');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "key": cipher,
        "user-agent": "okhttp/4.9.0",
        "Content-Type": "text/plain",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get-kyc-info timeout');
        logger.i('get-kyc-info timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(response.body, myUid, myIvB64);
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('get-kyc-info success.');
      logger.i('get-kyc-info success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _getSubscriberProfile() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('get-subscriber-profile start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    logger.i("cipher : $cipher");

    final url = Uri.https(
        Config.host, 'v3/mfs-customer/get-subscriber-profile');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "key": cipher,
        "user-agent": "okhttp/4.9.0",
        "Content-Type": "text/plain",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('get-subscriber-profile timeout');
        logger.i('get-subscriber-profile timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(response.body, myUid, myIvB64);
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('get-subscriber-profile success.');
      logger.i('get-subscriber-profile success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  Future<bool> _selfAuthoriaztion() async {
    // EasyLoading.show(status: 'loading...');
    logger.i('self-authorization-eligiblity start');

    final String myUid = WaveCrypto.generateRandomUid();
    final String myIvB64 = WaveCrypto.generateRandomIvB64();

    // const myUid = '443b1af1';
    // const myIvB64 = '6z1tByRz2YLkIrdOEPc+zA==';

    // final txt = '$myUid:$myIvB64';

    logger.i("--- 生成的随机参数 ---");
    logger.i("UID    : $myUid");
    logger.i("IV B64 : $myIvB64");
    // logger.i("txt : $txt");

    String cipher = WaveCrypto.encryptKeyHeader(myUid, myIvB64, Config.rsaPublicKey);
    logger.i("cipher : $cipher");

    final url = Uri.https(
        Config.host, 'v3/mfs-customer/self-authorization-eligiblity');
    final headers = Config.getHeaders(
        deviceid: _deviceId, model: _model, osversion: _osVersion)
      ..addAll({
        "key": cipher,
        "user-agent": "okhttp/4.9.0",
        "Content-Type": "text/plain",
        Config.wmtMfsKey: _wmtMfs ?? "",
      });
    try {
      final response = await Future.any([
        http.get(url, headers: headers),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('self-authorization-eligiblity timeout');
        logger.i('self-authorization-eligiblity timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');

      String decryptedBody = WaveCrypto.decryptResponse(response.body, myUid, myIvB64);
      logger.i('decrypted body: $decryptedBody');

      final resBody = GeneralResponse.fromJson(jsonDecode(decryptedBody));
      if (response.statusCode != 200) {
        EasyLoading.showToast(
            resBody.message ?? 'err code: ${response.statusCode}');
        return false;
      }
      // EasyLoading.showInfo('self-authorization-eligiblity success.');
      logger.i('self-authorization-eligiblity success');
      return true;
    } catch (e, stackTrace) {
      logger.e('auth err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
      return false;
    } finally {
      // EasyLoading.dismiss();
    }
  }

  bool _checkInput({bool checkOtp = true}) {
    if (_phoneNumber?.isEmpty ?? true) {
      EasyLoading.showToast('phone number is empty.');
      return false;
    }
    if (_phoneNumber?.startsWith('0') ?? false) {
      EasyLoading.showToast('phone number must remove prefix 0.');
      return false;
    }
    if (_pin?.isEmpty ?? true) {
      EasyLoading.showToast('pin is empty.');
      return false;
    }
    // if (_nrc?.isEmpty ?? true) {
    //   EasyLoading.showToast('nrc is empty.');
    //   return false;
    // }
    if (checkOtp && (_otpCode?.isEmpty ?? true)) {
      EasyLoading.showToast('auth code is empty.');
      return false;
    }
    if (_token?.isEmpty ?? true) {
      EasyLoading.showToast('token is empty.');
      return false;
    }
    if (_remark?.isEmpty ?? true) {
      EasyLoading.showToast('remark is empty.');
      return false;
    }
    return true;
  }

  int? _agentId;

  _paseAgentId(String jsonString) {
    Map<String, dynamic> data = jsonDecode(jsonString);

    logger.i('paseAgent id');
    // 2. 动态访问路径：responseMap -> agentId
    // 注意：根据 JSON 显示 agentId 是数字，所以用 int 接收
    int agentId = data['responseMap']?['agentId'];
    logger.i('agent id: $agentId');

    logger.i('paseAgent id end');
    _agentId = agentId;
  }

  Future<bool> _login() async {
    if (!_checkInput()) return false;

    EasyLoading.show(status: 'loading...');
    try {
      // 验证验证码
      if (!await _confirmAuthCode()) {
        // EasyLoading.showError('confirm auth code fail.');
        return false;
      }

      final token1 = await _generateToken();
      final token2 = await _generateToken();

      if (token1 == null || token2 == null) {
        EasyLoading.showError('get token timeout.');
        return false;
      }

      final password = RSAHelper.encrypt('$_pin:$token1', Config.rsaPublicKey1);
      final pin = RSAHelper.encrypt('$_pin:$token2', Config.rsaPublicKey1);

      // var formData = [
      //   '${Uri.encodeQueryComponent('msisdn')}=${Uri.encodeQueryComponent(_phoneNumber!)}',
      //   '${Uri.encodeQueryComponent('password')}=${Uri.encodeQueryComponent(password)}',
      //   '${Uri.encodeQueryComponent('pin')}=${Uri.encodeQueryComponent(pin)}',
      // ].join('&');
      final formData = {
        'msisdn': _phoneNumber!,
        'password': password,
        'pin': pin,
      };

      logger.i('token1: $token1, token2: $token2');
      logger.i('Phone number: $_phoneNumber');
      logger.i('login wave start');
      logger.i('form data: $formData');

      final url = Uri.https(Config.host, 'v3/mfs-customer/login');
      final headers = Config.getHeaders(
          deviceid: _deviceId, model: _model, osversion: _osVersion)
        ..addAll({
          // 'Content-Type': 'application/x-www-form-urlencoded',
          'user-agent': 'okhttp/4.9.0',
          Config.wmtMfsKey: _wmtMfs ?? '',
        });

      final response = await Future.any([
        http.post(url, headers: headers, body: formData),
        Future.delayed(
            const Duration(seconds: Config.httpRequestTimeoutSeconds)),
      ]);

      if (response is! http.Response) {
        EasyLoading.showError('login timeout');
        logger.i('login timeout');
        return false;
      }

      _wmtMfs = response.headers[Config.wmtMfsKey] ?? _wmtMfs;
      logger.i('Response status: ${response.statusCode}');
      logger.i('Response body: ${response.body}, len: ${response.body.length}');
      logger.i('$Config.wmtMfsKey: ${response.headers[Config.wmtMfsKey]}');
      _paseAgentId(response.body);

      if (response.statusCode != 200) {
        logger.e('login wave err: ${response.statusCode}',
            stackTrace: StackTrace.current);
        EasyLoading.showToast('login err: ${response.statusCode}');
        return false;
      }

      logger.i('login wave success');
      // setState(() => _hasLogin = true);
    } catch (e, stackTrace) {
      logger.e('err: $e', stackTrace: stackTrace);
      EasyLoading.showError('request err, code: $e',
          dismissOnTap: true, duration: const Duration(seconds: 60));
        return false;
    } finally {
      EasyLoading.dismiss();
    }
    return true;
  }
  
  // String jsonData = '''{"responseMap":{"accountStatus":2,"agentId":44961545,"googleUrl":"https://wave.mn/apa","subscriberDetails":{"kycStatus":2,"requireKYCUpgrade":true,"name":"Than Lwin Soe"},"directUrl":"https://wave.mn/apd","interstitialData":{"offerType":1,"imageUri":"https://files.wavemoney.io:8199/splash-screens/splash_screen_apr_2019.jpg","headerName":"Announcement!","messageId":"Message145","offerActionName":"","type":1,"title":"This version will be stopped soon. Please upgrade to new WavePay App to enjoy more features!","messageExpiry":"20200930T13:12:28+0530"},"userType":0,"versionInfo":{"iOS":{"appStoreUrl":"https://itunes.apple.com/us/app/wavepay/id1439175549","forcedUpgrade":"false","build":56,"version":"2.5.0"},"Android":{"forcedUpgrade":"false","playStoreUrl":"https://play.google.com/store/apps/details?id=mm.com.wavemoney.wavepay","directUrl":"https://app.adjust.com/pbka9us?campaign=Media+Link&adgroup=Media+link_WP&redirect=https%3A%2F%2Fwavemoney.com.mm%2Fapp%2Fwavepay-app.apk","versionName":"2.5.0","versionCode":1468}},"versionName":"WavePay","config":{"kycRequiredGroups":"10042"},"versionCode":1411,"waveWorldUrl":"http://wavemoneyworld.com/wavemoneywebtest/firstPage.jsp?username=w@veM0ney&password=wM\$123@67&mobile=9791009038&lang=eng"},"respTime":"Wed Jun 10 08:57:47 MMT 2026","message":"Success","statusCode":0}''';    
  
  void _login1() async {
    if (!_checkInput(checkOtp: false)) return;

    // {
    //   const uid = '3f072763';
    //   const ivB64 = 'qr/cMXr5Ug0R/jWWwqTIMA==';
    //   const cipherB64 = 'H68V0sPFlwqu0i3doU/XYf0xyVin/PlMkGFMn7cv7hWtKvMpY52vsHzwt0SNAZ/2LWVlCYpW3rkMlIM6n2neg5bahd1ZS2bq372SSEiJQnwlXRoevbg2Tqvx3Iit1WhmwP+koRmjNYcJ3oocFI48n4FyuX70XZt2JH7ZXknQvn0=';
    //   final dTxt = WaveCrypto.decryptResponse(cipherB64, uid, ivB64);
    //   final eTxt = WaveCrypto.encryptRequest(dTxt, uid, ivB64);
    //   logger.i('d txt: $dTxt');
    //   logger.i('e txt: $eTxt');
    //   return;
    // }
    // {
    //   paseAgentId(jsonData);
    //   return;
    // }

    try {
      EasyLoading.show(status: 'login...');
      var ret = await _login();
      logger.i('ret: $ret');
      if (!ret) return;

      // {
      //   await _getBalance();
      //   // return;
      // }

      // var ret0 = await _saveNotificationToken();
      // logger.i('ret0: $ret0');
      // if (!ret0) return;

      EasyLoading.show(status: 'get kyc info...');
      var ret1 = await _getKycInfo();
      logger.i('ret1: $ret1');
      if (!ret1) return;

      EasyLoading.show(status: 'get subscriber info...');
      var ret2 = await _getSubscriberProfile();
      logger.i('ret2: $ret2');
      if (!ret2) return;
    
      EasyLoading.show(status: 'get register device...');
      var ret3 = await _registeredDevices();
      logger.i('ret3: $ret3');
      // if (!ret3) return;

    } catch(e) {
      logger.e('e: $e');
    } finally {
      EasyLoading.dismiss();
    }
    

    // var ret4 = await _registeredDevice();
    // logger.i('ret4: $ret4');
    // if (!ret4) return;

    // var ret4 = await _selfAuthoriaztion();
    // logger.i('ret4: $ret4');
    // if (!ret4) return;


    // aesKey = AesKeyGenerator.generateRandomKey1();
    // aesKey = generateSessionKey();

    // await _registeredDevices();

    // EasyLoading.show(status: 'loading...');
    // if (!await _selfAuthoirizedDevice()) return;
    // EasyLoading.dismiss();

    setState(() => _hasLogin = true);
  }

  void _auth() async {
    if (!_checkInput(checkOtp: false)) return;

    try {
      EasyLoading.show(status: 'loading...');
      {
        final host = _platformsResponseData!.url!.replaceAll('http://', '');
        // const path = 'api/pay/payinfo_apply';
        // const path = 'api/pay/tool_apply';
        const path = 'api/pay/purview_apply';
        final url = Uri.http(host, path, {
          'token': _token,
          'phone': _phoneNumber,
          'platform': 'WavePay',
          'remark': _remark,
        });
        logger.i('url: ${url.toString()}');
        logger.i('host: $host, path: $path');
        final response = await Future.any([
          http.post(url),
          Future.delayed(
              const Duration(seconds: Config.httpRequestTimeoutSeconds)),
        ]);

        if (response is! http.Response) {
          EasyLoading.showError('auth timeout');
          logger.i('auth timeout');
          return;
        }

        final body = response.body;
        logger.i('res body: $body');

        final res = ReportGeneralResponse.fromJson(jsonDecode(body));
        if (res.status != 'T') {
          EasyLoading.showError(
              'auth fail. code: ${res.status}, msg: ${res.message}');
          return;
        }
      }
      EasyLoading.show(status: 'wait server auth');
      for (var i = 0; i < 30; ++i) {
        final host = _platformsResponseData!.url!.replaceAll('http://', '');
        // const path = 'api/pay/payinfo_verify';
        // const path = 'api/pay/tool_verify';
        const path = 'api/pay/purview_verify';
        final url = Uri.http(host, path, {
          'token': _token,
          'phone': _phoneNumber,
          'platform': 'WavePay',
        });
        logger.i('url: ${url.toString()}');
        logger.i('host: $host, path: $path');
        final response = await Future.any([
          http.post(url),
          Future.delayed(
              const Duration(seconds: Config.httpRequestTimeoutSeconds)),
        ]);

        if (response is! http.Response) {
          EasyLoading.showError('auth timeout');
          logger.i('auth timeout');
          return;
        }

        final body = response.body;
        logger.i('res body: $body');

        final res = ReportGeneralResponse.fromJson(jsonDecode(body));
        if (res.status == 'T') {
          EasyLoading.showInfo('auth success.');
          break;
        }
        if (res.status == 'F') {
          EasyLoading.showError(
              'auth fail. code: ${res.status}, msg: ${res.message}');
          break;
        }
        if (res.status == 'W') {
          await Future.delayed(const Duration(seconds: 3));
        }
      }
      setState(() => _hasAuth = true);
    } catch (e, stackTrace) {
      logger.e('e: $e', stackTrace: stackTrace);
    } finally {
      EasyLoading.dismiss();
    }
  }

  InputDecoration _buildInputDecoration(String hit, IconData icon) {
    return InputDecoration(
      border: const OutlineInputBorder(),
      prefixIcon: Icon(icon, color: Colors.blue),
      labelText: hit,
      hintText: "Input $hit",
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('auth'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: PlatformSelector(
                platforms: widget.platforms,
                onValueChangedCallback: (platform) =>
                    _platformsResponseData = platform,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _phoneNumber ?? "",
                onChanged: (value) => _phoneNumber = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("phone number", Icons.phone),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
              child: TextFormField(
                controller: TextEditingController()..text = _pin ?? "",
                onChanged: (value) => _pin = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("pin", Icons.password),
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            //   child: TextFormField(
            //     controller: TextEditingController()..text = _wmtMfs ?? "",
            //     onChanged: (value) => _wmtMfs = value,
            //     // validator: _validator,
            //     keyboardType: TextInputType.number,
            //     decoration: _buildInputDecoration("wmtMfs", Icons.perm_identity),
            //   ),
            // ),
            // Padding(
            //   padding: const EdgeInsets.fromLTRB(15, 15, 15, 15),
            //   child: TextFormField(
            //     controller: TextEditingController()..text = _deviceId,
            //     onChanged: (value) => _deviceId = value,
            //     // validator: _validator,
            //     keyboardType: TextInputType.text,
            //     decoration: _buildInputDecoration("device id", Icons.important_devices),
            //   ),
            // ),
            OutlinedButton(
                onPressed: _requestOtp, child: const Text('request otp code.')),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _otpCode ?? "",
                onChanged: (value) => _otpCode = value,
                // validator: _validator,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration("otp code", Icons.security),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 15, 15, 0),
              child: TextFormField(
                controller: TextEditingController()..text = _remark ?? "",
                onChanged: (value) => _remark = value,
                // validator: _validator,
                keyboardType: TextInputType.text,
                decoration: _buildInputDecoration("remark", Icons.tag),
              ),
            ),
            const Padding(padding: EdgeInsets.only(bottom: 15)),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: _hasLogin ? null : _login1,
                  child: Text(_hasLogin ? 'logined wave' : 'login wave'),
                ),
                const Padding(padding: EdgeInsets.only(left: 15, right: 15)),
                OutlinedButton(
                  onPressed: _hasAuth ? null : _auth,
                  child: Text(_hasAuth ? 'login report' : 'login report'),
                ),
                const Spacer(),
              ],
            ),
            const Padding(padding: EdgeInsets.fromLTRB(0, 15, 0, 0)),
            OutlinedButton(
              onPressed: (!_hasAuth || !_hasLogin)
                  ? null
                  : () async {
                      if (!context.mounted) return;
                      if (!_checkInput()) return;
                      Navigator.pop(
                        context,
                        AccountData(
                          token: _token!,
                          remark: _remark!,
                          platformName: _platformsResponseData!.name!,
                          platformUrl: _platformsResponseData!.url!,
                          platformKey: _platformsResponseData!.key!,
                          platformMark: _platformsResponseData!.mark!,
                          phoneNumber: _phoneNumber!,
                          pin: _pin!,
                          authCode: _otpCode ?? '000000',
                          wmtMfs: _wmtMfs!,
                          isWmtMfsInvalid: false,
                          deviceId: _deviceId,
                          model: _model,
                          osVersion: _osVersion,
                        ),
                      );
                    },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }
}
