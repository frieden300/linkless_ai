import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../local/database_service.dart';
import '../models/model_entry.dart';

class ModelRepository {
  final DatabaseService _db;

  ModelRepository(this._db);

  Future<List<ModelEntry>> getModels() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'models',
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => ModelEntry.fromMap(maps[i]));
  }

  Future<void> addModel(ModelEntry model) async {
    final db = await _db.database;
    await db.insert(
      'models',
      model.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateModel(ModelEntry model) async {
    final db = await _db.database;
    await db.update(
      'models',
      model.toMap(),
      where: 'id = ?',
      whereArgs: [model.id],
    );
  }

  Future<void> deleteModel(String id) async {
    final db = await _db.database;
    await db.delete('models', where: 'id = ?', whereArgs: [id]);
  }

  Future<ModelEntry?> getModelById(String id) async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'models',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return ModelEntry.fromMap(maps.first);
    }
    return null;
  }
}
