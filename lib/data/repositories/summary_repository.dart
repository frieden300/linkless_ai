import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../local/database_service.dart';
import '../models/summary.dart';

class SummaryRepository {
  final DatabaseService _db;

  SummaryRepository(this._db);

  /// Get the latest summary for a conversation
  Future<Summary?> getLatestSummary(String conversationId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'summaries',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Summary.fromMap(maps.first);
    }
    return null;
  }

  /// Get all summaries for a conversation
  Future<List<Summary>> getSummaries(String conversationId) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'summaries',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => Summary.fromMap(m)).toList();
  }

  /// Save a summary
  Future<void> saveSummary(Summary summary) async {
    final db = await _db.database;
    await db.insert(
      'summaries',
      summary.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete all summaries for a conversation
  Future<void> deleteSummaries(String conversationId) async {
    final db = await _db.database;
    await db.delete(
      'summaries',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }
}
