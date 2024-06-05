class Config {
  static const rsaPublicKey = "-----BEGIN PUBLIC KEY-----" +
      "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4fV3EhdFo6O6ujXcji4y" +
      "6GmhX8eXP6Of0SJSVp4AVQXj9Bbb5UKW0smu/wVhqBOSBpF9dfaJcCAhXOr9XDm5" +
      "aGZVEMQIJ1UM89MgYcvZ11zQ6z8mbq775X/8TUPun1L2Z+2oIc6fu5v0VKfjFo1J" +
      "2tuK+abF9C7EOcWClyAZFpo2GB+AYk3AcGTLJ8PcbH5A8KZesBVIitYb1uSASREJ" +
      "mvbeBSOyITpnLppXOui6RIba7Kc5KPvSJxJ270+SJxrg2t6CehoDAx1JW17q1VfC" +
      "OMVWewfwge8EkQ0DVwNy7p5z6a+1BoIEdweJn83/XluyMx6sWlbnwIJvc0i6vPTX" +
      "lwIDAQAB" +
      "-----END PUBLIC KEY-----";

  static const host = 'api.wavemoney.io:8100';

  static const fingerprint =
      '87EC104C0FFBB8E749CD59D9C64851441B38D1C13C9746DC124BB9E71E66DCB9';
  static const appid = 'mm.com.wavemoney.wavepay';
  static const userlanguage = 'en';
  static const acceptEncoding = 'gzip, deflate, br';
  static const versioncode = '1460';
  static const appversion = '2.2.0';

  static const deviceid = 'fd701ebcc3dcc6342ab647f5b9800f76ba3a7b5a';
  static const device = 'redfin';
  static const product = 'redfin';
  static const cpuabi = 'arm64-v8a,armeabi-v7a,armeabi';
  static const manufacturer = 'Google';
  static const model = 'Pixel 6';
  static const osversion = '12';

  static Map<String, String> getHeaders() {
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
