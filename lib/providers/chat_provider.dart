import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/models/conversation.dart';
import '../data/models/message.dart';
import '../data/repositories/chat_repository.dart';
import '../data/services/llama_service.dart';
import '../data/services/gemini_search_service.dart';
import '../core/ai/prompt_builder.dart';
import '../core/ai/summary_service.dart';
import '../core/ai/token_estimator.dart';
import '../data/models/app_settings.dart';
import '../core/services/file_extraction_service.dart';
import '../core/models/attachment.dart';
import 'app_settings_provider.dart';
import 'providers.dart';
import 'settings_provider.dart';
import 'server_provider.dart';

class ChatState {
  final List<Conversation> conversations;
  final List<Conversation> temporaryConversations;
  final String? currentConversationId;
  final List<Message> activeMessages;
  final bool isGenerating;
  final String streamingContent;
  final String streamingReasoning;
  final bool isTemporaryChat;
  final DateTime? generationStartTime;
  final int generationTokenCount;
  final double generationTPS;
  final int generationTotalContext;
  final int generationPromptTokens;
  final List<String> selectedTools;
  final List<Attachment> attachments;
  final bool isPreparingVision;

  const ChatState({
    required this.conversations,
    required this.temporaryConversations,
    this.currentConversationId,
    required this.activeMessages,
    required this.isGenerating,
    required this.streamingContent,
    required this.streamingReasoning,
    this.isTemporaryChat = false,
    this.generationStartTime,
    this.generationTokenCount = 0,
    this.generationTPS = 0,
    this.generationTotalContext = 0,
    this.generationPromptTokens = 0,
    this.selectedTools = const [],
    this.attachments = const [],
    this.isPreparingVision = false,
  });

  factory ChatState.initial() {
    return const ChatState(
      conversations: [],
      temporaryConversations: [],
      activeMessages: [],
      isGenerating: false,
      streamingContent: '',
      streamingReasoning: '',
      generationTokenCount: 0,
      generationTPS: 0,
      generationTotalContext: 0,
      generationPromptTokens: 0,
      selectedTools: [],
    );
  }

  // Combined list for UI
  List<Conversation> get allConversations => [
    ...temporaryConversations,
    ...conversations,
  ];

