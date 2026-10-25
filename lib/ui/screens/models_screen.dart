import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/app_theme.dart';
import '../../providers/model_provider.dart';
import '../../providers/server_provider.dart';
import '../widgets/model_card.dart';

class ModelsScreen extends ConsumerWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.sidebarBackground,
        title: const Text("Models", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Add Model button
          IconButton(
            icon: const Icon(Icons.note_add_outlined, color: AppTheme.accent),
            tooltip: "Add Model",
            onPressed: () async {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['gguf'],
                dialogTitle: 'Select GGUF Model',
              );
              if (result != null && result.files.single.path != null) {
                await ref
                    .read(modelProvider.notifier)
                    .addModelFromFile(result.files.single.path!);
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Model Loaded Indicator
          _buildLoadedModelIndicator(context, ref, modelState),

          // Model Cards List
          Expanded(
            child: modelState.models.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: modelState.models.length,
                    itemBuilder: (context, index) {
                      return ModelCard(model: modelState.models[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedModelIndicator(
    BuildContext context,
    WidgetRef ref,
    ModelState modelState,
  ) {
    final loadedModel = ref.watch(modelProvider.notifier).loadedModel;
    final serverStatus = ref.watch(serverProvider).status;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(
            serverStatus == ServerStatus.online
                ? Icons.check_circle
                : Icons.circle_outlined,
            color: serverStatus == ServerStatus.online
                ? AppTheme.accent
                : AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loadedModel != null
                  ? 'Model Loaded: ${loadedModel.name}'
                  : 'No Model Loaded',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 80,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 24),
          Text(
            "No Models Added",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Click the + icon to add a .gguf model",
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
