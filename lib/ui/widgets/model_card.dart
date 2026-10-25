import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import '../../core/app_theme.dart';
import '../../data/models/model_entry.dart';
import '../../providers/model_provider.dart';
import '../../providers/server_provider.dart';

class ModelCard extends ConsumerWidget {
  final ModelEntry model;
  final bool isSelectable;
  final bool isSelected;
  final VoidCallback? onSelect;

  const ModelCard({
    super.key,
    required this.model,
    this.isSelectable = false,
    this.isSelected = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loadedModelId = ref.watch(modelProvider).loadedModelId;
    final isLoaded = loadedModelId == model.id;
    final serverState = ref.watch(serverProvider);
    final isActiveModel = serverState.activeModelPath == model.filePath;
    final bool isHighlighted = isSelectable ? isSelected : isLoaded;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isHighlighted
            ? AppTheme.primary.withValues(alpha: 0.1)
            : AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primary.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Model Name
          Row(
            children: [
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isHighlighted)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isSelectable ? 'SELECTED' : 'LOADED',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Tags/Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (model.sizeParam != null) _buildChip(model.sizeParam!),
              if (model.quantization != null) _buildChip(model.quantization!),
              if (model.fileSizeMb != null)
                _buildChip(
                  '${(model.fileSizeMb! / 1024).toStringAsFixed(2)} GB',
                ),
              if (model.modelFamily != null) _buildChip(model.modelFamily!),
              _buildChip(model.storageType),
            ],
          ),

          const SizedBox(height: 12),

          // Metadata
          Text(
            'Context Length: ${model.contextLength}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'File: ${path.basename(model.filePath)}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          if (isActiveModel &&
              (serverState.status == ServerStatus.starting ||
                  serverState.status == ServerStatus.loading ||
                  serverState.status == ServerStatus.stopping))
            Column(
              children: [
                const LinearProgressIndicator(
                  backgroundColor: Colors.transparent,
                  color: AppTheme.accent,
                  minHeight: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  ref.watch(serverProvider).status == ServerStatus.stopping
                      ? 'Stopping model...'
                      : 'Loading model...',
                  style: const TextStyle(
                    color: AppTheme.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Edit
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppTheme.textSecondary,
                ),
                tooltip: "Edit Model",
                onPressed: () => _showEditDialog(context, ref),
              ),

              // Delete
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                tooltip: "Delete Model",
                onPressed: () => _confirmDelete(context, ref),
              ),

              // Select or Play/Stop
              if (isSelectable)
                Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.accent.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? AppTheme.accent
                          : AppTheme.textSecondary,
                      size: 32,
                    ),
                    tooltip: isSelected ? "Selected" : "Select Model",
                    onPressed: onSelect,
                  ),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: isLoaded
                        ? Colors.redAccent.withValues(alpha: 0.2)
                        : AppTheme.accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      isLoaded
                          ? Icons.stop_circle_outlined
                          : Icons.play_circle_outline,
                      color: isLoaded ? Colors.redAccent : AppTheme.accent,
                      size: 36,
                    ),
                    tooltip: isLoaded ? "Stop Model" : "Load Model",
                    onPressed: () async {
                      if (isLoaded) {
                        await ref.read(modelProvider.notifier).unloadModel();
                      } else {
                        await ref
                            .read(modelProvider.notifier)
                            .loadModel(model.id);
                      }
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: model.name);
    final contextController = TextEditingController(
      text: model.contextLength.toString(),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Edit Model', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Model Name',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: contextController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Context Length',
                labelStyle: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedModel = model.copyWith(
                name: nameController.text,
                contextLength:
                    int.tryParse(contextController.text) ?? model.contextLength,
              );
              ref.read(modelProvider.notifier).updateModel(updatedModel);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Delete Model?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${model.name}"?',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(modelProvider.notifier).deleteModel(model.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
