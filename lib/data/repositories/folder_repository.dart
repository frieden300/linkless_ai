import '../local/database_service.dart';
import '../models/folder.dart';

class FolderRepository {
  final DatabaseService _dbService;

  FolderRepository(this._dbService);

  Future<List<Folder>> getAllFolders() async {
    final db = await _dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'folders',
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Folder.fromMap(maps[i]));
  }

  Future<void> insertFolder(Folder folder) async {
    final db = await _dbService.database;
    await db.insert('folders', folder.toMap());
  }

  Future<void> updateFolder(Folder folder) async {
    final db = await _dbService.database;
    await db.update(
      'folders',
      folder.toMap(),
      where: 'id = ?',
      whereArgs: [folder.id],
    );
  }

  Future<void> deleteFolder(String id) async {
    final db = await _dbService.database;

    // First, unset folder_id for all conversations in this folder
    await db.update(
      'conversations',
      {'folder_id': null},
      where: 'folder_id = ?',
      whereArgs: [id],
    );

    // Delete the folder
    await db.delete('folders', where: 'id = ?', whereArgs: [id]);
  }
}
