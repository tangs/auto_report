class NewTransRecordListResqonseTransRecordList implements Comparable {
/*
{
  "_id": "693fcba0dac5cd14e6f32dc9",
  "code": "251133576296",
  "name": "Transfer to Wallet",
  "transRefId": "693fcb9bdcc500ee20377e10",
  "origAmount": 2000,
  "amount": 2000,
  "currency": "MMK",
  "sender": { "id": "...", "name": "...", "phone": "...", ... },
  "receiver": { "id": "...", "name": "...", "phone": "...", ... },
  "status": "done",
  "processedAt": "2025-12-15T08:49:36.296Z",
  "totalDebit": 0,
  "totalCredit": 2000,
  "totalEarn": 0,
  "totalDiscount": 0,
  "icon": "https://...",
  ...
}
*/

  String? orderId;
  String? code;
  String? tradeType;
  int? tradeTime;
  int? amount;
  int? origAmount;
  String? oppositeName;
  String? oppositePhone;
  String? currency;
  int? totalAmount;
  String? debitOrCredit;
  String? historyTitle;
  String? icon;
  String? status;
  String? transRefId;
  int? totalDebit;
  int? totalCredit;
  int? totalEarn;
  int? totalDiscount;
  String? senderPhone;
  String? senderName;
  String? receiverPhone;
  String? receiverName;
  String? message;

  NewTransRecordListResqonseTransRecordList({
    this.orderId,
    this.code,
    this.tradeType,
    this.tradeTime,
    this.amount,
    this.origAmount,
    this.oppositeName,
    this.oppositePhone,
    this.currency,
    this.totalAmount,
    this.debitOrCredit,
    this.historyTitle,
    this.icon,
    this.status,
    this.transRefId,
    this.totalDebit,
    this.totalCredit,
    this.totalEarn,
    this.totalDiscount,
    this.senderPhone,
    this.senderName,
    this.receiverPhone,
    this.receiverName,
    this.message,
  });

  NewTransRecordListResqonseTransRecordList.fromJson(
      Map<String, dynamic> json) {
    orderId = json['_id']?.toString();
    code = json['code']?.toString();
    // code 还是order id，保持兼容
    orderId = code;
    tradeType = json['name']?.toString();
    transRefId = json['transRefId']?.toString();
    amount = (json['amount'] is num) ? (json['amount'] as num).toInt() : null;
    origAmount = (json['origAmount'] is num)
        ? (json['origAmount'] as num).toInt()
        : null;
    currency = json['currency']?.toString();
    status = json['status']?.toString();
    icon = json['icon']?.toString();
    message = json['message']?.toString();

    // Parse processedAt ISO date to milliseconds
    final processedAt = json['processedAt']?.toString();
    if (processedAt != null) {
      tradeTime = DateTime.tryParse(processedAt)?.millisecondsSinceEpoch;
    }

    // Parse sender info
    final sender = json['sender'];
    if (sender is Map<String, dynamic>) {
      senderPhone = sender['phone']?.toString();
      senderName = sender['name']?.toString();
    }

    // Parse receiver info
    final receiver = json['receiver'];
    if (receiver is Map<String, dynamic>) {
      receiverPhone = receiver['phone']?.toString();
      receiverName = receiver['name']?.toString();
      oppositeName = receiverName;
      oppositePhone = receiverPhone;
    }

    totalDebit =
        (json['totalDebit'] is num) ? (json['totalDebit'] as num).toInt() : 0;
    totalCredit =
        (json['totalCredit'] is num) ? (json['totalCredit'] as num).toInt() : 0;
    totalEarn =
        (json['totalEarn'] is num) ? (json['totalEarn'] as num).toInt() : 0;
    totalDiscount = (json['totalDiscount'] is num)
        ? (json['totalDiscount'] as num).toInt()
        : 0;

    // Determine debit or credit
    if (totalCredit != null && totalCredit! > 0) {
      debitOrCredit = 'C';
      totalAmount = totalCredit;
    } else if (totalDebit != null && totalDebit! > 0) {
      debitOrCredit = 'D';
      totalAmount = totalDebit;
    } else {
      debitOrCredit = 'C';
      totalAmount = amount;
    }

    historyTitle = '${tradeType ?? ''} ${oppositeName ?? ''}';
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['_id'] = orderId;
    data['code'] = code;
    data['name'] = tradeType;
    data['transRefId'] = transRefId;
    data['amount'] = amount;
    data['origAmount'] = origAmount;
    data['currency'] = currency;
    data['status'] = status;
    data['icon'] = icon;
    data['message'] = message;
    if (tradeTime != null) {
      data['processedAt'] =
          DateTime.fromMillisecondsSinceEpoch(tradeTime!).toIso8601String();
    }
    data['sender'] = {'name': senderName, 'phone': senderPhone};
    data['receiver'] = {'name': receiverName, 'phone': receiverPhone};
    data['totalDebit'] = totalDebit;
    data['totalCredit'] = totalCredit;
    data['totalEarn'] = totalEarn;
    data['totalDiscount'] = totalDiscount;
    return data;
  }

  @override
  int compareTo(other) {
    if (other is NewTransRecordListResqonseTransRecordList) {
      if (tradeTime == other.tradeTime) return 0;
      return tradeTime! - other.tradeTime!;
    }
    return 0;
  }

  String target() {
    return receiverPhone ?? oppositePhone ?? '';
  }
}

class NewTransRecordListResqonse {
/*
{
  "err": 200,
  "message": "Success",
  "total": 1,
  "data": [ ... ]
}
*/

  List<NewTransRecordListResqonseTransRecordList?>? transRecordList;
  int? err;
  String? message;
  int? total;

  NewTransRecordListResqonse({
    this.transRecordList,
    this.err,
    this.message,
    this.total,
  });

  NewTransRecordListResqonse.fromJson(Map<String, dynamic> json) {
    err = json['err'];
    message = json['message']?.toString();
    total = json['total'];

    if (json['data'] != null) {
      final v = json['data'];
      final arr0 = <NewTransRecordListResqonseTransRecordList>[];
      v.forEach((v) {
        arr0.add(NewTransRecordListResqonseTransRecordList.fromJson(v));
      });
      transRecordList = arr0;
    }
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['err'] = err;
    data['message'] = message;
    data['total'] = total;
    if (transRecordList != null) {
      final arr0 = [];
      transRecordList!.forEach((v) {
        arr0.add(v!.toJson());
      });
      data['data'] = arr0;
    }
    return data;
  }
}
