class Message {
  final String id;
  final String conversationId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String? reasoning;
  final DateTime timestamp;
  final String? model;
  final double? generationTime;
  final int? tokenCount;
  final int? totalContext;
  final double? tps;
  final List<String>? imagePaths; // Paths of images attached to this message
  final List<String>? documentPaths; // Paths of documents attached to this message (PDFs, etc)

  Message({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.reasoning,
    required this.timestamp,
    this.model,
    this.generationTime,
    this.tokenCount,
    this.totalContext,
    this.tps,
    this.imagePaths,
    this.documentPaths,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'role': role,
      'content': content,
      'reasoning': reasoning,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'model': model,
      'generation_time': generationTime,
      'token_count': tokenCount,
      'total_context': totalContext,
      'tps': tps,
      'image_paths': imagePaths?.join('|'),
      'document_paths': documentPaths?.join('|'),
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      conversationId: map['conversation_id'],
      role: map['role'],
      content: map['content'],
      reasoning: map['reasoning'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      model: map['model'],
      generationTime: map['generation_time']?.toDouble(),
      tokenCount: map['token_count'],
      totalContext: map['total_context'],
      tps: map['tps']?.toDouble(),
      imagePaths: (map['image_paths'] as String?)?.isNotEmpty == true
          ? (map['image_paths'] as String).split('|')
          : null,
      documentPaths: (map['document_paths'] as String?)?.isNotEmpty == true
          ? (map['document_paths'] as String).split('|')
          : null,
    );
  }

  Message copyWith({
    String? id,
    String? conversationId,
    String? role,
    String? content,
    String? reasoning,
    DateTime? timestamp,
    String? model,
    double? generationTime,
    int? tokenCount,
    int? totalContext,
    double? tps,
    List<String>? imagePaths,
    List<String>? documentPaths,
  }) {
    return Message(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      reasoning: reasoning ?? this.reasoning,
      timestamp: timestamp ?? this.timestamp,
      model: model ?? this.model,
      generationTime: generationTime ?? this.generationTime,
      tokenCount: tokenCount ?? this.tokenCount,
      totalContext: totalContext ?? this.totalContext,
      tps: tps ?? this.tps,
      imagePaths: imagePaths ?? this.imagePaths,
      documentPaths: documentPaths ?? this.documentPaths,
    );
  }
}
