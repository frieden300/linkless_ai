import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../local/database_service.dart';
import '../models/fact.dart';

class FactRepository {
  final DatabaseService _db;

  FactRepository(this._db);

  /// Get all facts
  Future<List<Fact>> getAllFacts() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'facts',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Fact.fromMap(m)).toList();
  }

  /// Get a specific fact by key
  Future<Fact?> getFactByKey(String key) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'facts',
      where: 'fact_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return Fact.fromMap(maps.first);
    }
    return null;
  }

  /// Insert or update a fact
  Future<void> upsertFact(Fact fact) async {
    final db = await _db.database;
    await db.insert(
      'facts',
      fact.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete a fact by id
  Future<void> deleteFact(String id) async {
    final db = await _db.database;
    await db.delete('facts', where: 'id = ?', whereArgs: [id]);
  }

  /// Delete all facts
  Future<void> deleteAllFacts() async {
    final db = await _db.database;
    await db.delete('facts');
  }
}
