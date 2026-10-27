import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../data/models/model_entry.dart';
import '../data/repositories/model_repository.dart';
import 'providers.dart';
import 'server_provider.dart';
import 'settings_provider.dart';

class ModelState {
  final List<ModelEntry> models;
  final String? loadedModelId;
  final bool isLoading;

  ModelState({
    required this.models,
    this.loadedModelId,
    this.isLoading = false,
  });

  ModelState copyWith({
    List<ModelEntry>? models,
    String? loadedModelId,
    bool? isLoading,
    bool forceClearLoadedModelId = false,
  }) {
    return ModelState(
      models: models ?? this.models,
      loadedModelId: forceClearLoadedModelId
          ? null
          : (loadedModelId ?? this.loadedModelId),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ModelNotifier extends StateNotifier<ModelState> {
  final ModelRepository _repo;
  final Ref _ref;

  ModelNotifier(this._repo, this._ref) : super(ModelState(models: [])) {
    _init();
  }

  Future<void> _init() async {
    await loadModels();
    await _scanLocalModelsOnStartup();
  }

  Future<void> _scanLocalModelsOnStartup() async {
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      Directory modelDir = Directory(p.join(exeDir, 'models'));

      if (!await modelDir.exists()) {
        final cwdModels = Directory(p.join(Directory.current.path, 'models'));
        if (await cwdModels.exists()) {
          modelDir = cwdModels;
        } else {
          final devModels = Directory(p.normalize(p.join(exeDir, '..', '..', '..', '..', '..', 'models')));
          if (await devModels.exists()) {
            modelDir = devModels;
          }
        }
      }
      
      if (!await modelDir.exists()) return;
      
      final currentModels = state.models.map((m) => p.basename(m.filePath)).toSet();
      bool addedAny = false;
      
      final entities = await modelDir.list().toList();
      for (final entity in entities) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
          final fileName = p.basename(entity.path);
          if (!currentModels.contains(fileName)) {
            final id = const Uuid().v4();
            final model = ModelEntry.fromFilePath(entity.path, id);
            await _repo.addModel(model);
            addedAny = true;
          }
        }
      }
      
      if (addedAny) {
        await loadModels();
      }
    } catch (e) {
      debugPrint('Error scanning local models: $e');
    }
  }

  Future<void> loadModels() async {
    state = state.copyWith(isLoading: true);
    try {
      final models = await _repo.getModels();
      state = ModelState(models: models, loadedModelId: state.loadedModelId);
    } catch (e) {
      debugPrint('Error loading models: $e');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> addModelFromFile(String filePath) async {
    final id = const Uuid().v4();
    final model = ModelEntry.fromFilePath(filePath, id);
    await _repo.addModel(model);
    await loadModels();
  }

  Future<void> updateModel(ModelEntry model) async {
    await _repo.updateModel(model);
    await loadModels();
  }

  Future<void> deleteModel(String id) async {
    // Stop server if this model is currently loaded
    if (state.loadedModelId == id) {
      await _ref.read(serverProvider.notifier).stopServer();
      state = state.copyWith(forceClearLoadedModelId: true);
    }

    await _repo.deleteModel(id);
    await loadModels();
  }

  Future<void> loadModel(String modelId) async {
    final model = await _repo.getModelById(modelId);
    if (model == null) {
      debugPrint('Model not found: $modelId');
      return;
    }

    // Start server with this model
    await _ref
        .read(serverProvider.notifier)
        .startServerWithModel(model.filePath);

    // Save to settings to remember as the last used model
    await _ref.read(settingsProvider.notifier).setModelPath(model.filePath);

    // Update loaded model ID
    state = state.copyWith(loadedModelId: modelId);
  }

  Future<void> unloadModel() async {
    await _ref.read(serverProvider.notifier).stopServer();
    state = state.copyWith(forceClearLoadedModelId: true);
  }

  void setLoadedModel(String? modelId) {
    if (state.loadedModelId != modelId) {
      state = state.copyWith(loadedModelId: modelId, forceClearLoadedModelId: modelId == null);
    }
  }

  ModelEntry? get loadedModel {
    if (state.loadedModelId == null) return null;
    return state.models.firstWhere(
      (m) => m.id == state.loadedModelId,
      orElse: () => state.models.first,
    );
  }
}

final modelProvider = StateNotifierProvider<ModelNotifier, ModelState>((ref) {
  return ModelNotifier(ref.watch(modelRepositoryProvider), ref);
});
