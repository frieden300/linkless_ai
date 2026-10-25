class Summary {
  final String id;
  final String conversationId;
  final String summaryText;
  final String? startMsgId;
  final String? endMsgId;
  final int? tokenCount;
  final DateTime createdAt;

  Summary({
    required this.id,
    required this.conversationId,
    required this.summaryText,
    this.startMsgId,
    this.endMsgId,
    this.tokenCount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'summary_text': summaryText,
      'start_msg_id': startMsgId,
      'end_msg_id': endMsgId,
      'token_count': tokenCount,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory Summary.fromMap(Map<String, dynamic> map) {
    return Summary(
      id: map['id'],
      conversationId: map['conversation_id'],
      summaryText: map['summary_text'],
      startMsgId: map['start_msg_id'],
      endMsgId: map['end_msg_id'],
      tokenCount: map['token_count'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']),
    );
  }
}
