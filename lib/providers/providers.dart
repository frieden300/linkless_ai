import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/database_service.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/model_repository.dart';
import '../data/repositories/folder_repository.dart';
import '../data/repositories/summary_repository.dart';
import '../data/repositories/fact_repository.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository(ref.watch(databaseServiceProvider));
});

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(databaseServiceProvider));
});

final modelRepositoryProvider = Provider<ModelRepository>((ref) {
  return ModelRepository(ref.watch(databaseServiceProvider));
});

final folderRepositoryProvider = Provider<FolderRepository>((ref) {
  return FolderRepository(ref.watch(databaseServiceProvider));
});

final summaryRepositoryProvider = Provider<SummaryRepository>((ref) {
  return SummaryRepository(ref.watch(databaseServiceProvider));
});

final factRepositoryProvider = Provider<FactRepository>((ref) {
  return FactRepository(ref.watch(databaseServiceProvider));
});
