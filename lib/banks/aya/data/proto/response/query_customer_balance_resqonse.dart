// ignore_for_file: non_constant_identifier_names

class QueryCustomerBalanceResqonseResponseBodyResponseDetailNewResultInfo {
/*
{} 
*/

  QueryCustomerBalanceResqonseResponseBodyResponseDetailNewResultInfo();
  QueryCustomerBalanceResqonseResponseBodyResponseDetailNewResultInfo.fromJson(
      Map<String, dynamic> json);
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    return data;
  }
}

class QueryCustomerBalanceResqonseResponseBodyResponseDetail {
/*
{
  "TotalBalance": "149.00",
  "newResultInfo": {},
  "AvailableBalance": "149.00",
  "Currency": "Ks",
  "ServerTimestamp": 1720768360757,
  "ResultDesc": "Process service request successfully.",
  "Balance": "149.00",
  "TransTime": "1720768359913",
  "ResultCode": "0"
} 
*/

  String? TotalBalance;
  QueryCustomerBalanceResqonseResponseBodyResponseDetailNewResultInfo?
      newResultInfo;
  String? AvailableBalance;
  String? Currency;
  int? ServerTimestamp;
  String? ResultDesc;
  String? Balance;
  String? TransTime;
  String? ResultCode;

  QueryCustomerBalanceResqonseResponseBodyResponseDetail({
    this.TotalBalance,
    this.newResultInfo,
    this.AvailableBalance,
    this.Currency,
    this.ServerTimestamp,
    this.ResultDesc,
    this.Balance,
    this.TransTime,
    this.ResultCode,
  });
  QueryCustomerBalanceResqonseResponseBodyResponseDetail.fromJson(
      Map<String, dynamic> json) {
    TotalBalance = json['TotalBalance']?.toString();
    newResultInfo = (json['newResultInfo'] != null)
        ? QueryCustomerBalanceResqonseResponseBodyResponseDetailNewResultInfo
            .fromJson(json['newResultInfo'])
        : null;
    AvailableBalance = json['AvailableBalance']?.toString();
    Currency = json['Currency']?.toString();
    ServerTimestamp = json['ServerTimestamp']?.toInt();
    ResultDesc = json['ResultDesc']?.toString();
    Balance = json['Balance']?.toString();
    TransTime = json['TransTime']?.toString();
    ResultCode = json['ResultCode']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['TotalBalance'] = TotalBalance;
    if (newResultInfo != null) {
      data['newResultInfo'] = newResultInfo!.toJson();
    }
    data['AvailableBalance'] = AvailableBalance;
    data['Currency'] = Currency;
    data['ServerTimestamp'] = ServerTimestamp;
    data['ResultDesc'] = ResultDesc;
    data['Balance'] = Balance;
    data['TransTime'] = TransTime;
    data['ResultCode'] = ResultCode;
    return data;
  }
}

class QueryCustomerBalanceResqonseResponseBody {
/*
{
  "ResponseCode": "0",
  "ResponseDesc": "Accept the service request successfully.",
  "ResponseDetail": {
    "TotalBalance": "149.00",
    "newResultInfo": {},
    "AvailableBalance": "149.00",
    "Currency": "Ks",
    "ServerTimestamp": 1720768360757,
    "ResultDesc": "Process service request successfully.",
    "Balance": "149.00",
    "TransTime": "1720768359913",
    "ResultCode": "0"
  }
} 
*/

  String? ResponseCode;
  String? ResponseDesc;
  QueryCustomerBalanceResqonseResponseBodyResponseDetail? ResponseDetail;

  QueryCustomerBalanceResqonseResponseBody({
    this.ResponseCode,
    this.ResponseDesc,
    this.ResponseDetail,
  });
  QueryCustomerBalanceResqonseResponseBody.fromJson(Map<String, dynamic> json) {
    ResponseCode = json['ResponseCode']?.toString();
    ResponseDesc = json['ResponseDesc']?.toString();
    ResponseDetail = (json['ResponseDetail'] != null)
        ? QueryCustomerBalanceResqonseResponseBodyResponseDetail.fromJson(
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

class QueryCustomerBalanceResqonseResponseHeader {
/*
{
  "Version": "1460",
  "ConversationID": ""
} 
*/

  String? Version;
  String? ConversationID;

  QueryCustomerBalanceResqonseResponseHeader({
    this.Version,
    this.ConversationID,
  });
  QueryCustomerBalanceResqonseResponseHeader.fromJson(
      Map<String, dynamic> json) {
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

class QueryCustomerBalanceResqonseResponse {
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
      "TotalBalance": "149.00",
      "newResultInfo": {},
      "AvailableBalance": "149.00",
      "Currency": "Ks",
      "ServerTimestamp": 1720768360757,
      "ResultDesc": "Process service request successfully.",
      "Balance": "149.00",
      "TransTime": "1720768359913",
      "ResultCode": "0"
    }
  }
} 
*/

  QueryCustomerBalanceResqonseResponseHeader? Header;
  QueryCustomerBalanceResqonseResponseBody? Body;

  QueryCustomerBalanceResqonseResponse({
    this.Header,
    this.Body,
  });
  QueryCustomerBalanceResqonseResponse.fromJson(Map<String, dynamic> json) {
    Header = (json['Header'] != null)
        ? QueryCustomerBalanceResqonseResponseHeader.fromJson(json['Header'])
        : null;
    Body = (json['Body'] != null)
        ? QueryCustomerBalanceResqonseResponseBody.fromJson(json['Body'])
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

class QueryCustomerBalanceResqonse {
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
        "TotalBalance": "149.00",
        "newResultInfo": {},
        "AvailableBalance": "149.00",
        "Currency": "Ks",
        "ServerTimestamp": 1720768360757,
        "ResultDesc": "Process service request successfully.",
        "Balance": "149.00",
        "TransTime": "1720768359913",
        "ResultCode": "0"
      }
    }
  }
} 
*/

  QueryCustomerBalanceResqonseResponse? Response;

  QueryCustomerBalanceResqonse({
    this.Response,
  });
  QueryCustomerBalanceResqonse.fromJson(Map<String, dynamic> json) {
    Response = (json['Response'] != null)
        ? QueryCustomerBalanceResqonseResponse.fromJson(json['Response'])
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
