import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../data/models/app_settings.dart';
import '../data/repositories/settings_repository.dart';
import 'providers.dart';

class AppSettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  AppSettingsNotifier(this._repo) : super(AppSettings()) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    try {
      final settings = await _repo.loadAppSettings();
      state = settings;
    } catch (e) {
      debugPrint('Error loading app settings: $e');
      // Use defaults
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    // Update state immediately for UI responsiveness
    switch (key) {
      case 'llamaServerPath':
        state = state.copyWith(llamaServerPath: value as String);
        break;
      case 'temperature':
        state = state.copyWith(temperature: value as double);
        break;
      case 'maxTokens':
        state = state.copyWith(maxTokens: value as int);
        break;
      case 'systemPrompt':
        state = state.copyWith(systemPrompt: value as String);
        break;
      case 'autoScroll':
        state = state.copyWith(autoScroll: value as bool);
        break;
      case 'fontSize':
        state = state.copyWith(fontSize: value as int);
        break;
      case 'darkMode':
        state = state.copyWith(darkMode: value as bool);
        break;
      case 'accentColor':
        state = state.copyWith(accentColor: value as String);
        break;
      case 'contextWindow':
        state = state.copyWith(contextWindow: value as int);
        break;
      case 'webSearchApiKey':
        state = state.copyWith(
          webSearchApiKey: value as String?,
          clearWebSearchApiKey: value == null,
        );
        break;
      case 'saveHistory':
        state = state.copyWith(saveHistory: value as bool);
        break;
      case 'contextLength':
        state = state.copyWith(contextLength: value as int);
        break;
      case 'enableKvCache':
        state = state.copyWith(enableKvCache: value as bool);
        break;
      case 'maxHistoryTokens':
        state = state.copyWith(maxHistoryTokens: value as int);
        break;
      case 'messageWindow':
        state = state.copyWith(messageWindow: value as int);
        break;
      case 'summaryThreshold':
        state = state.copyWith(summaryThreshold: value as int);
        break;
      case 'enableAutoSummary':
        state = state.copyWith(enableAutoSummary: value as bool);
        break;
      case 'visionModelPath':
        state = state.copyWith(
          visionModelPath: value as String?,
          clearVisionModelPath: value == null,
        );
        break;
      case 'mmProjPath':
        state = state.copyWith(
          mmProjPath: value as String?,
          clearMmProjPath: value == null,
        );
        break;
      case 'baseModelsExpanded':
        state = state.copyWith(baseModelsExpanded: value as bool);
        break;
      case 'visualModelsExpanded':
        state = state.copyWith(visualModelsExpanded: value as bool);
        break;
      case 'mmProjModelsExpanded':
        state = state.copyWith(mmProjModelsExpanded: value as bool);
        break;
    }

    // Auto-save to database with correct snake_case keys used by AppSettings.fromMap
    String storageKey = key;
    switch (key) {
      case 'llamaServerPath':
        storageKey = 'llama_server_path';
        break;
      case 'temperature':
        storageKey = 'temperature';
        break;
      case 'maxTokens':
        storageKey = 'max_tokens';
        break;
      case 'systemPrompt':
        storageKey = 'system_prompt';
        break;
      case 'autoScroll':
        storageKey = 'auto_scroll';
        break;
      case 'fontSize':
        storageKey = 'font_size';
        break;
      case 'darkMode':
        storageKey = 'dark_mode';
        break;
      case 'accentColor':
        storageKey = 'accent_color';
        break;
      case 'contextWindow':
        storageKey = 'context_window';
        break;
      case 'webSearchApiKey':
        storageKey = 'web_search_api_key';
        break;
      case 'saveHistory':
        storageKey = 'save_history';
        break;
      case 'contextLength':
        storageKey = 'context_length';
        break;
      case 'enableKvCache':
        storageKey = 'enable_kv_cache';
        break;
      case 'maxHistoryTokens':
        storageKey = 'max_history_tokens';
        break;
      case 'messageWindow':
        storageKey = 'message_window';
        break;
      case 'summaryThreshold':
        storageKey = 'summary_threshold';
        break;
      case 'enableAutoSummary':
        storageKey = 'enable_auto_summary';
        break;
      case 'visionModelPath':
        storageKey = 'vision_model_path';
        break;
      case 'mmProjPath':
        storageKey = 'mm_proj_path';
        break;
      case 'baseModelsExpanded':
        storageKey = 'base_models_expanded';
        break;
      case 'visualModelsExpanded':
        storageKey = 'visual_models_expanded';
        break;
      case 'mmProjModelsExpanded':
        storageKey = 'mm_proj_models_expanded';
        break;
    }

    // Convert values to strings for storage (Persistence format)
    String storageValue = value?.toString() ?? '';
    if (value is bool) {
      storageValue = value ? '1' : '0';
    }

    await _repo.saveAppSetting(storageKey, storageValue);
  }

  Future<void> saveAllSettings() async {
    await _repo.saveAppSettings(state);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
      return AppSettingsNotifier(ref.watch(settingsRepositoryProvider));
    });
