import 'dart:math';

import 'package:auto_report/banks/kbiz/data/bank/get_account_summary_list_response.dart';
import 'package:auto_report/banks/kbiz/data/bank/get_blacklist_flag.dart';
import 'package:auto_report/banks/kbiz/data/bank/recent_transaction_response.dart';
import 'package:auto_report/banks/kbiz/data/bank/validate_session_response.dart';
import 'package:auto_report/config/global_config.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class BankSender {
  final dio = Dio(
    BaseOptions(
      connectTimeout:
          const Duration(seconds: GlobalConfig.httpRequestTimeoutSeconds),
      sendTimeout:
          const Duration(seconds: GlobalConfig.httpRequestTimeoutSeconds),
      receiveTimeout:
          const Duration(seconds: GlobalConfig.httpRequestTimeoutSeconds),
    ),
  );

  String? _account;
  String? _password;

  String? _token;
  String? _sessionToken;
  String? _dataRsso;

  // todo
  bool _isInvalid = false;
  bool _isLogin = false;

  ValidateSessionResponse? _validateSessionResponse;
  GetAccountSummaryListResponse? _accountSummaryListResponse;

  BankSender({String? account, String? password}) {
    _account = account;
    _password = _password;

    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  get isInvalid => _isInvalid;
  get isLogin => _isLogin;
  get isNormalState => !_isInvalid && isLogin;

  Future<bool> getIcon() async {
    await dio.get(
      'https://kbiz.kasikornbank.com/android-icon-144x144.png',
      options: Options(headers: {
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      }),
    );
    return true;
  }

  String _genRequestId() {
    final now = DateTime.now();

    // 获取各个时间分量
    final year = now.year;
    final month = now.month;
    final day = now.day;
    final hour = now.hour;
    final minute = now.minute;
    final second = now.second;
    final millisecond = now.millisecond;

    // 构造格式化的时间字符串
    final timeStr = '${year.toString().padLeft(4, '0')}'
        '${month.toString().padLeft(2, '0')}'
        '${day.toString().padLeft(2, '0')}'
        '${hour.toString().padLeft(2, '0')}'
        '${minute.toString().padLeft(2, '0')}'
        '${second.toString().padLeft(2, '0')}'
        '${millisecond.toString().padLeft(3, '0')}';

    // 生成随机数
    final random = Random();
    final randomNumber = random.nextInt(900) + 100;

    // 最终结果
    final result = timeStr + randomNumber.toString().padLeft(3, '0');
    return result;
  }

  ValidateSessionResponseDataUserProfiles? _getUserProfile() {
    final userProfile = _validateSessionResponse?.data?.userProfiles?.first;
    if (userProfile == null) {
      logger.e('user profile is null, accout: $_account');
      return null;
    }
    return userProfile;
  }

  Map<String, dynamic>? _getHeader({
    required String referer,
    required String url,
  }) {
    final userProfile = _getUserProfile()!;

    final ibId = userProfile.ibId!;
    final requestId = _genRequestId();

    return {
      'x-session-ibid': ibId,
      'x-ib-id': ibId,
      'x-url': url,
      'x-request-id': requestId,
      'x-re-fresh': 'N',
      'x-verify': 'Y',
      'Accept': 'application/json, text/plain, */*',
      'Content-Type': 'application/json',
      'Referer': referer,
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      'authorization': _sessionToken,
    };
  }

  Future<bool> _getToken() async {
    final res =
        await dio.get('https://kbiz.kasikornbank.com/authen/login.jsp?lang=en');
    final body = res.data.toString();
    final tokenRe = RegExp(r'id="tokenId"\svalue="([^"]*)"');
    final ret = tokenRe.firstMatch(body);
    assert(ret != null);
    final token = ret!.group(1);
    _token = token;

    logger.i('token: $token');
    return true;
  }

  Future<bool> _login(String account, String password) async {
    final res = await dio.post(
      'https://kbiz.kasikornbank.com/authen/login.do',
      data: FormData.fromMap({
        'userName': account,
        'password': password,
        'tokenId': _token!,
        'cmd': 'authenticate',
        'locale': 'en',
        'custType': '',
        'captcha': '',
        'app': '0',
      }),
      options: Options(headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': '*/*',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      }),
    );

    // logger.i('login res: $res');
    _account = account;
    _password = password;

    final loginResult =
        res.data.toString().contains('authen/ib/redirectToIB.jsp');
    return loginResult;
  }

  Future<bool> _redirectToIB() async {
    final res = await dio.get(
      'https://kbiz.kasikornbank.com/authen/ib/redirectToIB.jsp',
      options: Options(headers: {
        'referer': 'https://kbiz.kasikornbank.com/authen/login.do',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      }),
    );

    // logger.i('redirect to ib res: $res');

    final re = RegExp(r'href = "([^="]*)=([^="]*)"');

    final responseData = res.data.toString();

    final matchRet = re.firstMatch(responseData);
    logger.i('match ret: $matchRet');
    if (matchRet == null) return false;

    final dataRsso = matchRet.group(2);
    assert(dataRsso?.isNotEmpty ?? false);

    _dataRsso = dataRsso;

    logger.i('dataRsso: $dataRsso');

    await dio.get(
      'https://kbiz.kasikornbank.com/login?dataRsso=$_dataRsso',
      options: Options(headers: {
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'referer': 'https://kbiz.kasikornbank.com/authen/ib/redirectToIB.jsp',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
        'Content-Type': 'text/html',
      }),
    );

    // logger.i('res1: $res1');

    return true;
  }

  Future<bool> _validateSession() async {
    final requestId = _genRequestId();
    final res = await dio.post(
      'https://kbiz.kasikornbank.com/services/api/authentication/validateSession',
      data: {
        'dataRsso': _dataRsso,
      },
      options: Options(headers: {
        'x-request-id': requestId,
        'Content-Type': 'application/json',
        'Referer': 'https://kbiz.kasikornbank.com/login?dataRsso=$_dataRsso',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      }),
    );

    final resData = res.data;

    _validateSessionResponse = ValidateSessionResponse.fromJson(resData);

    if (_validateSessionResponse?.data?.userProfiles?.isEmpty ?? true) {
      logger.e('must contains user profile: $_account');
      return false;
    }

    _sessionToken = res.headers.value('x-session-token');
    logger.i('x-session-token: $_sessionToken');

    return true;
  }

  /// return: 余额
  Future<double?> _getBalance() async {
    if (!isNormalState) {
      final ret = await fullLogin(_account!, _password!);
      if (!ret) return null;
    }

    try {
      final userProfile = _getUserProfile()!;
      const url = 'https://kbiz.kasikornbank.com/menu/account/account-summary';

      final res = await dio.post(
        'https://kbiz.kasikornbank.com/services/api/accountsummary/getAccountSummaryList',
        data: {
          'custType': userProfile.custType!,
          'isReload': 'N',
          'lang': 'en',
          'nicknameType': 'OWNAC',
          'ownerId': userProfile.companyId!,
          'ownerType': 'Company',
          'pageAmount': '6',
        },
        options: Options(headers: _getHeader(referer: url, url: url)),
      );

      final resData = res.data;
      final summaryResponse = GetAccountSummaryListResponse.fromJson(resData);
      assert(summaryResponse.data?.accountSummaryList?.isNotEmpty ?? false);
      _accountSummaryListResponse = summaryResponse;

      final balance = summaryResponse.data!.availableBalanceSum;

      logger.i('get account summary list res: ${res.toString()}');
      logger.i('balance: $balance');

      if (balance?.isEmpty ?? true) return null;
      return double.parse(balance!);
    } catch (e, stackTrace) {
      Logger().e('err: $e', stackTrace: stackTrace);
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          _isInvalid = true;
        }
      }
    }
    return null;
  }

  Future<double?> getBalance() async {
    return await _getBalance() ?? await _getBalance();
  }

  /// return: 是否成功
  Future<bool> getBlackListFlag() async {
    const url =
        'https://kbiz.kasikornbank.com/menu/account/account/recent-transaction';

    final res = await dio.post(
      'https://kbiz.kasikornbank.com/services/api/configuration/getBlacklistFlag',
      options: Options(headers: _getHeader(referer: url, url: url)),
      data: {},
    );

    logger.i('get black list flag: ${res.toString()}');

    final resData = res.data;
    final getBlacklistFlag = GetBlacklistFlag.fromJson(resData);

    return getBlacklistFlag.status?.contains('S') ?? false;
  }

  Future<bool> getRecentTransactionList() async {
    final acountSummary =
        _accountSummaryListResponse!.data!.accountSummaryList!.first!;
    final userProfile = _getUserProfile()!;
    const url =
        'https://kbiz.kasikornbank.com/menu/account/account/recent-transaction';

    final formatter = DateFormat('dd/MM/yyyy');
    final nowDate =
        formatter.format(DateTime.now().subtract(const Duration(hours: 1)));
    final endDate = formatter.format(DateTime.now());

    final res = await dio.post(
      'https://kbiz.kasikornbank.com/services/api/accountsummary/getRecentTransactionList',
      options: Options(headers: _getHeader(referer: url, url: url)),
      data: {
        'acctNo': acountSummary.accountNo!,
        'acctType': acountSummary.accountType!,
        'custType': userProfile.custType!,
        'ownerId': userProfile.companyId!,
        'ownerType': 'Company',
        'pageNo': '1',
        'refKey': '',
        'rowPerPage': '20',
        'startDate': nowDate,
        'endDate': endDate,
      },
    );

    logger.i('get recent transations: ${res.toString()}');

    final resData = res.data;
    final recentTransactionResponse =
        RecentTransactionResponse.fromJson(resData);

    // return getBlacklistFlag.status?.contains('S') ?? false;
    return recentTransactionResponse.status == 'S';
  }

  Future<bool> fullLogin(String account, String password) async {
    Logger().i('start full login.');
    {
      final ret = await _getToken();
      logger.i('get token ret: $ret');
      if (!ret) return false;
    }

    {
      final ret = await _login(account, password);
      logger.i('loggin ret: $ret');
      if (!ret) return false;
    }

    {
      final ret = await _redirectToIB();
      logger.i('redirect to ib ret: $ret');
      if (!ret) return false;
    }

    {
      final ret = await _validateSession();
      logger.i('validate session ret: $ret');
      if (!ret) return false;
    }

    // {
    //   final ret = await getBalance();
    //   logger.i('get balance: $ret');
    //   if (ret == null) return false;
    // }

    // {
    //   final ret = await getBlackListFlag();
    //   logger.i('get black list ret: $ret');
    //   if (!ret) return false;
    // }

    _isLogin = true;
    _isInvalid = false;

    return true;
  }

  static Future<bool> test() async {
    try {
      EasyLoading.show();
      final sender = BankSender();

      {
        final ret = await sender._getToken();
        logger.i('get token ret: $ret');
        if (!ret) return false;
      }

      {
        final ret = await sender._login('Suminta41', 'May88990#');
        logger.i('loggin ret: $ret');
        if (!ret) return false;
      }

      {
        final ret = await sender._redirectToIB();
        logger.i('redirect to ib ret: $ret');
        if (!ret) return false;
      }

      {
        final ret = await sender._validateSession();
        logger.i('validate session ret: $ret');
        if (!ret) return false;
      }

      {
        final ret = await sender.getBalance();
        logger.i('get balance: $ret');
        if (ret == null) return false;
      }

      {
        final ret = await sender.getBlackListFlag();
        logger.i('get black list ret: $ret');
        if (!ret) return false;
      }

      {
        final ret = await sender.getRecentTransactionList();
        logger.i('get recent transactions ret: $ret');
        if (!ret) return false;
      }
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    } finally {
      EasyLoading.dismiss();
    }

    return true;
  }
}
