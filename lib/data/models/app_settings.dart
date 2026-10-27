import 'dart:io';
import 'package:path/path.dart' as p;

enum ModelMode { fast, vision }

class AppSettings {
  final String llamaServerPath;
  final double temperature; // AI creativity (0.0-2.0)
  final int maxTokens; // Max response length
  final String systemPrompt; // Default instructions for AI
  final bool autoScroll;
  final int fontSize;
  final bool darkMode;
  final String accentColor;
  final int contextWindow; // Number of messages to remember
  final String? webSearchApiKey;
  final bool saveHistory; // Privacy: save conversation history
  final int contextLength; // Total context length for llama-server (-c)
  final bool enableKvCache; // Enable/disable KV cache in llama-server
  final int maxHistoryTokens; // Max tokens to send in conversation history
  final int messageWindow; // Number of recent messages to always include
  final int summaryThreshold; // Token count that triggers auto-summarization
  final bool enableAutoSummary; // Enable/disable auto-summarization
  final String? visionModelPath; // Path to VL GGUF model
  final String? mmProjPath;     // Path to mmproj GGUF file
  final bool baseModelsExpanded;
  final bool visualModelsExpanded;
  final bool mmProjModelsExpanded;

  static String get defaultLlamaServerPath {
    final exeDir = p.dirname(Platform.resolvedExecutable);

    // 1. Packaged release mode: next to linkless_ai.exe
    final releasePath = p.join(exeDir, 'llama-cpp', 'llama-server.exe');
    if (File(releasePath).existsSync()) {
      return releasePath;
    }

    // 2. Development mode: current working directory (e.g. flutter run in repo root)
    final cwdPath = p.join(Directory.current.path, 'llama-cpp', 'llama-server.exe');
    if (File(cwdPath).existsSync()) {
      return cwdPath;
    }

    // 3. Development mode: project root when running from build/windows/x64/runner/(Debug|Release)
    final devPath = p.normalize(p.join(exeDir, '..', '..', '..', '..', '..', 'llama-cpp', 'llama-server.exe'));
    if (File(devPath).existsSync()) {
      return devPath;
    }

    return releasePath;
  }

  AppSettings({
    String? llamaServerPath,
    this.temperature = 0.7,
    this.maxTokens = 8192,
    this.systemPrompt = 'You are a helpful AI assistant.',
    this.autoScroll = true,
    this.fontSize = 15,
    this.darkMode = true,
    this.accentColor = '00D9FF',
    this.contextWindow = 10,
    this.webSearchApiKey,
    this.saveHistory = true,
    this.contextLength = 4096,
    this.enableKvCache = true,
    this.maxHistoryTokens = 8000,
    this.messageWindow = 20,
    this.summaryThreshold = 4000,
    this.enableAutoSummary = true,
    this.visionModelPath,
    this.mmProjPath,
    this.baseModelsExpanded = true,
    this.visualModelsExpanded = true,
    this.mmProjModelsExpanded = true,
  }) : llamaServerPath = (llamaServerPath != null && llamaServerPath.isNotEmpty && File(llamaServerPath).existsSync())
            ? llamaServerPath
            : defaultLlamaServerPath;

  Map<String, dynamic> toMap() {
    return {
      'llama_server_path': llamaServerPath,
      'temperature': temperature.toString(),
      'max_tokens': maxTokens.toString(),
      'system_prompt': systemPrompt,
      'auto_scroll': autoScroll ? '1' : '0',
      'font_size': fontSize.toString(),
      'dark_mode': darkMode ? '1' : '0',
      'accent_color': accentColor,
      'context_window': contextWindow.toString(),
      'web_search_api_key': webSearchApiKey ?? '',
      'save_history': saveHistory ? '1' : '0',
      'context_length': contextLength.toString(),
      'enable_kv_cache': enableKvCache ? '1' : '0',
      'max_history_tokens': maxHistoryTokens.toString(),
      'message_window': messageWindow.toString(),
      'summary_threshold': summaryThreshold.toString(),
      'enable_auto_summary': enableAutoSummary ? '1' : '0',
      'vision_model_path': visionModelPath ?? '',
      'mm_proj_path': mmProjPath ?? '',
      'base_models_expanded': baseModelsExpanded ? '1' : '0',
      'visual_models_expanded': visualModelsExpanded ? '1' : '0',
      'mm_proj_models_expanded': mmProjModelsExpanded ? '1' : '0',
    };
  }

