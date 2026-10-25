import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../local/database_service.dart';
import '../models/app_settings.dart';

class SettingsRepository {
  final DatabaseService _db;

  SettingsRepository(this._db);

  // Keys
  static const String keyServerUrl = 'server_url';
  static const String keyModelPath = 'model_path';
  static const String keyDarkMode = 'dark_mode';
  static const String keySystemPrompt = 'system_prompt';

  // Defaults
  static const String defaultServerUrl = 'http://localhost:8080';
  static const bool defaultDarkMode = true;
  static const String defaultSystemPrompt =
      'You are a helpful AI assistant. When writing math equations, always wrap them in \$\$ equation \$\$ for block equations or inline math. Example: \$\$ E = mc^2 \$\$';

  // Legacy key-value settings
  Future<void> saveSetting(String key, String value) async {
    final db = await _db.database;
    await db.insert('settings', {
      'key': key,
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await _db.database;
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

  Future<String> getServerUrl() async {
    return await getSetting(keyServerUrl) ?? defaultServerUrl;
  }

  Future<void> setServerUrl(String url) async {
    await saveSetting(keyServerUrl, url);
  }

  Future<String?> getModelPath() async {
    return await getSetting(keyModelPath);
  }

  Future<void> setModelPath(String path) async {
    await saveSetting(keyModelPath, path);
  }

  Future<bool> getDarkMode() async {
    final val = await getSetting(keyDarkMode);
    if (val == null) return defaultDarkMode;
    return val == 'true';
  }

  Future<void> setDarkMode(bool enabled) async {
    await saveSetting(keyDarkMode, enabled.toString());
  }

  Future<String> getSystemPrompt() async {
    return await getSetting(keySystemPrompt) ?? defaultSystemPrompt;
  }

  Future<void> setSystemPrompt(String prompt) async {
    await saveSetting(keySystemPrompt, prompt);
  }

  // AppSettings methods
  Future<void> saveAppSetting(String key, String value) async {
    final db = await _db.database;
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<AppSettings> loadAppSettings() async {
    final db = await _db.database;
    final List<Map<String, dynamic>> maps = await db.query('app_settings');

    final settingsMap = <String, String>{};
    for (var map in maps) {
      settingsMap[map['key'] as String] = map['value'] as String;
    }

    return AppSettings.fromMap(settingsMap);
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    final map = settings.toMap();
    for (var entry in map.entries) {
      await saveAppSetting(entry.key, entry.value);
    }
  }
}
