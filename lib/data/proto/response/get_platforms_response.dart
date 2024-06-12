///
/// Code generated by jsonToDartModel https://ashamp.github.io/jsonToDartModel/
///
class GetPlatformsResponseData {
/*
{
  "name": "缅甸6",
  "url": "http://18.140.251.182",
  "key": "myanmar6",
  "mark": "69d80bc75f239f99087e5807c86e0c7a"
} 
*/

  String? name;
  String? url;
  String? key;
  String? mark;

  GetPlatformsResponseData({
    this.name,
    this.url,
    this.key,
    this.mark,
  });
  GetPlatformsResponseData.fromJson(Map<String, dynamic> json) {
    name = json['name']?.toString();
    url = json['url']?.toString();
    key = json['key']?.toString();
    mark = json['mark']?.toString();
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['name'] = name;
    data['url'] = url;
    data['key'] = key;
    data['mark'] = mark;
    return data;
  }
}

class GetPlatformsResponse {
/*
{
  "status": true,
  "msg": "success",
  "data": [
    {
      "name": "缅甸6",
      "url": "http://18.140.251.182",
      "key": "myanmar6",
      "mark": "69d80bc75f239f99087e5807c86e0c7a"
    }
  ]
} 
*/

  bool? status;
  String? msg;
  List<GetPlatformsResponseData?>? data;

  GetPlatformsResponse({
    this.status,
    this.msg,
    this.data,
  });
  GetPlatformsResponse.fromJson(Map<String, dynamic> json) {
    status = json['status'];
    msg = json['msg']?.toString();
    if (json['data'] != null) {
      final v = json['data'];
      final arr0 = <GetPlatformsResponseData>[];
      v.forEach((v) {
        arr0.add(GetPlatformsResponseData.fromJson(v));
      });
      data = arr0;
      // data = json['data']
      //     .map((v) => GetPlatformsResponseData.fromJson(v))
      //     .toList<GetPlatformsResponseData>();
    }
  }
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};
    data['status'] = status;
    data['msg'] = msg;
    if (this.data != null) {
      // final v = this.data;
      // final arr0 = [];
      // v!.forEach((v) {
      //   arr0.add(v!.toJson());
      // });
      data['data'] = this.data!.map((v) => v!.toJson()).toList();
    }
    return data;
  }
}
