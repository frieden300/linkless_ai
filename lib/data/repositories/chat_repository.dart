import 'package:uuid/uuid.dart';
import '../local/database_service.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class ChatRepository {
  final DatabaseService _dbService;
  final Uuid _uuid = const Uuid();

  ChatRepository(this._dbService);

  Future<List<Conversation>> getConversations() async {
    return await _dbService.getConversations();
  }

  Future<List<Message>> getMessages(String conversationId) async {
    return await _dbService.getMessages(conversationId);
  }

  Future<Conversation> createConversation({String? title}) async {
    final id = _uuid.v4();
    final newConversation = Conversation(
      id: id,
      title: title ?? 'New Chat',
      updatedAt: DateTime.now(),
    );
    await _dbService.insertConversation(newConversation);
    return newConversation;
  }

  Future<void> deleteConversation(String id) async {
    await _dbService.deleteConversation(id);
  }

  Future<void> deleteConversationsInFolder(String folderId) async {
    await _dbService.deleteConversationsByFolder(folderId);
  }

  Future<void> renameConversation(String id, String newTitle) async {
    await _dbService.updateConversationTitle(id, newTitle);
  }

  Future<void> saveMessage(Message message) async {
    await _dbService.insertMessage(message);
  }

  Future<void> deleteMessage(String id) async {
    await _dbService.deleteMessage(id);
  }

  Future<void> moveToFolder(String conversationId, String? folderId) async {
    final db = await _dbService.database;
    await db.update(
      'conversations',
      {'folder_id': folderId},
      where: 'id = ?',
      whereArgs: [conversationId],
    );
  }

  Future<void> clearAllHistory() async {
    await _dbService.clearAllConversations();
  }
}
