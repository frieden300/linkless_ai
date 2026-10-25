import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:linkless_ai/core/app_theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../core/services/media_service.dart';
import '../../providers/model_provider.dart';
import '../../providers/server_provider.dart';
import '../../data/models/model_entry.dart';
import '../widgets/model_card.dart';
import '../../providers/chat_provider.dart';

/// Compact modern settings dialog - opens as overlay window
class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // 4 Tabs: Models, AI Behavior, Appearance, Privacy
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 800, // Slightly wider for model cards
        height: 600,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            _buildHeader(),

            // Tab Bar
            _buildTabBar(),

            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  _ModelManagementTab(),
                  _AISettingsTab(),
                  _AppearanceTab(),
                  _PrivacyTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: AppTheme.primary, size: 28),
          const SizedBox(width: 12),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      indicatorColor: AppTheme.primary,
      labelColor: Colors.white,
      unselectedLabelColor: AppTheme.textSecondary,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(text: 'Models'),
        Tab(text: 'AI Behavior'),
        Tab(text: 'Appearance'),
        Tab(text: 'Privacy & Data'),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 1. Model Management Tab (NEW)
// -----------------------------------------------------------------------------
class _ModelManagementTab extends ConsumerWidget {
  const _ModelManagementTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modelState = ref.watch(modelProvider);
    final serverState = ref.watch(serverProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final isModelsLoading =
        modelState.isLoading || serverState.status == ServerStatus.loading;

    final allModels = modelState.models;
    final mmProjModels = allModels.where((m) => m.name.toLowerCase().contains('mmproj') || m.filePath.toLowerCase().contains('mmproj')).toList();
    final visualModels = allModels.where((m) => !mmProjModels.contains(m) && (m.name.toLowerCase().contains('vl') || m.name.toLowerCase().contains('vision') || m.filePath.toLowerCase().contains('vl') || m.filePath.toLowerCase().contains('vision'))).toList();
    final baseModels = allModels.where((m) => !mmProjModels.contains(m) && !visualModels.contains(m)).toList();

    return Column(
      children: [
        if (isModelsLoading)
          const LinearProgressIndicator(
            backgroundColor: Colors.transparent,
            color: AppTheme.accent,
            minHeight: 2,
          ),
        // Upload Button Area
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Installed Models",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  if (serverState.status != ServerStatus.offline)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: TextButton.icon(
                        onPressed: () => ref.read(serverProvider.notifier).stopServer(),
                        icon: const Icon(Icons.stop_rounded, color: Colors.redAccent, size: 20),
                        label: const Text(
                          "Stop Model",
                          style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                        ),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.2)),
                          ),
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
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
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text("Add GGUF Model"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Models List
        Flexible(
          child: allModels.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _buildSection(context, ref, 'Base Models', baseModels, false, null, appSettings.baseModelsExpanded, 'baseModelsExpanded'),
                    const SizedBox(height: 16),
                    _buildSection(context, ref, 'Visual Models', visualModels, true, appSettings.visionModelPath, appSettings.visualModelsExpanded, 'visualModelsExpanded'),
                    const SizedBox(height: 16),
                    _buildSection(context, ref, 'MMProj Models', mmProjModels, true, appSettings.mmProjPath, appSettings.mmProjModelsExpanded, 'mmProjModelsExpanded'),
                    const SizedBox(height: 32),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open,
            size: 60,
            color: AppTheme.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            "No Models Added",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    List<ModelEntry> models,
    bool isSelectable,
    String? selectedPath,
    bool initiallyExpanded,
    String settingsKey,
  ) {
    return Container(
      key: PageStorageKey('$title-section'), // Assist with list preservation
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: (expanded) {
            ref.read(appSettingsProvider.notifier).updateSetting(settingsKey, expanded);
          },
          iconColor: AppTheme.primary,
          collapsedIconColor: AppTheme.textSecondary,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          title: Text(
            '$title (${models.length})',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          children: models.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24, top: 8),
                    child: Center(
                      child: Text(
                        'No $title added.',
                        style: TextStyle(
                          color: AppTheme.textSecondary.withValues(alpha: 0.5),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                ]
              : models.map((m) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ModelCard(
                      model: m,
                      isSelectable: isSelectable,
                      isSelected: isSelectable && selectedPath == m.filePath,
                      onSelect: isSelectable
                          ? () {
                              final isVision = title.contains('Visual');
                              final key = isVision ? 'visionModelPath' : 'mmProjPath';
                              ref.read(appSettingsProvider.notifier).updateSetting(key, m.filePath);
                            }
                          : null,
                    ),
                  );
                }).toList(),
        ),
      ),
    );
  }
}



