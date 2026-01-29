// ignore_for_file: non_constant_identifier_names

class GeneralResqonseResponseBodyResponseDetailNewResultInfo {
/*
{} 
*/

  GeneralResqonseResponseBodyResponseDetailNewResultInfo();
  GeneralResqonseResponseBodyResponseDetailNewResultInfo.fromJson(
      Map<String, dynamic> json);
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    return data;
  }
}

class GeneralResqonseResponseBodyResponseDetail {
/*
{
  "newResultInfo": {},
  "ServerTimestamp": 1720677001709,
  "ResultDesc": "Process service request successfully.",
  "ResultCode": "0"
} 
*/

  GeneralResqonseResponseBodyResponseDetailNewResultInfo? newResultInfo;
  int? ServerTimestamp;
  String? ResultDesc;
  String? ResultCode;

  GeneralResqonseResponseBodyResponseDetail({
    this.newResultInfo,
    this.ServerTimestamp,
    this.ResultDesc,
    this.ResultCode,
  });

  GeneralResqonseResponseBodyResponseDetail.fromJson(
      Map<String, dynamic> json) {
    newResultInfo = (json['newResultInfo'] != null)
        ? GeneralResqonseResponseBodyResponseDetailNewResultInfo.fromJson(
            json['newResultInfo'])
        : null;
    ServerTimestamp = json['ServerTimestamp']?.toInt();
    ResultDesc = json['ResultDesc']?.toString();
    ResultCode = json['ResultCode']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (newResultInfo != null) {
      data['newResultInfo'] = newResultInfo!.toJson();
    }
    data['ServerTimestamp'] = ServerTimestamp;
    data['ResultDesc'] = ResultDesc;
    data['ResultCode'] = ResultCode;
    return data;
  }
}

class GeneralResqonseResponseBody {
/*
{
  "ResponseCode": "0",
  "ResponseDesc": "Accept the service request successfully.",
  "ResponseDetail": {
    "newResultInfo": {},
    "ServerTimestamp": 1720677001709,
    "ResultDesc": "Process service request successfully.",
    "ResultCode": "0"
  }
} 
*/

  String? ResponseCode;
  String? ResponseDesc;
  GeneralResqonseResponseBodyResponseDetail? ResponseDetail;

  GeneralResqonseResponseBody({
    this.ResponseCode,
    this.ResponseDesc,
    this.ResponseDetail,
  });
  GeneralResqonseResponseBody.fromJson(Map<String, dynamic> json) {
    ResponseCode = json['ResponseCode']?.toString();
    ResponseDesc = json['ResponseDesc']?.toString();
    ResponseDetail = (json['ResponseDetail'] != null)
        ? GeneralResqonseResponseBodyResponseDetail.fromJson(
            json['ResponseDetail'])
        : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['ResponseCode'] = ResponseCode;
    data['ResponseDesc'] = ResponseDesc;
    if (ResponseDetail != null) {
      data['ResponseDetail'] = ResponseDetail!.toJson();
    }
    return data;
  }
}

class GeneralResqonseResponseHeader {
/*
{
  "Version": "1460",
  "ConversationID": ""
} 
*/

  String? Version;
  String? ConversationID;

  GeneralResqonseResponseHeader({
    this.Version,
    this.ConversationID,
  });
  GeneralResqonseResponseHeader.fromJson(Map<String, dynamic> json) {
    Version = json['Version']?.toString();
    ConversationID = json['ConversationID']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['Version'] = Version;
    data['ConversationID'] = ConversationID;
    return data;
  }
}

class GeneralResqonseResponse {
/*
{
  "Header": {
    "Version": "1460",
    "ConversationID": ""
  },
  "Body": {
    "ResponseCode": "0",
    "ResponseDesc": "Accept the service request successfully.",
    "ResponseDetail": {
      "newResultInfo": {},
      "ServerTimestamp": 1720677001709,
      "ResultDesc": "Process service request successfully.",
      "ResultCode": "0"
    }
  }
} 
*/

  GeneralResqonseResponseHeader? Header;
  GeneralResqonseResponseBody? Body;

  GeneralResqonseResponse({
    this.Header,
    this.Body,
  });
  GeneralResqonseResponse.fromJson(Map<String, dynamic> json) {
    Header = (json['Header'] != null)
        ? GeneralResqonseResponseHeader.fromJson(json['Header'])
        : null;
    Body = (json['Body'] != null)
        ? GeneralResqonseResponseBody.fromJson(json['Body'])
        : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (Header != null) {
      data['Header'] = Header!.toJson();
    }
    if (Body != null) {
      data['Body'] = Body!.toJson();
    }
    return data;
  }
}

class GeneralResqonse {
/*
{
  "Response": {
    "Header": {
      "Version": "1460",
      "ConversationID": ""
    },
    "Body": {
      "ResponseCode": "0",
      "ResponseDesc": "Accept the service request successfully.",
      "ResponseDetail": {
        "newResultInfo": {},
        "ServerTimestamp": 1720677001709,
        "ResultDesc": "Process service request successfully.",
        "ResultCode": "0"
      }
    }
  }
} 
*/

  GeneralResqonseResponse? Response;

  GeneralResqonse({
    this.Response,
  });
  GeneralResqonse.fromJson(Map<String, dynamic> json) {
    Response = (json['Response'] != null)
        ? GeneralResqonseResponse.fromJson(json['Response'])
        : null;
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    if (Response != null) {
      data['Response'] = Response!.toJson();
    }
    return data;
  }
}
