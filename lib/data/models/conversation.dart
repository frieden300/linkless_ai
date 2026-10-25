class Conversation {
  final String id;
  final String title;
  final DateTime updatedAt;
  final String? folderId;

  Conversation({
    required this.id,
    required this.title,
    required this.updatedAt,
    this.folderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'folder_id': folderId,
    };
  }

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: map['id'],
      title: map['title'],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at']),
      folderId: map['folder_id'],
    );
  }
}
