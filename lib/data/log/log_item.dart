import 'dart:collection';

enum LogItemType { receive, send, err, newAccount, deleteAccount }

final class LogItem extends LinkedListEntry<LogItem> {
  final LogItemType type;
  final String platformName;
  final String platformKey;
  final String phone;
  final DateTime time;
  final String content;

  LogItem({
    required this.type,
    required this.platformName,
    required this.platformKey,
    required this.phone,
    required this.time,
    required this.content,
  });

  @override
  String toString() {
    return '$type $phone[$time]: $content';
  }

  String getType() {
    switch (type) {
      case LogItemType.receive:
        return 'receive money';
      case LogItemType.send:
        return 'recsendive money';
      case LogItemType.err:
        return 'err';
      case LogItemType.newAccount:
        return 'new account';
      case LogItemType.deleteAccount:
        return 'delete account';
    }
  }
}