  ChatState copyWith({
    List<Conversation>? conversations,
    List<Conversation>? temporaryConversations,
    String? currentConversationId,
    List<Message>? activeMessages,
    bool? isGenerating,
    String? streamingContent,
    String? streamingReasoning,
    bool? isTemporaryChat,
    bool forceClearConversationId = false,
    DateTime? generationStartTime,
    int? generationTokenCount,
    double? generationTPS,
    int? generationTotalContext,
    int? generationPromptTokens,
    List<String>? selectedTools,
    List<Attachment>? attachments,
    bool? isPreparingVision,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      temporaryConversations:
          temporaryConversations ?? this.temporaryConversations,
      currentConversationId: forceClearConversationId
          ? null
          : (currentConversationId ?? this.currentConversationId),
      activeMessages: activeMessages ?? this.activeMessages,
      isGenerating: isGenerating ?? this.isGenerating,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingReasoning: streamingReasoning ?? this.streamingReasoning,
      isTemporaryChat: isTemporaryChat ?? this.isTemporaryChat,
      generationStartTime: generationStartTime ?? this.generationStartTime,
      generationTokenCount: generationTokenCount ?? this.generationTokenCount,
      generationTPS: generationTPS ?? this.generationTPS,
      generationTotalContext:
          generationTotalContext ?? this.generationTotalContext,
      generationPromptTokens:
          generationPromptTokens ?? this.generationPromptTokens,
      selectedTools: selectedTools ?? this.selectedTools,
      attachments: attachments ?? this.attachments,
      isPreparingVision: isPreparingVision ?? this.isPreparingVision,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final ChatRepository _chatRepository;
  final Ref _ref;

  StreamSubscription<dynamic>? _currentSubscription;

  ChatNotifier(this._chatRepository, this._ref) : super(ChatState.initial()) {
    loadConversations();
  }

  void toggleTool(String toolId) {
    final isUpload = toolId == 'upload_document' || toolId == 'upload_image';
    
    if (state.selectedTools.contains(toolId)) {
      if (!isUpload) {
        state = state.copyWith(
          selectedTools: state.selectedTools.where((id) => id != toolId).toList(),
        );
      }
    } else {
      state = state.copyWith(
        selectedTools: [...state.selectedTools, toolId],
      );
    }
  }

  void removeToolOnly(String toolId) {
     state = state.copyWith(
       selectedTools: state.selectedTools.where((id) => id != toolId).toList(),
     );
  }

  void removeToolWithAttachments(String toolId) {
    state = state.copyWith(
      selectedTools: state.selectedTools.where((id) => id != toolId).toList(),
    );

    // If it's an upload tool, also clear the corresponding files
    if (toolId == 'upload_document') {
      state = state.copyWith(
        attachments: state.attachments.where((a) => !a.isDocument).toList(),
      );
    } else if (toolId == 'upload_image') {
      state = state.copyWith(
        attachments: state.attachments.where((a) => !a.isImage).toList(),
      );
    }
  }

  void addAttachment(Attachment attachment) {
    final updatedTools = List<String>.from(state.selectedTools);
    
    // Auto-enable the corresponding chip if not already present
    if (attachment.isImage && !updatedTools.contains('upload_image')) {
      updatedTools.add('upload_image');
    } else if (attachment.isDocument && !updatedTools.contains('upload_document')) {
      updatedTools.add('upload_document');
    }

    state = state.copyWith(
      attachments: [...state.attachments, attachment],
      selectedTools: updatedTools,
    );
  }

  void updateAttachment(Attachment oldAttachment, Attachment newAttachment) {
    state = state.copyWith(
      attachments: state.attachments.map((a) => a == oldAttachment ? newAttachment : a).toList(),
    );
  }

  void removeAttachment(int index) {
    final updated = List<Attachment>.from(state.attachments);
    final removed = updated.removeAt(index);
    
    final updatedTools = List<String>.from(state.selectedTools);
    
    // Check if we just removed the last of its kind
    if (removed.isImage) {
      final stillHasImages = updated.any((a) => a.isImage);
      if (!stillHasImages) {
        updatedTools.remove('upload_image');
      }
    } else if (removed.isDocument) {
      final stillHasDocs = updated.any((a) => a.isDocument);
      if (!stillHasDocs) {
        updatedTools.remove('upload_document');
      }
    }

    state = state.copyWith(
      attachments: updated,
      selectedTools: updatedTools,
    );
  }

  void clearAttachments() {
    state = state.copyWith(attachments: const []);
  }

  Future<void> loadConversations() async {
    final conversations = await _chatRepository.getConversations();
    state = state.copyWith(conversations: conversations);
  }

  Future<void> selectConversation(String id) async {
    final bool isTemp = id.startsWith('temp-');
    List<Message> messages = [];

    if (isTemp) {
      if (state.currentConversationId == id) return;
      // In a full implementation, we'd store temp messages in memory map.
      // For now, assume empty or managed elsewhere if we switch back.
      // Simply clearing for this mvp if switching between temps.
      messages = [];
    } else {
      messages = await _chatRepository.getMessages(id);
    }

    state = state.copyWith(
      currentConversationId: id,
      activeMessages: messages,
      streamingContent: '',
      isTemporaryChat: isTemp,
    );
  }

  Future<void> clearSelection() async {
    state = state.copyWith(
      forceClearConversationId: true,
      activeMessages: [],
      streamingContent: '',
      isTemporaryChat: false,
    );
  }

  Future<void> createNewChat({bool isTemporary = false}) async {
    if (isTemporary) {
      final tempId = 'temp-${const Uuid().v4()}';
      final tempConv = Conversation(
        id: tempId,
        title: 'Ghost Chat',
        updatedAt: DateTime.now(),
      );
      state = state.copyWith(
        temporaryConversations: [tempConv, ...state.temporaryConversations],
        currentConversationId: tempId,
        activeMessages: [],
        streamingContent: '',
        isTemporaryChat: true,
      );
    } else {
      final newChat = await _chatRepository.createConversation();
      await loadConversations();
      await selectConversation(newChat.id);
    }
  }

  Future<void> deleteConversation(String id) async {
    if (id.startsWith('temp-')) {
      state = state.copyWith(
        temporaryConversations: state.temporaryConversations
            .where((c) => c.id != id)
            .toList(),
      );
    } else {
      await _chatRepository.deleteConversation(id);
      await loadConversations();
    }
    if (state.currentConversationId == id) {
      clearSelection();
    }
  }

  Future<void> renameConversation(String id, String newTitle) async {
    if (id.startsWith('temp-')) {
      state = state.copyWith(
        temporaryConversations: state.temporaryConversations
            .map(
              (c) => c.id == id
                  ? Conversation(
                      id: c.id,
                      title: newTitle,
                      updatedAt: c.updatedAt,
                      folderId: c.folderId,
                    )
                  : c,
            )
            .toList(),
      );
    } else {
      await _chatRepository.renameConversation(id, newTitle);
      await loadConversations();
    }
  }

  Future<void> moveToFolder(String conversationId, String? folderId) async {
    if (conversationId.startsWith('temp-')) {
      state = state.copyWith(
        temporaryConversations: state.temporaryConversations
            .map(
              (c) => c.id == conversationId
                  ? Conversation(
                      id: c.id,
                      title: c.title,
                      updatedAt: c.updatedAt,
                      folderId: folderId,
                    )
                  : c,
            )
            .toList(),
      );
    } else {
      await _chatRepository.moveToFolder(conversationId, folderId);
      await loadConversations();
    }
  }

  Future<void> sendMessage(String text) async {
    if (state.isGenerating || text.trim().isEmpty) return;

    final currentAttachments = List<Attachment>.from(state.attachments);
    final imageAttachments = currentAttachments.where((a) => a.isImage).toList();
    final docAttachments = currentAttachments.where((a) => !a.isImage).toList();

    String conversationId = state.currentConversationId ?? '';
    final bool isTemp = state.isTemporaryChat;

    if (conversationId.isEmpty) {
      if (isTemp) {
        final tempId = 'temp-${const Uuid().v4()}';
        final tempConv = Conversation(
          id: tempId,
          title: 'Ghost Chat',
          updatedAt: DateTime.now(),
        );
        state = state.copyWith(
          temporaryConversations: [tempConv, ...state.temporaryConversations],
          currentConversationId: tempId,
          isTemporaryChat: true,
        );
        conversationId = tempId;
      } else {
        final newChat = await _chatRepository.createConversation(
          title: _generateTitle(text),
        );
        conversationId = newChat.id;
        await loadConversations();
        state = state.copyWith(currentConversationId: conversationId);
      }
    }

    // Build user message content (inject doc text if present)
    String userContent = text;
    if (docAttachments.isNotEmpty) {
      final docContext = docAttachments
          .where((a) => a.extractedText != null)
          .map((a) => '[Context from ${a.displayName}]:\n${a.extractedText}')
          .join('\n\n');
      if (docContext.isNotEmpty) {
        userContent = '$docContext\n\n---CONTEXT_END---\n\n$text';
      }
    }

    final userMessage = Message(
      id: const Uuid().v4(),
      conversationId: conversationId,
      role: 'user',
      content: userContent,
      timestamp: DateTime.now(),
      imagePaths: imageAttachments.isNotEmpty
          ? imageAttachments.map((a) => a.filePath).toList()
          : null,
      documentPaths: docAttachments.isNotEmpty
          ? docAttachments.map((a) => a.filePath).toList()
          : null,
    );

    if (!isTemp) {
      await _chatRepository.saveMessage(userMessage);
    }

    // Capture tools BEFORE clearing state so we can pass to response generator
    final activeTools = List<String>.from(state.selectedTools);
    final useWebSearch = activeTools.contains('web_search');

    state = state.copyWith(
      activeMessages: [...state.activeMessages, userMessage],
      selectedTools: state.selectedTools.where((t) => t != 'upload_document' && t != 'upload_image').toList(),
      attachments: const [],
    );

    // If we rely on the local server, ensure it is running
    if (!useWebSearch) {
      final serverState = _ref.read(serverProvider);
      
      if (imageAttachments.isNotEmpty) {
        // Swap to vision model if currently fast or completely offline
        if (serverState.currentMode == ModelMode.fast || serverState.status == ServerStatus.offline) {
          state = state.copyWith(isGenerating: true, streamingContent: 'Starting vision model...');
          await _ref.read(serverProvider.notifier).startVisionServer();
          state = state.copyWith(isGenerating: false, streamingContent: '');
        }
      } else {
        // For text-only, jumpstart the normal server if offline
        if (serverState.status == ServerStatus.offline) {
          state = state.copyWith(isGenerating: true, streamingContent: 'Starting offline model...');
          await _ref.read(serverProvider.notifier).startServer();
          state = state.copyWith(isGenerating: false, streamingContent: '');
        }
      }

      // Check if the required server actually started successfully
      final updatedServer = _ref.read(serverProvider);
      if (updatedServer.status != ServerStatus.online) {
        // Vision or normal server failed, bail out
        return;
      }
    }

    await _generateAssistantResponse(
      text,
      conversationId,
      imagePaths: imageAttachments.map((a) => a.filePath).toList(),
      useWebSearch: useWebSearch,
    );
  }


  Future<void> _generateAssistantResponse(
    String prompt,
    String conversationId, {
    List<String> imagePaths = const [],
    bool useWebSearch = false,
  }) async {
    state = state.copyWith(
      isGenerating: true,
      streamingContent: '',
      streamingReasoning: '',
      generationStartTime: DateTime.now(),
      generationTokenCount: 0,
      generationTPS: 0,
      generationPromptTokens: 0,
      generationTotalContext: 0,
    );

    try {
      final settings = _ref.read(settingsProvider);
      final appSettings = _ref.read(appSettingsProvider);
      final llamaService = LlamaService(baseUrl: settings.serverUrl);

      // Load facts and latest summary for this conversation
      final factRepo = _ref.read(factRepositoryProvider);
      final summaryRepo = _ref.read(summaryRepositoryProvider);

      final facts = await factRepo.getAllFacts();
      final latestSummary = await summaryRepo.getLatestSummary(conversationId);

      // Build text-only structured prompt
      final messages = PromptBuilder.build(
        userSystemPrompt: appSettings.systemPrompt,
        facts: facts,
        conversationSummary: latestSummary?.summaryText,
        recentMessages: state.activeMessages,
        tokenBudget: appSettings.maxHistoryTokens,
        messageWindow: appSettings.messageWindow,
      );

      // Pre-estimate prompt tokens so context counter doesn't start from 0
      final promptTokenEstimate = TokenEstimator.estimateMessages(messages);
      state = state.copyWith(generationPromptTokens: promptTokenEstimate);

      // ── WEB SEARCH ROUTE ─────────────────────────────────────────────────────
      if (useWebSearch) {
        final apiKey = appSettings.webSearchApiKey;
        if (apiKey == null || apiKey.isEmpty) {
          state = state.copyWith(
            isGenerating: false,
            streamingContent:
                '⚠️ Web Search requires a Gemini API key. Please add one in Settings → AI Behavior.',
          );
          return;
        }
        // Use conversation messages (not llama-formatted) for Gemini
        final geminiMessages = state.activeMessages
            .map((m) => {'role': m.role, 'content': m.content})
            .toList();

        _currentSubscription = GeminiSearchService.search(
          messages: geminiMessages,
          apiKey: apiKey,
        ).listen(
          (token) {
            final now = DateTime.now();
            final duration =
                now.difference(state.generationStartTime!).inMilliseconds /
                1000.0;
            final tokenCount = state.generationTokenCount + 1;
            final tps = duration > 0 ? tokenCount / duration : 0.0;
            state = state.copyWith(
              streamingContent: state.streamingContent + token,
              generationTokenCount: tokenCount,
              generationTPS: tps,
            );
          },
          onDone: () async {
            final now = DateTime.now();
            final totalTime =
                now.difference(state.generationStartTime!).inMilliseconds /
                1000.0;
            final assistantMessage = Message(
              id: const Uuid().v4(),
              conversationId: conversationId,
              role: 'assistant',
              content: state.streamingContent,
              timestamp: now,
              model: '${_ref.read(serverProvider).activeModelPath?.split(RegExp(r'[/\\]')).last ?? 'Gemini'}+gemini',
              generationTime: totalTime,
              tokenCount: state.generationTokenCount,
              tps: state.generationTPS,
              totalContext: state.generationTokenCount,
            );
            if (!state.isTemporaryChat) {
              await _chatRepository.saveMessage(assistantMessage);
              loadConversations();
              final msgs = await _chatRepository.getMessages(conversationId);
              state = state.copyWith(
                activeMessages: msgs,
                isGenerating: false,
                streamingContent: '',
                streamingReasoning: '',
              );
            } else {
              state = state.copyWith(
                activeMessages: [...state.activeMessages, assistantMessage],
                isGenerating: false,
                streamingContent: '',
                streamingReasoning: '',
              );
            }
            _currentSubscription = null;
          },
          onError: (e) {
            state = state.copyWith(
              isGenerating: false,
              streamingContent:
                  '⚠️ Gemini Web Search failed: $e',
            );
            _currentSubscription = null;
          },
          cancelOnError: true,
        );
        return; // Don't fall through to local model
      }

      // ── LOCAL MODEL ROUTE ─────────────────────────────────────────────────────
      // If we are in vision mode, we MUST use the vision-aware stream to preserve context of ANY images in history.
      final serverState = _ref.read(serverProvider);
      final Stream<dynamic> stream;
      if (serverState.currentMode == ModelMode.vision) {
        debugPrint('[ChatProvider] routing through vision stream (context-aware)');
        stream = llamaService.generateStreamingVision(
          messages: messages,
          temperature: appSettings.temperature,
          maxTokens: appSettings.maxTokens,
        );
      } else {
        stream = llamaService.generateStreaming(
          messages: messages,
          temperature: appSettings.temperature,
          maxTokens: appSettings.maxTokens,
          cachePrompt: appSettings.enableKvCache,
        );
      }

      String accumulated = '';

      _currentSubscription = stream.listen(
        (chunk) {
          if (chunk is Map && chunk['type'] == 'usage') {
            final usage = chunk['data'];
            state = state.copyWith(
              generationPromptTokens: usage['prompt_tokens'],
              generationTotalContext: usage['total_tokens'],
            );
            return;
          }

          if (chunk is! String) return;
          final token = chunk;

          accumulated += token;
          String content = accumulated;
          String reasoning = '';

          if (accumulated.contains('<thought>')) {
            final start = accumulated.indexOf('<thought>') + 9;
            if (accumulated.contains('</thought>')) {
              final end = accumulated.indexOf('</thought>');
              reasoning = accumulated.substring(start, end).trim();
              content = accumulated.substring(end + 10).trim();
            } else {
              reasoning = accumulated.substring(start).trim();
              content = '';
            }
          } else if (accumulated.contains('<think>')) {
            final start = accumulated.indexOf('<think>') + 7;
            if (accumulated.contains('</think>')) {
              final end = accumulated.indexOf('</think>');
              reasoning = accumulated.substring(start, end).trim();
              content = accumulated.substring(end + 8).trim();
            } else {
              reasoning = accumulated.substring(start).trim();
              content = '';
            }
          }

          final now = DateTime.now();
          final duration =
              now.difference(state.generationStartTime!).inMilliseconds /
              1000.0;
          final tokenCount = state.generationTokenCount + 1;
          final tps = duration > 0 ? tokenCount / duration : 0.0;

          state = state.copyWith(
            streamingContent: content,
            streamingReasoning: reasoning,
            generationTokenCount: tokenCount,
            generationTPS: tps,
          );
        },
        onDone: () async {
          final now = DateTime.now();
          final totalTime =
              now.difference(state.generationStartTime!).inMilliseconds /
              1000.0;

          final assistantMessage = Message(
            id: const Uuid().v4(),
            conversationId: conversationId,
            role: 'assistant',
            content: state.streamingContent,
            reasoning: state.streamingReasoning,
            timestamp: now,
            model: () {
              final base = _ref
                  .read(serverProvider)
                  .activeModelPath
                  ?.split(RegExp(r'[/\\]'))
                  .last ?? 'Unknown';
              // Tag whether web search was used so the UI can show Gemini badge
              final usedWebSearch = state.selectedTools.contains('web_search');
              return usedWebSearch ? '$base+gemini' : base;
            }(),
            generationTime: totalTime,
            tokenCount: state.generationTokenCount,
            tps: state.generationTPS,
            totalContext: state.generationTotalContext > 0
                ? state.generationTotalContext
                : (state.generationPromptTokens + state.generationTokenCount),
          );

          if (!state.isTemporaryChat) {
            await _chatRepository.saveMessage(assistantMessage);
            loadConversations();
            final msgs = await _chatRepository.getMessages(conversationId);
            state = state.copyWith(
              activeMessages: msgs,
              isGenerating: false,
              streamingContent: '',
              streamingReasoning: '',
            );

            // --- Background summarization trigger ---
            if (appSettings.enableAutoSummary) {
              _triggerSummarizationIfNeeded(
                conversationId: conversationId,
                messages: msgs,
                appSettings: appSettings,
                llamaService: llamaService,
              );
            }
          } else {
            state = state.copyWith(
              activeMessages: [...state.activeMessages, assistantMessage],
              isGenerating: false,
              streamingContent: '',
              streamingReasoning: '',
            );
          }
          _currentSubscription = null;
        },
        onError: (e) {
          state = state.copyWith(
            isGenerating: false,
            streamingContent: 'Error: $e',
          );
          _currentSubscription = null;
        },
        cancelOnError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isGenerating: false,
        streamingContent: 'Error: $e',
      );
    }
  }

  /// Fire-and-forget background summarization.
  /// Runs AFTER the AI response completes — never blocks UI.
  void _triggerSummarizationIfNeeded({
    required String conversationId,
    required List<Message> messages,
    required AppSettings appSettings,
    required LlamaService llamaService,
  }) {
    // Check if summarization should fire
    if (!SummaryService.shouldSummarize(
      messages: messages,
      summaryThreshold: appSettings.summaryThreshold,
    )) {
      return;
    }

    // Fire-and-forget: run in background, don't await
    Future.microtask(() async {
      try {
        final summaryRepo = _ref.read(summaryRepositoryProvider);
        final summaryService = SummaryService(
          summaryRepo: summaryRepo,
          llamaService: llamaService,
        );

        final compressed = await summaryService.summarizeAndStore(
          conversationId: conversationId,
          messages: messages,
          keepRecentCount: appSettings.messageWindow,
        );

        if (compressed > 0) {
          debugPrint('📋 SummaryService: Compressed $compressed messages into summary');
        }
      } catch (e) {
        debugPrint('⚠️ SummaryService error: $e');
      }
    });
  }

  void stopGeneration() {
    if (_currentSubscription != null) {
      _currentSubscription?.cancel();
      _currentSubscription = null;

      // Save what we have so far if it's not empty
      if (state.streamingContent.isNotEmpty) {
        final assistantMessage = Message(
          id: const Uuid().v4(),
          conversationId: state.currentConversationId ?? '',
          role: 'assistant',
          content: state.streamingContent,
          reasoning: state.streamingReasoning,
          timestamp: DateTime.now(),
        );

        if (!state.isTemporaryChat) {
          _chatRepository.saveMessage(assistantMessage).then((_) {
            loadConversations();
            _chatRepository.getMessages(state.currentConversationId!).then((
              msgs,
            ) {
              state = state.copyWith(
                activeMessages: msgs,
                isGenerating: false,
                streamingContent: '',
                streamingReasoning: '',
              );
            });
          });
        } else {
          state = state.copyWith(
            activeMessages: [...state.activeMessages, assistantMessage],
            isGenerating: false,
            streamingContent: '',
            streamingReasoning: '',
          );
        }
      } else {
        state = state.copyWith(isGenerating: false);
      }
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final bool isTemp = state.isTemporaryChat;
    if (isTemp) {
      state = state.copyWith(
        activeMessages: state.activeMessages
            .where((m) => m.id != messageId)
            .toList(),
      );
    } else {
      await _chatRepository.deleteMessage(messageId);
      if (state.currentConversationId != null) {
        final messages = await _chatRepository.getMessages(
          state.currentConversationId!,
        );
        state = state.copyWith(activeMessages: messages);
      }
    }
  }

  Future<void> regenerateResponse(String assistantMessageId) async {
    if (state.isGenerating) return;

    final index = state.activeMessages.indexWhere(
      (m) => m.id == assistantMessageId,
    );
    if (index == -1) return;

    // Find the user message before this assistant message
    Message? lastUserMessage;
    for (int i = index - 1; i >= 0; i--) {
      if (state.activeMessages[i].role == 'user') {
        lastUserMessage = state.activeMessages[i];
        break;
      }
    }

    if (lastUserMessage == null) return;

    // Remove all messages from this assistant message onwards
    final List<Message> truncatedMessages = state.activeMessages.sublist(
      0,
      index,
    );

    // If not temporary, delete from DB as well
    if (!state.isTemporaryChat) {
      for (int i = index; i < state.activeMessages.length; i++) {
        await _chatRepository.deleteMessage(state.activeMessages[i].id);
      }
    }

    state = state.copyWith(activeMessages: truncatedMessages);

    // Trigger new generation with the last user message
    await _generateAssistantResponse(
      lastUserMessage.content,
      lastUserMessage.conversationId,
    );
  }

  Future<void> editAndResendMessage(String messageId, String newContent) async {
    if (state.isGenerating || newContent.trim().isEmpty) return;

    final index = state.activeMessages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;

    final originalMessage = state.activeMessages[index];
    if (originalMessage.role != 'user') return;

    // 1. Convert old paths back to attachments so they are picked up by sendMessage
    final List<Attachment> oldAttachments = [];
    final List<String> updatedTools = List<String>.from(state.selectedTools);

    if (originalMessage.imagePaths != null) {
      for (final path in originalMessage.imagePaths!) {
        oldAttachments.add(Attachment(
          filePath: path,
          type: AttachmentType.image,
          fileName: path.split(RegExp(r'[/\\]')).last,
        ));
      }
      if (!updatedTools.contains('upload_image')) {
        updatedTools.add('upload_image');
      }
    }
    if (originalMessage.documentPaths != null) {
      for (final path in originalMessage.documentPaths!) {
        // Re-extract to ensure sendMessage has the context
        final text = await FileExtractionService.extractText(File(path));
        oldAttachments.add(Attachment(
          filePath: path,
          type: AttachmentType.document,
          fileName: path.split(RegExp(r'[/\\]')).last,
          extractedText: text,
        ));
      }
      if (!updatedTools.contains('upload_document')) {
        updatedTools.add('upload_document');
      }
    }

    // 2. Delete original message and ALL subsequent messages from state
    final List<Message> truncatedMessages = state.activeMessages.sublist(0, index);

    // 3. Delete them from DB as well
    if (!state.isTemporaryChat) {
      for (int i = index; i < state.activeMessages.length; i++) {
        await _chatRepository.deleteMessage(state.activeMessages[i].id);
      }
    }

    // 4. Update state with restored attachments and truncated messages
    state = state.copyWith(
      activeMessages: truncatedMessages,
      attachments: oldAttachments,
      selectedTools: updatedTools,
    );

    // 5. Now, trigger the normal send flow with the NEW content
    await sendMessage(newContent);
  }

  Future<void> clearAllHistory() async {
    await _chatRepository.clearAllHistory();
    state = state.copyWith(
      activeMessages: [],
      conversations: [],
      attachments: [],
      selectedTools: [],
    );
    loadConversations();
  }

  String _generateTitle(String text) {
    return text.length > 30 ? '${text.substring(0, 30)}...' : text;
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ChatNotifier(repo, ref);
});
