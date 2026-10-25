import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/settings_repository.dart';
import 'providers.dart';

class SettingsState {
  final String serverUrl;
  final String? modelPath;
  final bool isDarkMode;
  final String systemPrompt;

  const SettingsState({
    required this.serverUrl,
    this.modelPath,
    required this.isDarkMode,
    required this.systemPrompt,
  });

  SettingsState copyWith({
    String? serverUrl,
    String? modelPath,
    bool? isDarkMode,
    String? systemPrompt,
  }) {
    return SettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      modelPath: modelPath ?? this.modelPath,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      systemPrompt: systemPrompt ?? this.systemPrompt,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _repository;

  SettingsNotifier(this._repository)
    : super(
        const SettingsState(
          serverUrl: SettingsRepository.defaultServerUrl,
          isDarkMode: true,
          systemPrompt: SettingsRepository.defaultSystemPrompt,
        ),
      ) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final url = await _repository.getServerUrl();
    final modelPath = await _repository.getModelPath();
    final darkMode = await _repository.getDarkMode();
    final prompt = await _repository.getSystemPrompt();

    state = SettingsState(
      serverUrl: url,
      modelPath: modelPath,
      isDarkMode: darkMode,
      systemPrompt: prompt,
    );
  }

  Future<void> setServerUrl(String url) async {
    await _repository.setServerUrl(url);
    state = state.copyWith(serverUrl: url);
  }

  Future<void> setModelPath(String path) async {
    await _repository.setModelPath(path);
    state = state.copyWith(modelPath: path);
  }

  Future<void> toggleDarkMode() async {
    final newValue = !state.isDarkMode;
    await _repository.setDarkMode(newValue);
    state = state.copyWith(isDarkMode: newValue);
  }

  Future<void> setSystemPrompt(String prompt) async {
    await _repository.setSystemPrompt(prompt);
    state = state.copyWith(systemPrompt: prompt);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final repo = ref.watch(settingsRepositoryProvider);
    return SettingsNotifier(repo);
  },
);