  factory AppSettings.fromMap(Map<String, String> map) {
    return AppSettings(
      llamaServerPath: map['llama_server_path'],
      temperature: double.tryParse(map['temperature'] ?? '0.7') ?? 0.7,
      maxTokens: int.tryParse(map['max_tokens'] ?? '8192') ?? 8192,
      systemPrompt: map['system_prompt'] ?? 'You are a helpful AI assistant.',
      autoScroll: map['auto_scroll'] == '1',
      fontSize: int.tryParse(map['font_size'] ?? '15') ?? 15,
      darkMode: map['dark_mode'] != '0', // Default true
      accentColor: map['accent_color'] ?? '00D9FF',
      contextWindow: int.tryParse(map['context_window'] ?? '10') ?? 10,
      webSearchApiKey: (map['web_search_api_key'] == null ||
              map['web_search_api_key']!.isEmpty ||
              map['web_search_api_key'] == 'null')
          ? null
          : map['web_search_api_key'],
      saveHistory: map['save_history'] != '0', // Default true
      contextLength: int.tryParse(map['context_length'] ?? '4096') ?? 4096,
      enableKvCache: map['enable_kv_cache'] != '0', // Default true
      maxHistoryTokens:
          int.tryParse(map['max_history_tokens'] ?? '8000') ?? 8000,
      messageWindow: int.tryParse(map['message_window'] ?? '20') ?? 20,
      summaryThreshold:
          int.tryParse(map['summary_threshold'] ?? '4000') ?? 4000,
      enableAutoSummary: map['enable_auto_summary'] != '0',
      visionModelPath: map['vision_model_path']?.isEmpty ?? true
          ? null
          : map['vision_model_path'],
      mmProjPath: map['mm_proj_path']?.isEmpty ?? true
          ? null
          : map['mm_proj_path'],
      baseModelsExpanded: map['base_models_expanded'] != '0', // Default true
      visualModelsExpanded: map['visual_models_expanded'] != '0', // Default true
      mmProjModelsExpanded: map['mm_proj_models_expanded'] != '0', // Default true
    );
  }

  AppSettings copyWith({
    String? llamaServerPath,
    double? temperature,
    int? maxTokens,
    String? systemPrompt,
    bool? autoScroll,
    int? fontSize,
    bool? darkMode,
    String? accentColor,
    int? contextWindow,
    String? webSearchApiKey,
    bool? saveHistory,
    int? contextLength,
    bool? enableKvCache,
    int? maxHistoryTokens,
    int? messageWindow,
    int? summaryThreshold,
    bool? enableAutoSummary,
    String? visionModelPath,
    String? mmProjPath,
    bool? baseModelsExpanded,
    bool? visualModelsExpanded,
    bool? mmProjModelsExpanded,
    bool clearVisionModelPath = false,
    bool clearMmProjPath = false,
    bool clearWebSearchApiKey = false,
  }) {
    return AppSettings(
      llamaServerPath: llamaServerPath ?? this.llamaServerPath,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      autoScroll: autoScroll ?? this.autoScroll,
      fontSize: fontSize ?? this.fontSize,
      darkMode: darkMode ?? this.darkMode,
      accentColor: accentColor ?? this.accentColor,
      contextWindow: contextWindow ?? this.contextWindow,
      webSearchApiKey: clearWebSearchApiKey ? null : (webSearchApiKey ?? this.webSearchApiKey),
      saveHistory: saveHistory ?? this.saveHistory,
      contextLength: contextLength ?? this.contextLength,
      enableKvCache: enableKvCache ?? this.enableKvCache,
      maxHistoryTokens: maxHistoryTokens ?? this.maxHistoryTokens,
      messageWindow: messageWindow ?? this.messageWindow,
      summaryThreshold: summaryThreshold ?? this.summaryThreshold,
      enableAutoSummary: enableAutoSummary ?? this.enableAutoSummary,
      visionModelPath: clearVisionModelPath ? null : (visionModelPath ?? this.visionModelPath),
      mmProjPath: clearMmProjPath ? null : (mmProjPath ?? this.mmProjPath),
      baseModelsExpanded: baseModelsExpanded ?? this.baseModelsExpanded,
      visualModelsExpanded: visualModelsExpanded ?? this.visualModelsExpanded,
      mmProjModelsExpanded: mmProjModelsExpanded ?? this.mmProjModelsExpanded,
    );
  }
}
