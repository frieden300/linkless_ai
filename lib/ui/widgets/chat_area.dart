import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../core/app_theme.dart';
import '../../core/models/attachment.dart';
import '../../providers/app_settings_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/server_provider.dart';
import '../../providers/speech_provider.dart';
import '../../core/models/chat_action.dart';
import 'dashboard_grid.dart';
import 'file_preview_bar.dart';
import 'message_bubble.dart';
import '../../core/services/media_service.dart';
import '../../core/services/file_extraction_service.dart';
import 'voice_waveform.dart';
import '../components/api_key_modal.dart';

class ChatArea extends ConsumerStatefulWidget {
  const ChatArea({super.key});

  @override
  ConsumerState<ChatArea> createState() => _ChatAreaState();
}

class _ChatAreaState extends ConsumerState<ChatArea> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final FocusNode _areaFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter;
      final isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
                             HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

      if (isEnter && !isShiftPressed) {
        _sendMessage();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _areaFocusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final chatState = ref.read(chatProvider);
    if (chatState.isGenerating) return;

    if (_controller.text.trim().isNotEmpty) {
      // If web search is active, check for API key first
      if (chatState.selectedTools.contains('web_search')) {
        final apiKey = ref.read(appSettingsProvider).webSearchApiKey;
        if (apiKey == null || apiKey.isEmpty) {
          showApiKeyModal(context, ref).then((saved) {
            if (saved && mounted) {
              // Retry send after key is saved
              ref.read(chatProvider.notifier).sendMessage(_controller.text);
              _controller.clear();
              setState(() {});
              _focusNode.requestFocus();
            }
          });
          return;
        }
      }

      ref.read(chatProvider.notifier).sendMessage(_controller.text);
      _controller.clear();
      setState(() {});

      // Request focus again so typing can continue
      _focusNode.requestFocus();

      // Scroll to bottom (offset 0 for reversed ListView)
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  /// Open image file picker and add images as attachments
  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) {
      // If user cancelled and we have no images, remove the chip
      final current = ref.read(chatProvider).attachments;
      if (!current.any((a) => a.isImage)) {
        ref.read(chatProvider.notifier).removeToolOnly('upload_image');
      }
      return;
    }
    for (final file in result.files) {
      if (file.path == null) continue;

      String internalPath;
      try {
        internalPath = await MediaService.persistImage(file.path!);
      } catch (e) {
        debugPrint("Error persisting image: $e");
        internalPath = file.path!; // Fallback to original
      }

      ref.read(chatProvider.notifier).addAttachment(
        Attachment(
          filePath: internalPath,
          type: AttachmentType.image,
          fileName: file.name,
        ),
      );
    }
  }

  /// Open document picker, add extracting attachment, then extract text
  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'docx', 'xlsx', 'xls', 'epub', 'csv', 
        'txt', 'dart', 'py', 'json', 'html', 'md', 'xml',
        'js', 'ts', 'cpp', 'h', 'hpp', 'c', 'cs', 'java', 'kt',
        'sh', 'bash', 'yml', 'yaml', 'rb', 'go', 'rs', 'sql'
      ],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) {
      // If user cancelled and we have no documents, remove the chip
      final current = ref.read(chatProvider).attachments;
      if (!current.any((a) => a.isDocument)) {
        ref.read(chatProvider.notifier).removeToolOnly('upload_document');
      }
      return;
    }

    for (final file in result.files) {
      _handleDocumentFile(file);
    }
  }

  Future<void> _handleDocumentFile(PlatformFile file) async {
    if (file.path == null) return;

    // 1. Immediately add attachment in "extracting" state
    final initialAttachment = Attachment(
      filePath: file.path!,
      type: AttachmentType.document,
      fileName: file.name,
      isExtracting: true,
    );
    ref.read(chatProvider.notifier).addAttachment(initialAttachment);

    // 2. Perform extraction in the background
    final extractedText = await FileExtractionService.extractText(File(file.path!));

    // 3. Update the attachment with the result
    if (mounted) {
      final completedAttachment = initialAttachment.copyWith(
        extractedText: extractedText,
        isExtracting: false,
      );
      
      // Check if the attachment was removed by user while extracting before updating
      final currentAttachments = ref.read(chatProvider).attachments;
      if (currentAttachments.contains(initialAttachment)) {
        ref.read(chatProvider.notifier).updateAttachment(initialAttachment, completedAttachment);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final serverState = ref.watch(serverProvider);

    // Show dashboard only if no messages AND not generating
    final showDashboard =
        chatState.activeMessages.isEmpty && chatState.streamingContent.isEmpty;

    final allItemsCount =
        chatState.activeMessages.length + (chatState.isGenerating ? 1 : 0);

    return Focus(
      focusNode: _areaFocusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && node.hasPrimaryFocus) {
          final char = event.character;
          // Capture printable characters (excluding single spaces if nothing else is typed)
          if (char != null && char.trim().isNotEmpty) {
            _focusNode.requestFocus();
            _controller.text += char;
            _controller.selection =
                TextSelection.collapsed(offset: _controller.text.length);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Column(
      children: [
        // Chat History / Dashboard
        Expanded(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                child: showDashboard
                    ? DashboardGrid(
                        key: const ValueKey('dashboard'),
                        onPickDocument: _pickDocument,
                        onPickImages: _pickImages,
                      )
                    : SelectionArea(
                        child: ListView.builder(
                          key: const ValueKey('chat_list'),
                          controller: _scrollController,
                          reverse: true,
                          padding: const EdgeInsets.all(24),
                          itemCount: allItemsCount,
                          itemBuilder: (context, index) {
                            if (chatState.isGenerating && index == 0) {
                              return MessageBubble(
                                content: chatState.streamingContent,
                                reasoning: chatState.streamingReasoning,
                                isUser: false,
                                isStreaming: true,
                                model: ref
                                    .read(serverProvider)
                                    .activeModelPath
                                    ?.split(RegExp(r'[/\\]'))
                                    .last,
                                generationTime: chatState.generationStartTime != null
                                    ? DateTime.now()
                                              .difference(chatState.generationStartTime!)
                                              .inMilliseconds /
                                          1000.0
                                    : 0.0,
                                generationStartTime: chatState.generationStartTime,
                                tokenCount: chatState.generationTokenCount,
                                totalContext: chatState.generationTotalContext > 0
                                    ? chatState.generationTotalContext
                                    : (chatState.generationPromptTokens +
                                           chatState.generationTokenCount),
                                tps: chatState.generationTPS,
                              );
                            }

                            final messageIndex = chatState.activeMessages.length -
                                1 -
                                (chatState.isGenerating ? index - 1 : index);

                            if (messageIndex < 0 ||
                                messageIndex >= chatState.activeMessages.length) {
                              return const SizedBox.shrink();
                            }

                            final message = chatState.activeMessages[messageIndex];
                            return MessageBubble(
                              messageId: message.id,
                              content: message.content,
                              reasoning: message.reasoning,
                              isUser: message.role == 'user',
                              imagePaths: message.imagePaths,
                              documentPaths: message.documentPaths,
                              model: message.model,
                              generationTime: message.generationTime,
                              tokenCount: message.tokenCount,
                              totalContext: message.totalContext,
                              tps: message.tps,
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),

        // Input Area
        _buildInputArea(context, chatState, serverState),
      ],
    ),
    );
  }

  Widget _buildInputArea(
    BuildContext context,
    ChatState chatState,
    ServerState serverState,
  ) {
    final isEmpty = _controller.text.trim().isEmpty;
    final hasTools = chatState.selectedTools.isNotEmpty;
    final hasAttachments = chatState.attachments.isNotEmpty;
    final showExpandedLayout = hasTools || hasAttachments;
    final speechState = ref.watch(speechProvider);
    final isListening = speechState.isListening;

    // 1. Plus Button Widget
    final plusButton = Theme(
      data: Theme.of(context).copyWith(
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: PopupMenuButton<String>(
        offset: const Offset(0, -280),
        color: AppTheme.surface.withValues(alpha: 0.95),
        elevation: 10,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
        icon: const Icon(
          Icons.add_circle_outline,
          color: AppTheme.primary,
          size: 24,
        ),
        onSelected: (value) async {
          if (value == 'upload_document') {
             _pickDocument();
          } else if (value == 'upload_image') {
             _pickImages();
          } else if (value == 'web_search') {
            final apiKey = ref.read(appSettingsProvider).webSearchApiKey;
            if (apiKey == null || apiKey.isEmpty) {
              final saved = await showApiKeyModal(context, ref);
              if (!saved) return;
            }
          }
          // Always toggle the tool chip so it shows in the text field as requested
          ref.read(chatProvider.notifier).toggleTool(value);
        },
        itemBuilder: (context) => defaultChatActions
            .map((action) => _buildToolItem(
                  action.id,
                  action.icon,
                  action.label,
                  action.color,
                ))
            .toList(),
      ),
    );

    // 2. Chips Row Widget
    final chips = chatState.selectedTools.isEmpty
        ? const SizedBox.shrink()
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: chatState.selectedTools.map((toolId) {
                final action =
                    defaultChatActions.firstWhere((a) => a.id == toolId);
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ActionChipWidget(
                    action: action,
                    onRemove: () =>
                        ref.read(chatProvider.notifier).removeToolWithAttachments(toolId),
                  ),
                );
              }).toList(),
            ),
          );

    // 3. TextField Widget
    final textField = TextField(
      controller: _controller,
      focusNode: _focusNode,
      maxLines: 5,
      minLines: 1,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: const InputDecoration(
        hintText: "Ask anything",
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        hoverColor: Colors.transparent,
        hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        contentPadding: EdgeInsets.symmetric(vertical: 8),
        isDense: true,
        fillColor: Colors.transparent,
        filled: true,
      ),
      enabled: true,
      onChanged: (_) => setState(() {}),
    );

    // 4. Voice / Send / Stop Button Widget
    // ── When the AI is generating: show a red stop button.
    // ── When the mic is active (isListening): show the waveform + a stop-mic button.
    // ── When text is present: show the send arrow.
    // ── When text is empty and not listening: show the mic icon to start listening.
    final Widget actionButton;

    if (chatState.isGenerating) {
      // Stop AI generation
      actionButton = _buildIconButton(
        icon: Icons.stop_circle_rounded,
        color: Colors.redAccent,
        size: 24,
        onTap: () => ref.read(chatProvider.notifier).stopGeneration(),
      );
    } else if (isListening) {
      // Show waveform + tap to stop listening
      actionButton = GestureDetector(
        onTap: () async {
          await ref.read(speechProvider.notifier).stopListening();
          // Text is already in _controller from live updates – just refresh UI.
          setState(() {});
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            VoiceWaveform(
              isListening: true,
              soundLevel: speechState.soundLevel,
              color: AppTheme.primary,
              barCount: 5,
              height: 28,
              width: 44,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.stop_circle_rounded, color: AppTheme.primary, size: 22),
          ],
        ),
      );
    } else if (!isEmpty) {
      // Send the typed message
      actionButton = _buildIconButton(
        icon: Icons.send_rounded,
        color: AppTheme.primary,
        size: 20,
        onTap: _sendMessage,
      );
    } else {
      // Start voice input
      actionButton = _buildIconButton(
        icon: Icons.mic,
        color: AppTheme.primary,
        size: 22,
        onTap: () async {
                // Keep a reference to the text that was already in the field
                // before the mic session starts.
                final prefixText = _controller.text;

                await ref.read(speechProvider.notifier).startListening(
                  onUpdate: (words) {
                    // Live-type the recognised words after any pre-existing text
                    _controller.text = prefixText.isEmpty
                        ? words
                        : '$prefixText $words';
                    _controller.selection = TextSelection.collapsed(
                      offset: _controller.text.length,
                    );
                    setState(() {});
                  },
                );
                setState(() {});
              },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: showExpandedLayout
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // File/image preview thumbnails
                  if (hasAttachments)
                    FilePreviewBar(
                      attachments: chatState.attachments,
                      onRemove: (i) =>
                          ref.read(chatProvider.notifier).removeAttachment(i),
                    ),
                  textField,
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      plusButton,
                      const SizedBox(width: 8),
                      if (hasTools) Expanded(child: chips),
                      const SizedBox(width: 8),
                      actionButton,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  plusButton,
                  const SizedBox(width: 8),
                  Expanded(child: textField),
                  const SizedBox(width: 8),
                  actionButton,
                ],
              ),
      ),
    );
  }

  /// Small tappable icon helper used by the action button area.
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required double size,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(icon, color: color, size: size),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildToolItem(
    String id,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<String>(
      value: id,
      padding: EdgeInsets.zero,
      child: _ToolMenuItem(icon: icon, label: label, color: color),
    );
  }
}

class ActionChipWidget extends StatefulWidget {
  final ChatAction action;
  final VoidCallback onRemove;

  const ActionChipWidget({
    super.key,
    required this.action,
    required this.onRemove,
  });

  @override
  State<ActionChipWidget> createState() => _ActionChipWidgetState();
}

class _ActionChipWidgetState extends State<ActionChipWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onRemove,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: widget.action.color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: widget.action.color.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isHovered ? Icons.close : widget.action.icon,
                color: widget.action.color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                widget.action.label,
                style: TextStyle(
                  color: widget.action.color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolMenuItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _ToolMenuItem({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  State<_ToolMenuItem> createState() => _ToolMenuItemState();
}

class _ToolMenuItemState extends State<_ToolMenuItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _isHovered ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHovered ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            AnimatedScale(
              duration: const Duration(milliseconds: 150),
              scale: _isHovered ? 1.1 : 1.0,
              child: Icon(
                widget.icon,
                color: widget.color,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: _isHovered ? Colors.white : Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  fontWeight: _isHovered ? FontWeight.w600 : FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (_isHovered)
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.white.withValues(alpha: 0.3),
                size: 10,
              ),
          ],
        ),
      ),
    );
  }
}
