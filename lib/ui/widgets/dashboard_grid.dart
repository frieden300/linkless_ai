import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/models/chat_action.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/chat_provider.dart';
import '../components/api_key_modal.dart';

/// Dashboard grid shown on new/empty chats
class DashboardGrid extends ConsumerWidget {
  final VoidCallback onPickDocument;
  final VoidCallback onPickImages;

  const DashboardGrid({
    super.key,
    required this.onPickDocument,
    required this.onPickImages,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology, size: 56, color: AppTheme.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'What can I help you with?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 800),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                        itemCount: defaultChatActions.length,
                        itemBuilder: (context, index) {
                          return _DashboardActionCard(
                            action: defaultChatActions[index],
                            onTap: () async {
                              final id = defaultChatActions[index].id;
                              if (id == 'upload_document') {
                                onPickDocument();
                              } else if (id == 'upload_image') {
                                onPickImages();
                              } else if (id == 'web_search') {
                                // Check for API key before enabling web search
                                final apiKey = ref
                                    .read(appSettingsProvider)
                                    .webSearchApiKey;
                                if (apiKey == null || apiKey.isEmpty) {
                                  final saved = await showApiKeyModal(
                                    context,
                                    ref,
                                  );
                                  if (!saved) return; // User cancelled
                                }
                              }
                              ref.read(chatProvider.notifier).toggleTool(id);
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardActionCard extends StatefulWidget {
  final ChatAction action;
  final VoidCallback onTap;

  const _DashboardActionCard({required this.action, required this.onTap});

  @override
  State<_DashboardActionCard> createState() => _DashboardActionCardState();
}

class _DashboardActionCardState extends State<_DashboardActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: _isHovered
                ? widget.action.color.withValues(alpha: 0.15)
                : AppTheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isHovered
                  ? widget.action.color.withValues(alpha: 0.5)
                  : Colors.white.withValues(alpha: 0.1),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.action.icon,
                size: 40,
                color: _isHovered ? widget.action.color : Colors.white,
              ),
              const SizedBox(height: 12),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: _isHovered ? widget.action.color : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                widget.action.subtitle,
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