// -----------------------------------------------------------------------------
// 2. AI Settings Tab
// -----------------------------------------------------------------------------
class _AISettingsTab extends ConsumerStatefulWidget {
  const _AISettingsTab();

  @override
  ConsumerState<_AISettingsTab> createState() => _AISettingsTabState();
}

class _AISettingsTabState extends ConsumerState<_AISettingsTab> {
  late TextEditingController _systemPromptController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(appSettingsProvider);
    _systemPromptController = TextEditingController(text: settings.systemPrompt);
    _apiKeyController = TextEditingController(text: settings.webSearchApiKey ?? '');
  }

  @override
  void dispose() {
    _systemPromptController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);

    // Sync controller if settings change externally, but keep cursor position
    if (_systemPromptController.text != settings.systemPrompt) {
      final selection = _systemPromptController.selection;
      _systemPromptController.text = settings.systemPrompt;
      _systemPromptController.selection = selection;
    }

    final currentApiKey = settings.webSearchApiKey ?? '';
    if (_apiKeyController.text != currentApiKey) {
      final selection = _apiKeyController.selection;
      _apiKeyController.text = currentApiKey;
      _apiKeyController.selection = selection;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // System Prompt
          _buildSection('System Instructions'),
          TextField(
            controller: _systemPromptController,
            maxLines: 3,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Define how the AI should behave...',
              hintStyle: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.5),
              ),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('systemPrompt', value);
            },
          ),
          const SizedBox(height: 24),

          // Gemini API Key
          _buildSection('Gemini API Key (for Web Search)'),
          StatefulBuilder(
            builder: (context, setState) {
              bool isObscure = true;
              return StatefulBuilder(
                builder: (context, setInnerState) {
                  return TextField(
                    controller: _apiKeyController,
                    obscureText: isObscure,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter your Gemini API Key...',
                      hintStyle: TextStyle(
                        color: AppTheme.textSecondary.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isObscure ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textSecondary,
                          size: 18,
                        ),
                        onPressed: () => setInnerState(() => isObscure = !isObscure),
                      ),
                    ),
                    onChanged: (value) {
                      ref.read(appSettingsProvider.notifier).updateSetting(
                        'webSearchApiKey',
                        value.isEmpty ? null : value,
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Required for the Web Search feature. Get a free key at aistudio.google.com.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),
          _buildSection('Model Context Length (Tokens)'),
          _buildCompactSlider(
            value: settings.contextLength.toDouble(),
            min: 512,
            max: 40960,
            label: settings.contextLength.toString(),
            divisions: 79, // (40960-512)/512 approx
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('contextLength', value.round());
            },
          ),
          Text(
            'The total capacity of the AI\'s brain (Input + Output). Requires server restart.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Max History Tokens (NEW)
          _buildSection('Max History Tokens'),
          _buildCompactSlider(
            value: settings.maxHistoryTokens.toDouble(),
            min: 1000,
            max: 32000,
            label: settings.maxHistoryTokens.toString(),
            divisions: 31,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('maxHistoryTokens', value.round());
            },
          ),
          Text(
            'Higher = better memory, slower response.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // Message Window (NEW)
          _buildSection('Recent Message Priority'),
          _buildCompactSlider(
            value: settings.messageWindow.toDouble(),
            min: 5,
            max: 50,
            label: '${settings.messageWindow} messages',
            divisions: 45,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('messageWindow', value.round());
            },
          ),
          Text(
            'Always include this many recent messages, even if tokens are limited.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 24),

          // KV Cache Toggle
          _buildSection('AI Optimization'),
          _buildSwitchTile(
            title: 'KV Cache (Context Memory)',
            subtitle: settings.enableKvCache
                ? 'Enabled - Reuses previous context for faster responses'
                : 'Disabled - Fresh inference every time',
            value: settings.enableKvCache,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('enableKvCache', value);
            },
          ),
          const SizedBox(height: 16),

          // Auto Summary Toggle
          _buildSwitchTile(
            title: 'Auto-Summarization',
            subtitle: settings.enableAutoSummary
                ? 'Enabled - Compresses old messages to save context'
                : 'Disabled - No automatic summarization',
            value: settings.enableAutoSummary,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('enableAutoSummary', value);
            },
          ),
          const SizedBox(height: 24),

          // Summary Threshold
          _buildSection('Summary Threshold'),
          _buildCompactSlider(
            value: settings.summaryThreshold.toDouble(),
            min: 1000,
            max: 16000,
            label: settings.summaryThreshold.toString(),
            divisions: 30,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('summaryThreshold', value.round());
            },
          ),
          Text(
            'When conversation exceeds this many tokens, older messages are auto-summarized.',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCompactSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Appearance Tab
// -----------------------------------------------------------------------------
class _AppearanceTab extends ConsumerWidget {
  const _AppearanceTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dark Mode
          _buildSwitchTile(
            title: 'Dark Mode',
            subtitle: 'Use dark theme',
            value: settings.darkMode,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('darkMode', value);
            },
          ),
          const SizedBox(height: 16),

          // Auto Scroll
          _buildSwitchTile(
            title: 'Auto-scroll',
            subtitle: 'Automatically scroll to new messages',
            value: settings.autoScroll,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('autoScroll', value);
            },
          ),
          const SizedBox(height: 24),

          // Font Size
          _buildSection('Message Font Size'),
          _buildCompactSlider(
            value: settings.fontSize.toDouble(),
            min: 12,
            max: 20,
            label: '${settings.fontSize}pt',
            divisions: 8,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('fontSize', value.round());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCompactSlider({
    required double value,
    required double min,
    required double max,
    required String label,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 60,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4. Privacy & Data Tab
// -----------------------------------------------------------------------------
class _PrivacyTab extends ConsumerWidget {
  const _PrivacyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Save History
          _buildSwitchTile(
            title: 'Save Conversation History',
            subtitle: 'Store chats in local database',
            value: settings.saveHistory,
            onChanged: (value) {
              ref
                  .read(appSettingsProvider.notifier)
                  .updateSetting('saveHistory', value);
            },
          ),
          const SizedBox(height: 24),

          // Clear History Button
          _buildSection('Data Management'),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete_sweep, size: 18),
            label: const Text('Clear All History'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withValues(alpha: 0.2),
              foregroundColor: Colors.redAccent,
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showClearHistoryDialog(context, ref),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.image_not_supported_outlined, size: 18),
            label: const Text('Clear Image Cache'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.withValues(alpha: 0.2),
              foregroundColor: Colors.orangeAccent,
              minimumSize: const Size(double.infinity, 50),
              side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _showClearImagesDialog(context, ref),
          ),
        ],
      ),
    );
  }


  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Clear All History?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will permanently delete all conversations. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(chatProvider.notifier).clearAllHistory();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showClearImagesDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text(
          'Clear Image Cache?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all image copies stored by the app. Missing images will show as [deleted] in the chat UI. This action cannot be undone.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await MediaService.clearAllImages();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Image cache cleared successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
            child: const Text('Clear Images'),
          ),
        ],
      ),
    );
  }
}
