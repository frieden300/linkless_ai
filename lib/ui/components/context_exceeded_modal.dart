import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/server_provider.dart';
import '../screens/settings_screen.dart';

/// Shows a floating modal dialog when the prompt exceeds the model's context size.
Future<void> showContextExceededModal({
  required BuildContext context,
  required int? promptTokens,
  required int activeCtx,
  required int recommendedCtx,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _ContextExceededModal(
      promptTokens: promptTokens,
      activeCtx: activeCtx,
      recommendedCtx: recommendedCtx,
    ),
  );
}

class _ContextExceededModal extends ConsumerStatefulWidget {
  final int? promptTokens;
  final int activeCtx;
  final int recommendedCtx;

  const _ContextExceededModal({
    required this.promptTokens,
    required this.activeCtx,
    required this.recommendedCtx,
  });

  @override
  ConsumerState<_ContextExceededModal> createState() => _ContextExceededModalState();
}

class _ContextExceededModalState extends ConsumerState<_ContextExceededModal> {
  bool _isApplying = false;

  Future<void> _applyAndRestart() async {
    setState(() => _isApplying = true);
    try {
      // 1. Update context length in settings
      await ref
          .read(appSettingsProvider.notifier)
          .updateSetting('contextLength', widget.recommendedCtx);

      // 2. Restart server
      await ref.read(serverProvider.notifier).restartServer();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Context length updated to ${widget.recommendedCtx} and model restarted.',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to restart model: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 520,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 40,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFFF6B6B),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Prompt Exceeds Context Length',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Model requires a larger context window',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTheme.textSecondary.withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Info Box
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: Colors.amber, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.promptTokens != null
                                ? 'Your prompt with attachments required ~${widget.promptTokens} tokens, which exceeds the current limit (${widget.activeCtx} tokens).'
                                : 'Your prompt with attachments exceeded the model context limit (${widget.activeCtx} tokens).',
                            style: TextStyle(
                              color: Colors.amber.withValues(alpha: 0.95),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Recommendation & Restart Notice
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lightbulb_outline, color: Color(0xFF4ECDC4), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Recommended size: ${widget.recommendedCtx} tokens',
                                style: const TextStyle(
                                  color: Color(0xFF4ECDC4),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'You can apply the recommended context size and restart the model immediately, or adjust it manually in Settings.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isApplying ? null : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: AppTheme.textSecondary,
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _isApplying
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                showDialog(
                                  context: context,
                                  builder: (_) => const SettingsDialog(initialTabIndex: 1),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        icon: const Icon(Icons.tune_rounded, size: 16),
                        label: const Text('Open Settings'),
                      ),
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: _isApplying ? null : _applyAndRestart,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        icon: _isApplying
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.restart_alt_rounded, size: 16),
                        label: Text(_isApplying ? 'Restarting...' : 'Apply & Restart'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
