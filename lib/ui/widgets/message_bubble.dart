import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/chat/message_renderer.dart';
import '../../providers/chat_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../core/app_theme.dart';
import '../utils/attachment_utils.dart';
import '../screens/settings_screen.dart';
import '../components/context_exceeded_modal.dart';

class MessageBubble extends ConsumerStatefulWidget {
  final String? messageId;
  final String content;
  final String? reasoning;
  final bool isUser;
  final bool isStreaming;

  final String? model;
  final double? generationTime;
  final int? tokenCount;
  final int? totalContext;
  final double? tps;
  final VoidCallback? onEdit;
  final List<String>? imagePaths;
  final DateTime? generationStartTime;

  const MessageBubble({
    super.key,
    this.messageId,
    required this.content,
    this.reasoning,
    required this.isUser,
    this.isStreaming = false,
    this.model,
    this.generationTime,
    this.tokenCount,
    this.totalContext,
    this.tps,
    this.onEdit,
    this.imagePaths,
    this.generationStartTime,
    this.documentPaths,
  });

  final List<String>? documentPaths;

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  bool _isEditing = false;
  late TextEditingController _editController;
  late FocusNode _editFocusNode;

  @override
  void initState() {
    super.initState();
    _editController = TextEditingController(text: widget.content);
    _editFocusNode = FocusNode();
    
    // Handle Enter to submit, Shift+Enter for new line
    _editFocusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter;
      final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                             HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

      if (isEnter && !isShiftPressed) {
        _submitEdit();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content && !_isEditing) {
      _editController.text = widget.content;
    }
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  void _submitEdit() {
    if (_editController.text.trim().isNotEmpty && widget.messageId != null) {
      ref.read(chatProvider.notifier).editAndResendMessage(
        widget.messageId!,
        _editController.text,
      );
      setState(() {
        _isEditing = false;
      });
    }
  }

  Widget _buildEditingUI() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _editController,
              focusNode: _editFocusNode,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                fillColor: Colors.transparent,
                hoverColor: Colors.transparent, // Disable hover effect
                filled: true,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintText: 'Edit your prompt...',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isEditing = false;
                      String basePrompt = widget.content;
                      if (basePrompt.contains('---CONTEXT_END---')) {
                        basePrompt = basePrompt.split('---CONTEXT_END---').last.trim();
                      }
                      _editController.text = basePrompt;
                    });
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submitEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) {
        return GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Image content
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Hero(
                      tag: imagePath,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(imagePath),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                // Close button top right
                Positioned(
                  top: 40,
                  right: 40,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 30),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageId = widget.messageId;
    final content = widget.content;
    final reasoning = widget.reasoning;
    final isUser = widget.isUser;
    final isStreaming = widget.isStreaming;

    // Split content to hide injected document context from UI
    String displayContent = content;
    if (content.contains('---CONTEXT_END---')) {
      final parts = content.split('---CONTEXT_END---');
      displayContent = parts.last.trim();
    }

    // If this is an exceed context error, don't show it as a model response in the chat
    if (!isUser && _isExceedContextError(displayContent)) {
      return const SizedBox.shrink();
    }

    if (_isEditing && isUser) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEditingUI(),
            const SizedBox(width: 12),
            _buildAvatar(),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // 1. Attachments Layer (Floating Above)
          if ((widget.imagePaths != null && widget.imagePaths!.isNotEmpty) ||
              (widget.documentPaths != null && widget.documentPaths!.isNotEmpty))
            Padding(
              padding: EdgeInsets.only(
                left: isUser ? 0 : 48,
                right: isUser ? 48 : 0,
                bottom: 8,
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (widget.imagePaths != null && widget.imagePaths!.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.imagePaths!.map((path) {
                        final file = File(path);
                        if (!file.existsSync()) {
                           return Container(
                             width: 160,
                             height: 100,
                             decoration: BoxDecoration(
                               color: Colors.white.withValues(alpha: 0.05),
                               borderRadius: BorderRadius.circular(12),
                               border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                             ),
                             child: Center(
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Icon(Icons.broken_image, color: Colors.white.withValues(alpha: 0.3), size: 24),
                                   const SizedBox(height: 8),
                                   Text('[deleted]', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                                 ],
                               ),
                             ),
                           );
                        }
                        return GestureDetector(
                          onTap: () => _showFullScreenImage(context, path),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                file,
                                width: 160,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  if (widget.documentPaths != null && widget.documentPaths!.isNotEmpty) ...[
                    if (widget.imagePaths != null && widget.imagePaths!.isNotEmpty) const SizedBox(height: 8),
                    ...widget.documentPaths!.map((path) => _buildDocumentCard(path)),
                  ],
                ],
              ),
            ),

          // 2. Avatar + Bubble Interaction Row
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                _buildAvatar(),
                const SizedBox(width: 12),
              ],
              Flexible(
                child: Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isUser ? AppTheme.primary : AppTheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isUser ? 16 : 0),
                          bottomRight: Radius.circular(isUser ? 0 : 16),
                        ),
                        border: Border.all(
                          color: isUser ? AppTheme.primary : Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (reasoning != null && reasoning.isNotEmpty)
                            _ReasoningBox(
                              reasoning: reasoning,
                              isStreaming: isStreaming,
                            ),
                          if (content.isEmpty && !isUser && (reasoning == null || reasoning.isEmpty))
                            _buildTypingIndicator()
                          else if (!isUser && _isExceedContextError(displayContent))
                            _buildContextExceededBanner(context, displayContent)
                          else if (displayContent.isNotEmpty)
                            MessageRenderer(message: displayContent, isUser: isUser),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (!isUser) _buildMetricsBar(context),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isUser && messageId != null) ...[
                          _buildActionButton(
                            context,
                            Icons.copy_rounded,
                            'Copy prompt',
                            () {
                              Clipboard.setData(ClipboardData(text: displayContent));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied prompt to clipboard'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  width: 250,
                                ),
                              );
                            },
                          ),
                          _buildActionButton(
                            context,
                            Icons.edit_rounded,
                            'Edit prompt',
                            () {
                              setState(() {
                                _isEditing = true;
                                _editController.text = displayContent;
                              });
                              Future.delayed(const Duration(milliseconds: 50), () {
                                if (mounted) _editFocusNode.requestFocus();
                              });
                            },
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          isUser ? "You" : "AI Explorer",
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                        ),
                        if (!isUser && !isStreaming && messageId != null) ...[
                          const SizedBox(width: 12),
                          _buildActionButton(
                            context,
                            Icons.copy_rounded,
                            'Copy',
                            () {
                              Clipboard.setData(ClipboardData(text: content));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                  width: 200,
                                ),
                              );
                            },
                          ),
                          _buildActionButton(
                            context,
                            Icons.refresh_rounded,
                            'Regenerate',
                            () => ref.read(chatProvider.notifier).regenerateResponse(messageId),
                          ),
                          _buildActionButton(
                            context,
                            Icons.delete_outline_rounded,
                            'Delete',
                            () => ref.read(chatProvider.notifier).deleteMessage(messageId),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 12),
                _buildAvatar(),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsBar(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final maxContext = settings.contextLength;

    // Detect web search: model field has '+gemini' suffix when web search was used
    final rawModel = widget.model ?? 'Unknown';
    final usedWebSearch = rawModel.endsWith('+gemini');
    final displayModel = usedWebSearch
        ? rawModel.substring(0, rawModel.length - 7)
        : rawModel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          _buildStatTag(Icons.memory, displayModel),
          if (usedWebSearch)
            _buildGeminiTag(),
          _buildStatTag(
            Icons.format_list_numbered,
            '${widget.tokenCount ?? 0} tokens',
          ),
          _buildStatTag(
            Icons.timer_outlined,
            widget.isStreaming && widget.generationStartTime != null
                ? _LiveTimer(startTime: widget.generationStartTime!)
                : Text(
                    '${widget.generationTime?.toStringAsFixed(2) ?? '0.00'}s',
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
          ),
          _buildStatTag(
            Icons.speed,
            '${widget.tps?.toStringAsFixed(2) ?? '0.00'} tok/s',
          ),
          _buildStatTag(
            Icons.donut_large,
            '${widget.totalContext ?? 0}/$maxContext context',
          ),
        ],
      ),
    );
  }

  Widget _buildGeminiTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF4ECDC4).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF4ECDC4).withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search, size: 10, color: Color(0xFF4ECDC4)),
          const SizedBox(width: 4),
          const Text(
            'Gemini API',
            style: TextStyle(
              fontSize: 9,
              color: Color(0xFF4ECDC4),
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTag(IconData icon, dynamic content) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(width: 4),
          if (content is String)
            Text(
              content,
              style: const TextStyle(
                fontSize: 9,
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            )
          else if (content is Widget)
            content,
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Icon(
              icon,
              size: 14,
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: widget.isUser
            ? AppTheme.primary.withValues(alpha: 0.2)
            : AppTheme.secondary.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: widget.isUser ? AppTheme.primary : AppTheme.secondary,
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          widget.isUser ? Icons.person : Icons.psychology,
          size: 18,
          color: widget.isUser ? AppTheme.primary : AppTheme.secondary,
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.secondary,
          ),
        ),
        SizedBox(width: 8),
        Text(
          "AI is thinking...",
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildDocumentCard(String filePath) {
    final fileName = filePath.split(RegExp(r'[/\\]')).last;
    final style = AttachmentStyle.getFromFileName(fileName);

    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: style.baseColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              style.icon,
              color: style.baseColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  style.label,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isExceedContextError(String text) {
    final lower = text.toLowerCase();
    return lower.contains('exceed_context_size_error') ||
        (lower.contains('exceeds the available context size') ||
            (lower.contains('exceed') && lower.contains('context size')));
  }

  Widget _buildContextExceededBanner(BuildContext context, String rawError) {
    // Attempt to extract n_prompt_tokens and n_ctx from message
    int? promptTokens;
    int? currentCtx;

    final match = RegExp(r'request \((\d+) tokens\) exceeds the available context size \((\d+) tokens\)', caseSensitive: false)
        .firstMatch(rawError);
    if (match != null) {
      promptTokens = int.tryParse(match.group(1) ?? '');
      currentCtx = int.tryParse(match.group(2) ?? '');
    } else {
      final pMatch = RegExp(r'"n_prompt_tokens"\s*:\s*(\d+)').firstMatch(rawError);
      final cMatch = RegExp(r'"n_ctx"\s*:\s*(\d+)').firstMatch(rawError);
      if (pMatch != null) promptTokens = int.tryParse(pMatch.group(1) ?? '');
      if (cMatch != null) currentCtx = int.tryParse(cMatch.group(1) ?? '');
    }

    final currentSetting = ref.read(appSettingsProvider).contextLength;
    final activeCtx = currentCtx ?? currentSetting;

    // Recommend next standard power-of-2 context bucket that comfortably fits prompt + generation headroom
    int recommendedCtx;
    final needed = (promptTokens != null) ? (promptTokens + 2048) : (activeCtx * 2);
    if (needed <= 8192) {
      recommendedCtx = 8192;
    } else if (needed <= 12288) {
      recommendedCtx = 12288;
    } else if (needed <= 16384) {
      recommendedCtx = 16384;
    } else if (needed <= 24576) {
      recommendedCtx = 24576;
    } else if (needed <= 32768) {
      recommendedCtx = 32768;
    } else {
      recommendedCtx = 40960;
    }

    if (recommendedCtx <= activeCtx) {
      recommendedCtx = (activeCtx * 2).clamp(512, 40960);
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D1818),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE53935).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6B6B), size: 20),
              const SizedBox(width: 8),
              const Text(
                'Prompt Exceeds Context Length',
                style: TextStyle(
                  color: Color(0xFFFF6B6B),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            promptTokens != null
                ? 'Your prompt with attachments required ~$promptTokens tokens, which exceeds the current limit ($activeCtx tokens).'
                : 'Your prompt and attachments exceeded the current context limit ($activeCtx tokens).',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Color(0xFFFFCA28), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Recommended setting: $recommendedCtx tokens (Settings → AI Behavior).\nImportant: Restart model after changing context length.',
                  style: const TextStyle(
                    color: Color(0xFFFFCA28),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                icon: const Icon(Icons.info_outline_rounded, size: 16),
                label: const Text('View Details', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  showContextExceededModal(
                    context: context,
                    promptTokens: promptTokens,
                    activeCtx: activeCtx,
                    recommendedCtx: recommendedCtx,
                  );
                },
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Open Settings', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const SettingsDialog(initialTabIndex: 1),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasoningBox extends StatefulWidget {
  final String reasoning;
  final bool isStreaming;

  const _ReasoningBox({required this.reasoning, this.isStreaming = false});

  @override
  State<_ReasoningBox> createState() => _ReasoningBoxState();
}

class _ReasoningBoxState extends State<_ReasoningBox> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isStreaming;
  }

  @override
  void didUpdateWidget(_ReasoningBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isStreaming && !oldWidget.isStreaming) {
      _isExpanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 18,
                    color: AppTheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Reasoning",
                    style: TextStyle(
                      color: AppTheme.secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.unfold_more_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                widget.reasoning,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 13,
                  height: 1.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LiveTimer extends StatefulWidget {
  final DateTime startTime;
  const _LiveTimer({required this.startTime});

  @override
  State<_LiveTimer> createState() => _LiveTimerState();
}

class _LiveTimerState extends State<_LiveTimer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _seconds = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((_) {
      final now = DateTime.now();
      final diff = now.difference(widget.startTime).inMilliseconds / 1000.0;
      if (diff.toStringAsFixed(2) != _seconds.toStringAsFixed(2)) {
        setState(() {
          _seconds = diff;
        });
      }
    });
    _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${_seconds.toStringAsFixed(2)}s',
      style: const TextStyle(
        fontSize: 9,
        color: AppTheme.textSecondary,
        fontFamily: 'monospace',
      ),
    );
  }
}
