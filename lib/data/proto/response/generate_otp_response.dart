class GeneralResponse {
  String? message;
  String? statusCode;
  String? respTime;
  bool? releaseTest;
  ResponseMap? responseMap;

  GeneralResponse(
      {this.message,
      this.statusCode,
      this.respTime,
      this.releaseTest,
      this.responseMap});

  GeneralResponse.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    statusCode = json['statusCode'];
    respTime = json['respTime'];
    releaseTest = json['releaseTest'];
    responseMap = json['responseMap'] != null
        ? ResponseMap.fromJson(json['responseMap'])
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message'] = message;
    data['statusCode'] = statusCode;
    data['respTime'] = respTime;
    data['releaseTest'] = releaseTest;
    if (responseMap != null) {
      data['responseMap'] = responseMap!.toJson();
    }
    return data;
  }
}

class ResponseMap {
  String? securityCounter;

  ResponseMap({this.securityCounter});

  ResponseMap.fromJson(Map<String, dynamic> json) {
    securityCounter = json['securityCounter'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['securityCounter'] = securityCounter;
    return data;
  }
}
