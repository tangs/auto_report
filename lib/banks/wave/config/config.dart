import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class Config {
  static const wmtMfsKey = 'wmt-mfs';

  static const rsaPublicKey = '''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4fV3EhdFo6O6ujXcji4y
6GmhX8eXP6Of0SJSVp4AVQXj9Bbb5UKW0smu/wVhqBOSBpF9dfaJcCAhXOr9XDm5
aGZVEMQIJ1UM89MgYcvZ11zQ6z8mbq775X/8TUPun1L2Z+2oIc6fu5v0VKfjFo1J
2tuK+abF9C7EOcWClyAZFpo2GB+AYk3AcGTLJ8PcbH5A8KZesBVIitYb1uSASREJ
mvbeBSOyITpnLppXOui6RIba7Kc5KPvSJxJ270+SJxrg2t6CehoDAx1JW17q1VfC
OMVWewfwge8EkQ0DVwNy7p5z6a+1BoIEdweJn83/XluyMx6sWlbnwIJvc0i6vPTX
lwIDAQAB
-----END PUBLIC KEY-----''';

  static const rsaPrivateKeyReport = '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC9IDr3Dq0WGVtE
UXEp7HQiJ4pIKZYncTZyayCAz+c9M3v6iKGU9Ag9E6nizQW5mCybOMmZsI1pkrRT
s7lqyE0+7TsFvKwganBr2RIxV8spr8yA5lF/mzml6/KpNk1Y5UonyAvjTzKZ32Gp
RD/tFSWeacyliUwrztoG6JtKuqUUEcZyssvVDyzQ6y1ewyh5nymBiSNjhe6m2h2x
gEfbMLuE1SQwXxFSAZ86SuiQ2WqCCnqUAmXWuJhtwZoPZyZ+OXdMYiAGOc/x4uqj
wn9huEsi0Getj7w1MbgR5vjQ9I+lRsNCeI+Xq4QPSLc34Xj6vp9WQnddrkNVXLa6
XLpBBHlrAgMBAAECggEAZxAjUfMbe8mBpO9E3fXPK7Wkc8LF4uSdKSkb41Zoyz89
NsAyXbvGqZIHqGLV1dgJpuUBZ9GAnqGlx19PkdNp1PruiSfSHTAj54G5mk4flq4I
oc3hZ8qtVbAI4xGGgQUirh8j61GDX7sNu3JH6+j0QSmirirt6Yml4tHrnoOr5g0A
KxrkzvRUv1f2xSFZf5vZGeGxjAQnaxtZEnPvgYed6u/3otnhrxhv1nSLyTHuxLVu
0lQdqBh/Mqcm9nF2YHi3ncJkjDMksvK5H//7z4a70xEfBGrGfr2zHSj2oMIu+s0k
1UoK9asR83N5810U7Z2FL1V7A55UzNyHqnVol2VJoQKBgQD4LgwCw87Y2JajUQs9
oI6w+zF9q7kjlS0m86VCPgbH+Mr793VzwZamREIbnfDwDlTm8d1ES/51ApODxcFY
zPBtrYCyhuyAgiGV87QxnGokoxHs7UCHmdgDOm9N4KtVHjW9Rn+eu0r9jN7yBn19
4/MTQMYnjjtFLMtf2Phd0cHtqQKBgQDDFdJ32rkN+BiDXXgpAJ9TOWFiujXo4Q5v
DT3iUn5LcBIcC4rOkoKT0Dov0AQaskygF9onO1jQxu28KNCenPo+4+UCcfxnuKTm
2oLxm3uhEv9zPg2Ny5cNO2O99vJPheAuz3eDPBIGCi4mkneiL5CQDIVP9c2QvJfJ
bukTyaoS8wKBgQDluvIhSRHbBrqCWQ3XsR0E1LEeTGxndLpEGTs7k2EBkNqM3Kcb
TPLf28V5/Py/qfSLhw20H8heldDpJJByW9qfHAFKwLyBxHPEc7+0QL68RTrdn0yh
eRZM/rVzWGogs4M5Pt35mBO1msXxMXLOqsgiZU5H5VAWG33yrkxRxE4IaQKBgGw3
NLLrj2+iSebE+Jy2Datazxy28qSmAx2zGLrsy8YI+uK3vF3ug6R/A2f2WfB9K2g7
EvZkQ1Y8oy+W7HKv3Vj5jdWXaU4X7NFqMOzZNPEa2r0QlPAtGTNr2F5OGAfo2Xzd
9QvFTLIw/3zCDr7W57ggWesLDObW1tQURBKH8WHlAoGBAOIfiU9oQw6YFFA2BqFE
rexBA28esJk2izcC8Zq9bpyfAroJPP2jft92acQPFthiGuTX+MHdD3oWgQVaXr8X
XeWHIoNO3bAAtfcraFezeS96iaISm4VkuEVhmOFzmRw81UWmdqi4UYZzONGE8rwS
T7hZ/lF1fzZwYxAoQA/hpBT4
-----END PRIVATE KEY-----''';

//   static const rsaPublicKey = '''-----BEGIN PUBLIC KEY-----
// MIIBITANBgkqhkiG9w0BAQEFAAOCAQ4AMIIBCQKCAQBazNxhXGg6+Uz2WdJnZlK0
// kDEJcuNHFy6HXTAyES2waQhEkO0vs6T2sFo/yi2e+qI+KpMc66xz4AW1TK4aBg9E
// ulIwXu/ZaP1vQmz68+E1Xh/vds3twx7Ivun/cjtdW6g5xYKSJE0WhDuS88m1PAkN
// I8gFPGIQBXnK3czG28cLBgPOknB8hyhmldLiMNg9zctNmNEGAj7k5HtCkaVqnWpn
// b7BLk1itqph4Wuq8y3brNMJdLIf7Bt0oLmKm/eXXBJwHFzuVctXQOJracfBxAMMM
// azlsQ1E6Crew2pNiWBbgSpCe8nt19JykEZk+0n4WJZBPCwS9tCN+JaIRCEUXW9Gv
// AgMBAAE=
// -----END PUBLIC KEY-----''';

  static const rsaPrivateKey =
      '''MIIEoQIBAAKCAQBazNxhXGg6+Uz2WdJnZlK0kDEJcuNHFy6HXTAyES2waQhEkO0v
s6T2sFo/yi2e+qI+KpMc66xz4AW1TK4aBg9EulIwXu/ZaP1vQmz68+E1Xh/vds3t
wx7Ivun/cjtdW6g5xYKSJE0WhDuS88m1PAkNI8gFPGIQBXnK3czG28cLBgPOknB8
hyhmldLiMNg9zctNmNEGAj7k5HtCkaVqnWpnb7BLk1itqph4Wuq8y3brNMJdLIf7
Bt0oLmKm/eXXBJwHFzuVctXQOJracfBxAMMMazlsQ1E6Crew2pNiWBbgSpCe8nt1
9JykEZk+0n4WJZBPCwS9tCN+JaIRCEUXW9GvAgMBAAECggEAI+3+orQbNoLh1nWy
kWHnBjYsgU2p676blcrlQFqV1sGpGOC0SnTuqQMdozJQnSEWRD06m24SfoO+HoCq
P/f34L1NuoBGrqQh7P2+/Aq3KhQF1Q8Q662TJ+KL254LKaUUS1ABm+yraGaI4FyB
i6qm9kEbbB75utc/22urFWFwQMb1LBaUAdelvFibiGatK8iIt4fPJb5YqzIgUPVK
qZMXo/25xxtpd96gCpeIIwX5qYgFLKog3oA7cwLxEvlhVuD4SyGawhXuuPvk53cQ
Fr/+bKbRIVNzhyNYd1c8h93c4yvCoicA/1z5J/8zZLjnyy7oPVyEa4tXu0CrywS3
nNsjAQKBgQC0TSxc0i/BINTF5GORU8XT5jUTUEnbW/MzbQ1AEekSqJr2zp8UJCW4
9ul8Mo7N7iGc9uU73IzXT0CThM55HtsPZ/cZDDqcM128xg5lqCQdEWFQhFmkABfZ
0/dPRHeqqI9K1mGeexlan9UUWX947LL1WOmoRhJYyRqzkuhxPPPUgQKBgQCA7BVg
J/2ObFvHfs1AagTryMwbURMTNty7lmbu1Fk8V1BWw5Lb6k8fhVEk/bvFE//wWkqZ
W6jnTWFYaylUsHqpl/1HhyZPXFQAvsDLKLvnDsKAN10OqbxhHl50d3yxROdZ5xKa
o6Gh3DGWYQ/PLFzdKF6HGiP3PfAest+CBZjOLwKBgH3vqZzr8w8ir3vKGwHXUcbA
dTIYUn41q5mwAiFOYU33FsZtbA/Vb8PSMyPc7IJKYpAQo+08D+QUJzbi/JT9SGVq
aN3F/Oo9tqu0azn2R8NF8IMc7r/ukLpFo+hqGmvJcM0FEQpxUTRLj7m3CaKdMiLN
B+fRid8aGNx1MIZn3KgBAoGAAQbgXLW01U+To5Ek/WBaza35wjXxGvQS6gOWqkxS
saJYZ3iDUPEa1DtxnAPRXQ59uWJeub37KGx7XALuf1gwge1N/SXcbkFkAeWDD5sx
c/OwJOlL+nPrpjJhujfBbIAJ/7NReJ3ZCbsBQhtfztyhmLlbl2Pj6XI62WO/V//H
ac0CgYBh/s3Tpgjk6pxYjBX5Bp0R6fK/TCtKmsyK7+SJBo3rmJqRQJFx8x0n2lbm
OhBZ49phSuEYGAq5+oAy8ZGBMtGGJBBU2vwWhjyI1Hz7rXSgWzwUegCJAC5WG4o5
w8UsJovG2xCw3FHr3Qzl1XRMb19BwYflGgikMbIfAsWhRHC1Gg==''';

  static const host = 'api.wavemoney.io:8100';

  static const fingerprint =
      '87EC104C0FFBB8E749CD59D9C64851441B38D1C13C9746DC124BB9E71E66DCB9';
  static const appid = 'mm.com.wavemoney.wavepay';
  static const userlanguage = 'en';
  static const acceptEncoding = 'gzip, deflate, br';
  static const versioncode = '1460';
  static const appversion = '2.2.0';

  // static const deviceid = 'fd701ebde3dcc9342ab647f5b5800f76ba3a7b5d';
  static const device = '';
  static var product = 'redfin';
  static var cpuabi = 'arm64-v8a,armeabi-v7a,armeabi';
  static var manufacturer = 'Google';
  // static const model = 'Pixel 5';
  // static const osversion = '11';

  static const httpRequestTimeoutSeconds = 60;
  static const logCountMax = 1024;

  static init() async {
    if (!Platform.isAndroid) return;

    EasyLoading.show();
    final deviceInfoPlugin = await DeviceInfoPlugin().androidInfo;
    Config.product = deviceInfoPlugin.product;
    Config.cpuabi = deviceInfoPlugin.supportedAbis.join(',');
    Config.manufacturer = deviceInfoPlugin.manufacturer;
    EasyLoading.dismiss();
  }

  static Map<String, String> getHeaders(
      {required String deviceid,
      required String model,
      required String osversion}) {
    return {
      "fingerprint": fingerprint,
      "appid": appid,
      "userlanguage": userlanguage,
      "accept-encoding": acceptEncoding,
      "versioncode": versioncode,
      "appversion": appversion,
      // "user-agent": "okhttp/4.9.0",
      "deviceid": deviceid, // 随机生成40位的uuid,用于确定是否当前登录设备
      "device": device, // 设备驱动名称
      "product": product, // 产品的名称
      "cpuabi": cpuabi, // 设备指令集名称（CPU的类型）
      "manufacturer": manufacturer, // 设备制造商
      "model": model, // 手机的型号 设备名称
      "osversion": osversion, // OS系统版本
    };
  }
}
