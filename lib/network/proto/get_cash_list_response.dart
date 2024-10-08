///
/// Code generated by jsonToDartModel https://ashamp.github.io/jsonToDartModel/
///
class GetCashListResponseDataList {
/*
{
  "id": 16,
  "withdrawals_id": "17184419445665097",
  "cash_account": "+959788972419",
  "money": 99000.1,
  "transfer_bank": ""
} 
*/

  int? id;
  String? withdrawalsId;
  String? cashAccount;
  double? money;
  String? transferBank;

  GetCashListResponseDataList({
    this.id,
    this.withdrawalsId,
    this.cashAccount,
    this.money,
    this.transferBank,
  });
  GetCashListResponseDataList.fromJson(Map<String, dynamic> json) {
    id = json['id']?.toInt();
    withdrawalsId = json['withdrawals_id']?.toString();
    cashAccount = json['cash_account']?.toString();
    money = json['money']?.toDouble();
    transferBank = json['transfer_bank']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['id'] = id;
    data['withdrawals_id'] = withdrawalsId;
    data['cash_account'] = cashAccount;
    data['money'] = money;
    data['transfer_bank'] = transferBank;
    return data;
  }
}

class GetCashListResponseData {
/*
{
  "sum_money": 901000.1,
  "list": [
    {
      "id": 16,
      "withdrawals_id": "17184419445665097",
      "cash_account": "+959788972419",
      "money": 99000.1,
      "transfer_bank": ""
    }
  ]
} 
*/

  double? sumMoney;
  List<GetCashListResponseDataList?>? list;

  GetCashListResponseData({
    this.sumMoney,
    this.list,
  });
  GetCashListResponseData.fromJson(Map<String, dynamic> json) {
    sumMoney = json['sum_money']?.toDouble();
    if (json['list'] != null) {
      final v = json['list'];
      final arr0 = <GetCashListResponseDataList>[];
      v.forEach((v) {
        arr0.add(GetCashListResponseDataList.fromJson(v));
      });
      list = arr0;
    }
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['sum_money'] = sumMoney;
    if (list != null) {
      final v = list;
      final arr0 = [];
      for (var v in v!) {
        arr0.add(v!.toJson());
      }
      data['list'] = arr0;
    }
    return data;
  }
}

class GetCashListResponse {
/*
{
  "success": true,
  "data": {
    "sum_money": 901000.1,
    "list": [
      {
        "id": 16,
        "withdrawals_id": "17184419445665097",
        "cash_account": "+959788972419",
        "money": 99000.1,
        "transfer_bank": ""
      }
    ]
  },
  "error": ""
} 
*/

  bool? success;
  GetCashListResponseData? data;
  String? error;

  GetCashListResponse({
    this.success,
    this.data,
    this.error,
  });
  GetCashListResponse.fromJson(Map<String, dynamic> json) {
    success = json['success'];
    data = (json['data'] != null)
        ? GetCashListResponseData.fromJson(json['data'])
        : null;
    error = json['error']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['success'] = success;
    data['data'] = this.data!.toJson();
    data['error'] = error;
    return data;
  }
}
