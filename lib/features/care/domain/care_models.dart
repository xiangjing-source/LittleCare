enum CareType { preset, custom, response }

class CareEvent {
  const CareEvent({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.toUserId,
    required this.type,
    required this.message,
    required this.createdAt,
    this.recordId,
    this.parentCareId,
    this.readAt,
  });

  final String id;
  final String groupId;
  final String fromUserId;
  final String toUserId;
  final String? recordId;
  final String? parentCareId;
  final CareType type;
  final String message;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;
}

abstract final class CarePresets {
  static const messages = <String>[
    '今天也要照顾好自己呀',
    '最近辛苦了，记得休息',
    '看到了你的记录，放心一些了',
    '有需要随时找我',
    '给你一个拥抱',
    '想问问你最近怎么样',
  ];

  static const responses = <String>['收到啦', '我没事', '晚点聊', '谢谢你', '想和你说说'];
}
