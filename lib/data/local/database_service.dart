import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class DatabaseService {
  static Database? _database;
  static bool _schemaChecked = false;

  Future<Database> get database async {
    if (_database != null) {
      if (!_schemaChecked) {
        _schemaChecked = true;
        try {
          await _database!.execute('ALTER TABLE conversations ADD COLUMN folder_id TEXT');
        } catch (_) {}
      }
      return _database!;
    }
    _database = await _initDatabase();
    _schemaChecked = true;
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Initialize FFI for Windows
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'linkless_ai', 'linkless_ai.db');

    // Ensure directory exists
    await Directory(dirname(path)).create(recursive: true);

    return await openDatabase(
      path,
      version: 8,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onOpen: (db) async {
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN folder_id TEXT');
        } catch (_) {}
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add models table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS models(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          file_path TEXT NOT NULL,
          size_param TEXT,
          quantization TEXT,
          file_size_mb INTEGER,
          model_family TEXT,
          storage_type TEXT,
          context_length INTEGER,
          created_at INTEGER
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add app_settings table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_settings(
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL,
          updated_at INTEGER
        )
      ''');

      // Add folders table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS folders(
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          created_at INTEGER
        )
      ''');

      // Add folder_id column to conversations
      await db.execute('''
        ALTER TABLE conversations ADD COLUMN folder_id TEXT
      ''');
    }

    if (oldVersion < 4) {
      // Add reasoning column to messages
      await db.execute('''
        ALTER TABLE messages ADD COLUMN reasoning TEXT
      ''');
    }

    if (oldVersion < 5) {
      // Summaries table — compressed conversation history
      await db.execute('''
        CREATE TABLE IF NOT EXISTS summaries(
          id TEXT PRIMARY KEY,
          conversation_id TEXT NOT NULL,
          summary_text TEXT NOT NULL,
          start_msg_id TEXT,
          end_msg_id TEXT,
          token_count INTEGER,
          created_at INTEGER,
          FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
        )
      ''');

      // Facts table — stable key-value user memory
      await db.execute('''
        CREATE TABLE IF NOT EXISTS facts(
          id TEXT PRIMARY KEY,
          fact_key TEXT NOT NULL,
          fact_value TEXT NOT NULL,
          source TEXT DEFAULT 'manual',
          confidence REAL DEFAULT 1.0,
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
    }

    if (oldVersion < 6) {
      // Add missing columns to messages table for metrics and image support
      try { await db.execute('ALTER TABLE messages ADD COLUMN model TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN generation_time REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN token_count INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN total_context INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN tps REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE messages ADD COLUMN image_paths TEXT'); } catch (_) {}
    }

    if (oldVersion < 7) {
      try { await db.execute('ALTER TABLE messages ADD COLUMN document_paths TEXT'); } catch (_) {}
    }

    if (oldVersion < 8) {
      try { await db.execute('ALTER TABLE conversations ADD COLUMN folder_id TEXT'); } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE conversations(
        id TEXT PRIMARY KEY,
        title TEXT,
        updated_at INTEGER,
        folder_id TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE messages(
        id TEXT PRIMARY KEY,
        conversation_id TEXT,
        role TEXT,
        content TEXT,
        reasoning TEXT,
        timestamp INTEGER,
        model TEXT,
        generation_time REAL,
        token_count INTEGER,
        total_context INTEGER,
        tps REAL,
        image_paths TEXT,
        document_paths TEXT,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');

    // Settings table for key-value storage
    await db.execute('''
      CREATE TABLE settings(
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Models table for managing .gguf models
    await db.execute('''
      CREATE TABLE models(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        size_param TEXT,
        quantization TEXT,
        file_size_mb INTEGER,
        model_family TEXT,
        storage_type TEXT,
        context_length INTEGER,
        created_at INTEGER
      )
    ''');

    // App settings table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings(
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at INTEGER
      )
    ''');

    // Folders table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS folders(
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        created_at INTEGER
      )
    ''');

    // Summaries table — compressed conversation history
    await db.execute('''
      CREATE TABLE summaries(
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        summary_text TEXT NOT NULL,
        start_msg_id TEXT,
        end_msg_id TEXT,
        token_count INTEGER,
        created_at INTEGER,
        FOREIGN KEY(conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    ''');

    // Facts table — stable key-value user memory
    await db.execute('''
      CREATE TABLE facts(
        id TEXT PRIMARY KEY,
        fact_key TEXT NOT NULL,
        fact_value TEXT NOT NULL,
        source TEXT DEFAULT 'manual',
        confidence REAL DEFAULT 1.0,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
  }

  // Conversation Helpers
  Future<List<Conversation>> getConversations() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Conversation.fromMap(maps[i]));
  }

  Future<void> insertConversation(Conversation conversation) async {
    final db = await database;
    try {
      await db.insert(
        'conversations',
        conversation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (e.toString().contains('no column named folder_id')) {
        try {
          await db.execute('ALTER TABLE conversations ADD COLUMN folder_id TEXT');
        } catch (_) {}
        await db.insert(
          'conversations',
          conversation.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> updateConversationTitle(String id, String newTitle) async {
    final db = await database;
    await db.update(
      'conversations',
      {'title': newTitle},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteConversation(String id) async {
    final db = await database;
    await db.delete('conversations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteConversationsByFolder(String folderId) async {
    final db = await database;
    // This will delete all conversations in that folder.
    // Due to the FOREIGN KEY CASCADE in the messages table (if correctly set up for folder_id, but it's not),
    // we need to make sure messages are also deleted.
    // However, our messages table references conversation_id with ON DELETE CASCADE.
    // So deleting the conversation is enough.
    await db.delete('conversations', where: 'folder_id = ?', whereArgs: [folderId]);
  }

  Future<void> clearAllConversations() async {
    final db = await database;
    await db.delete('conversations');
    await db.delete('folders');
    await db.delete('summaries');
  }

  // Message Helpers
  Future<List<Message>> getMessages(String conversationId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC',
    );
    return List.generate(maps.length, (i) => Message.fromMap(maps[i]));
  }

  Future<void> insertMessage(Message message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update conversation timestamp
    await db.update(
      'conversations',
      {'updated_at': message.timestamp.millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [message.conversationId],
    );
  }

  Future<void> deleteMessage(String id) async {
    final db = await database;
    await db.delete('messages', where: 'id = ?', whereArgs: [id]);
  }

  // Settings Helpers
  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String;
    }
    return null;
  }
}
