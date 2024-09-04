import 'dart:math';

import 'package:auto_report/banks/kbiz/data/bank/get_account_summary_list_response.dart';
import 'package:auto_report/banks/kbiz/data/bank/validate_session_response.dart';
import 'package:auto_report/utils/log_helper.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class Sender {
  final dio = Dio();

  String? _token;
  String? _sessionToken;
  String? _dataRsso;
  String? _account;
  String? _password;

  ValidateSessionResponse? _validateSessionResponse;

  Sender() {
    final cookieJar = CookieJar();
    dio.interceptors.add(CookieManager(cookieJar));
  }

  init() async {
    final res =
        await dio.get('https://kbiz.kasikornbank.com/authen/login.jsp?lang=en');
    final body = res.data.toString();

    // logger.i('res: $body');

    final tokenRe = RegExp(r'id="tokenId"\svalue="([^"]*)"');
    final ret = tokenRe.firstMatch(body);
    assert(ret != null);
    final token = ret!.group(1);
    _token = token;

    logger.i('token: $token');

    await dio.get(
      'https://kbiz.kasikornbank.com/android-icon-144x144.png',
      options: Options(headers: {
        'Accept':
            'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
      }),
    );

    // logger.i('res1: $res1');

    // final res2 = await dio.post(
    //   'https://kbiz.kasikornbank.com/authen/login.do',
    //   data: FormData.fromMap({
    //     'userName': 'Suminta41',
    //     'password': 'May88990#',
    //     'tokenId': token!,
    //     'cmd': 'authenticate',
    //     'locale': 'en',
    //     'custType': '',
    //     'captcha': '',
    //     'app': '0',
    //   }),
    //   options: Options(headers: {
    //     'Content-Type': 'application/x-www-form-urlencoded',
    //     'Accept': '*/*',
    //     'User-Agent':
    //         'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
    //   }),
    // );

    // logger.i('res2: $res2');

    // final loginResult =
    //     res2.data.toString().contains('authen/ib/redirectToIB.jsp');
    // logger.i('login result: $loginResult');

    // final a = 3;
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

  Future<bool> login(String account, String password) async {
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

  Future<bool> redirectToIB() async {
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

  Future<bool> validateSession() async {
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

  Future<bool> getAccountSummaryList() async {
    final userProfile = _validateSessionResponse?.data?.userProfiles?.first;
    if (userProfile == null) {
      logger.e('user profile is null, accout: $_account');
      return false;
    }

    final requestId = _genRequestId();
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
      options: Options(headers: {
        'x-session-ibid': userProfile.ibId!,
        'x-ib-id': userProfile.ibId!,
        'x-url': 'https://kbiz.kasikornbank.com/menu/account/account-summary',
        'x-request-id': requestId,
        'x-re-fresh': 'N',
        'x-verify': 'Y',
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/json',
        'Referer': 'https://kbiz.kasikornbank.com/menu/account/account-summary',
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko)',
        'authorization': _sessionToken,
      }),
    );

    final resData = res.data;

    final summaryResponse = GetAccountSummaryListResponse.fromJson(resData);

    logger.i('get account summary list res: ${res.toString()}');

    logger.i('balance: ${summaryResponse.data!.availableBalanceSum}');

    return true;
  }

  static void test() async {
    try {
      EasyLoading.show();
      final sender = Sender();
      await sender.init();
      final ret = await sender.login('Suminta41', 'May88990#');
      logger.i('loggin ret: $ret');
      if (!ret) return;

      final redirectToIBRet = await sender.redirectToIB();
      logger.i('redirect to ib ret: $redirectToIBRet');
      if (!redirectToIBRet) return;

      final validateSessionRet = await sender.validateSession();
      logger.i('validate session ret: $validateSessionRet');
      if (!validateSessionRet) return;

      final accountSummaryListRet = await sender.getAccountSummaryList();
      logger.i('account summary list ret: $accountSummaryListRet');
      if (!accountSummaryListRet) return;
    } catch (e, stack) {
      logger.e(e, stackTrace: stack);
    } finally {
      EasyLoading.dismiss();
    }
  }
}
