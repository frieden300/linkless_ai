import 'dart:io';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../data/services/llama_service.dart';
import '../data/models/app_settings.dart';
import 'settings_provider.dart';
import 'app_settings_provider.dart';
import 'model_provider.dart';

enum ServerStatus { offline, starting, loading, online, stopping, error }

class ServerState {
  final ServerStatus status;
  final String? errorMessage;
  final String? activeModelPath;
  final ModelMode currentMode;

  const ServerState({
    this.status = ServerStatus.offline,
    this.errorMessage,
    this.activeModelPath,
    this.currentMode = ModelMode.fast,
  });

  ServerState copyWith({
    ServerStatus? status,
    String? errorMessage,
    String? activeModelPath,
    ModelMode? currentMode,
  }) {
    return ServerState(
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      activeModelPath: activeModelPath ?? this.activeModelPath,
      currentMode: currentMode ?? this.currentMode,
    );
  }
}

class ServerNotifier extends StateNotifier<ServerState> {
  final Ref _ref;
  Process? _process;
  int? _processPid; // Track PID for force kill
  Timer? _healthCheckTimer;

  ServerNotifier(this._ref) : super(const ServerState()) {
    // Start periodic health check
    _healthCheckTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => checkServerStatus(),
    );
    checkServerStatus();
  }

  Future<void> checkServerStatus() async {
    final settings = _ref.read(settingsProvider);
    final service = LlamaService(baseUrl: settings.serverUrl);

    final isOnline = await service.checkHealth();

    if (isOnline) {
      if (state.status != ServerStatus.online) {
        // App just started, hot restarted, or reconnected
        final runningModels = await service.getModels();
        if (runningModels.isNotEmpty) {
          final modelName = runningModels.first;
          final modelState = _ref.read(modelProvider);
          final modelNotifier = _ref.read(modelProvider.notifier);

          // Find match by filename, direct ID, or path snippet
          String? foundModelId;
          String? foundModelPath;

          for (final m in modelState.models) {
            final fileName = p.basename(m.filePath);
            if (fileName == modelName || 
                m.id == modelName || 
                m.name == modelName ||
                m.filePath.contains(modelName)) {
              foundModelId = m.id;
              foundModelPath = m.filePath;
              break;
            }
          }

          if (foundModelId != null) {
            modelNotifier.setLoadedModel(foundModelId);
            state = state.copyWith(
              status: ServerStatus.online,
              activeModelPath: foundModelPath,
            );
            return;
          }
        }
        state = state.copyWith(status: ServerStatus.online);
      }
    } else {
      if (state.status == ServerStatus.online) {
        state = state.copyWith(status: ServerStatus.offline);
        _ref.read(modelProvider.notifier).setLoadedModel(null);
      }
    }
  }

  Future<void> startServer() async {
    if (state.status == ServerStatus.online ||
        state.status == ServerStatus.starting ||
        state.status == ServerStatus.loading) {
      return;
    }

    final settings = _ref.read(settingsProvider);
    var modelPath = settings.modelPath;

    // Fallback if settings.modelPath is not configured but a model exists
    if (modelPath == null || modelPath.isEmpty) {
      final modelState = _ref.read(modelProvider);
      if (modelState.models.isNotEmpty) {
        modelPath = modelState.models.first.filePath;
      }
    }

    if (modelPath == null || modelPath.isEmpty) {
      state = const ServerState(
        status: ServerStatus.error,
        errorMessage: "Model path not configured",
      );
      return;
    }

    if (!File(modelPath).existsSync()) {
      state = const ServerState(
        status: ServerStatus.error,
        errorMessage: "Model file not found",
      );
      return;
    }

    await startServerWithModel(modelPath);
  }

  /// Restarts the active server (either vision or text model) with updated settings
  Future<void> restartServer() async {
    final activePath = state.activeModelPath;
    final isVision = state.currentMode == ModelMode.vision;
    await stopServer(skipOfflineReset: true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (isVision) {
      await startVisionServer();
    } else if (activePath != null && activePath.isNotEmpty && File(activePath).existsSync()) {
      await startServerWithModel(activePath);
    } else {
      await startServer();
    }
  }

  /// Stop server with graceful termination + force kill fallback
  Future<void> stopServer({bool skipOfflineReset = false}) async {
    debugPrint('Stopping model/server...');
    // Enter stopping state to provide feedback
    state = state.copyWith(status: ServerStatus.stopping);

    // Step 1: Try graceful termination of the registered process handle
    if (_process != null) {
      try {
        _process!.kill(ProcessSignal.sigterm);
        debugPrint('Sent SIGTERM to process');
      } catch (e) {
        debugPrint('SIGTERM failed: $e');
      }
      await Future.delayed(const Duration(seconds: 1));
    }

    // Step 2: Force kill tracked PID
    if (_processPid != null) {
      try {
        if (Platform.isWindows) {
          await Process.run('taskkill', ['/F', '/T', '/PID', _processPid.toString()], runInShell: true);
        } else {
          _process?.kill(ProcessSignal.sigkill);
        }
      } catch (_) {}
    }

    // Step 3: Global cleanup (Backup for Hot Restart / dangling processes)
    // This solves the issue where server is running but app doesn't have the handle anymore
    try {
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/IM', 'llama-server.exe'], runInShell: true);
      } else {
        await Process.run('pkill', ['-f', 'llama-server']);
      }
      debugPrint('Performed global llama-server cleanup');
    } catch (e) {
      debugPrint('Global cleanup finished with error (usually means nothing found): $e');
    }

    // Step 4: Reset state
    _process = null;
    _processPid = null;
    if (!skipOfflineReset) {
      state = const ServerState(status: ServerStatus.offline);
      _ref.read(modelProvider.notifier).setLoadedModel(null);
    }
  }

  /// Force stop server immediately (sync) for app exit
  void stopServerImmediate() {
    debugPrint('Stopping model/server (IMMEDIATE)...');
    // 1. Direct kill of tracked handle
    _process?.kill(ProcessSignal.sigkill);
    
    // Resolve taskkill path dynamically from SystemRoot or fallback to taskkill
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final taskkillPath = p.join(systemRoot, 'System32', 'taskkill.exe');
    final taskkillCmd = File(taskkillPath).existsSync() ? taskkillPath : 'taskkill';

    // 2. Process-tree kill via PID (most specific)
    if (_processPid != null) {
      try {
        if (Platform.isWindows) {
          Process.runSync(taskkillCmd, ['/F', '/T', '/PID', _processPid.toString()], runInShell: taskkillCmd == 'taskkill');
        } else {
          _process?.kill(ProcessSignal.sigkill);
        }
      } catch (_) {}
    }

    // 3. Global backup kill by name (catches orphans)
    try {
      if (Platform.isWindows) {
        Process.runSync(taskkillCmd, ['/F', '/T', '/IM', 'llama-server.exe'], runInShell: taskkillCmd == 'taskkill');
      }
    } catch (_) {}

    _process = null;
    _processPid = null;
  }

  Future<void> startServerWithModel(String modelPath) async {
    debugPrint('Starting server with model: $modelPath');
    
    // Set starting state immediately so button shows and doesn't flicker
    state = ServerState(
      status: ServerStatus.starting,
      activeModelPath: modelPath,
    );

    await stopServer(skipOfflineReset: true);
    await Future.delayed(const Duration(milliseconds: 500));

    // Ensure we are STILL in starting state with the correct path
    state = ServerState(
      status: ServerStatus.starting,
      activeModelPath: modelPath,
    );

    try {
      final appSettings = _ref.read(appSettingsProvider);
      final contextLength = appSettings.contextLength.toString();
      final serverExe = appSettings.llamaServerPath;
      final serverDir = p.dirname(serverExe);

      if (!File(serverExe).existsSync()) {
        final err = 'llama-server executable not found at: $serverExe';
        debugPrint('[Server] Error: $err');
        state = ServerState(
          status: ServerStatus.error,
          errorMessage: err,
        );
        return;
      }

      _process = await Process.start(
        serverExe,
        ['-m', modelPath, '-ngl', '999', '-c', contextLength, '--port', '8080'],
        workingDirectory: serverDir,
        runInShell: false,
      );

      _processPid = _process!.pid;
      _process!.stdout.listen((data) => debugPrint('Server: ${String.fromCharCodes(data)}'));
      _process!.stderr.listen((data) => debugPrint('Server Error: ${String.fromCharCodes(data)}'));

      final settings = _ref.read(settingsProvider);
      final service = LlamaService(baseUrl: settings.serverUrl);

      for (int i = 0; i < 90; i++) {
        await Future.delayed(const Duration(seconds: 1));
        try {
          final isOnline = await service.checkHealth();
          if (isOnline) {
            debugPrint('Server ready after ${i + 1}s');
            // One final check to map state correctly
            await checkServerStatus();
            return;
          }
        } catch (_) {}
      }

      state = ServerState(
        status: ServerStatus.error,
        errorMessage: 'Server timed out (90s).',
      );
    } catch (e) {
      debugPrint('[Server] Failed to start server: $e');
      state = ServerState(
        status: ServerStatus.error,
        errorMessage: 'Failed to start server: $e',
      );
    }
  }

  /// Start the vision-capable llama-server using the configured VL model + mmproj.
  /// Stops any running server first, then waits for the new server to be fully ready.
  Future<void> startVisionServer() async {
    final appSettings = _ref.read(appSettingsProvider);
    final visionPath = appSettings.visionModelPath;
    final mmProjPath = appSettings.mmProjPath;

    // --- Validate paths ---
    if (visionPath == null || visionPath.isEmpty) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Vision model not selected. Go to Settings → Models and select a Visual Model.',
      );
      return;
    }
    if (mmProjPath == null || mmProjPath.isEmpty) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'MMProj model not selected. Go to Settings → Models and select an MMProj Model.',
      );
      return;
    }
    if (!File(visionPath).existsSync()) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Vision model file not found: $visionPath',
      );
      return;
    }
    if (!File(mmProjPath).existsSync()) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'MMProj file not found: $mmProjPath',
      );
      return;
    }

    // --- Stop existing server ---
    state = ServerState(
      status: ServerStatus.starting,
      activeModelPath: visionPath,
      currentMode: ModelMode.vision,
    );

    await stopServer(skipOfflineReset: true);
    await Future.delayed(const Duration(milliseconds: 800));

    // Restore starting state (stopServer may have touched it)
    state = ServerState(
      status: ServerStatus.starting,
      activeModelPath: visionPath,
      currentMode: ModelMode.vision,
    );

    // --- Launch llama-server ---
    try {
      int ctx = appSettings.contextLength;
      if (ctx < 8192) ctx = 8192;

      final serverExe = appSettings.llamaServerPath;
      final serverDir = p.dirname(serverExe);

      if (!File(serverExe).existsSync()) {
        final err = 'llama-server executable not found at: $serverExe';
        debugPrint('[Vision] Error: $err');
        state = state.copyWith(
          status: ServerStatus.error,
          errorMessage: err,
        );
        return;
      }

      debugPrint('[Vision] Starting vision server: $serverExe');
      debugPrint('[Vision]   model   : $visionPath');
      debugPrint('[Vision]   mmproj  : $mmProjPath');
      debugPrint('[Vision]   context : $ctx');

      _process = await Process.start(
        serverExe,
        [
          '-m', visionPath,
          '--mmproj', mmProjPath,
          '-ngl', '999',
          '-c', ctx.toString(),
          '--port', '8080',
          '--host', '0.0.0.0',
        ],
        workingDirectory: serverDir,
        runInShell: false,
      );
      _processPid = _process!.pid;

      _process!.stdout.listen((d) => debugPrint('[VL] ${String.fromCharCodes(d)}'));
      _process!.stderr.listen((d) => debugPrint('[VL-err] ${String.fromCharCodes(d)}'));
    } catch (e) {
      state = state.copyWith(
        status: ServerStatus.error,
        errorMessage: 'Failed to start vision server process: $e',
      );
      return;
    }

    // --- Wait for server to be fully ready ---
    // Poll /health every 1 second for up to 90 seconds.
    // Only accept "status":"ok" (not just HTTP 200) so we know warmup is done.
    final settings = _ref.read(settingsProvider);
    final service = LlamaService(baseUrl: settings.serverUrl);

    for (int i = 0; i < 90; i++) {
      await Future.delayed(const Duration(seconds: 1));
      try {
        final ready = await service.checkHealthReady();
        if (ready) {
          debugPrint('[Vision] Server ready after ${i + 1}s');
          state = state.copyWith(status: ServerStatus.online);
          return;
        }
      } catch (_) {}
    }

    state = state.copyWith(
      status: ServerStatus.error,
      errorMessage: 'Vision server timed out (90s). Check that llama-server supports multimodal.',
    );
  }

  @override
  void dispose() {
    _healthCheckTimer?.cancel();
    super.dispose();
  }
}

final serverProvider = StateNotifierProvider<ServerNotifier, ServerState>((ref) {
  return ServerNotifier(ref);
});
