import 'package:uuid/uuid.dart';
import '../../data/models/message.dart';
import '../../data/models/summary.dart';
import '../../data/repositories/summary_repository.dart';
import '../../data/services/llama_service.dart';
import 'token_estimator.dart';

/// Handles automatic conversation summarization when token limits are reached.
class SummaryService {
  final SummaryRepository _summaryRepo;
  final LlamaService _llamaService;

  SummaryService({
    required SummaryRepository summaryRepo,
    required LlamaService llamaService,
  })  : _summaryRepo = summaryRepo,
        _llamaService = llamaService;

  /// The prompt sent to the model for summarization.
  static String buildSummarizationPrompt(List<Message> messages) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Summarize the following conversation into 5-8 concise bullet points. '
      'Preserve: user preferences, key facts, names, decisions made, and action items. '
      'Output ONLY the bullet points, no extra commentary.\n',
    );
    buffer.writeln('Conversation:');
    for (final msg in messages) {
      buffer.writeln('${msg.role}: ${msg.content}');
    }
    return buffer.toString();
  }

  /// Checks if summarization should trigger based on token threshold.
  static bool shouldSummarize({
    required List<Message> messages,
    required int summaryThreshold,
  }) {
    int totalTokens = 0;
    for (final msg in messages) {
      totalTokens += TokenEstimator.estimate(msg.content);
    }
    return totalTokens > summaryThreshold;
  }

  /// Summarizes older messages and stores the summary in the database.
  /// Returns the number of messages that were compressed.
  Future<int> summarizeAndStore({
    required String conversationId,
    required List<Message> messages,
    required int keepRecentCount,
  }) async {
    if (messages.length <= keepRecentCount) return 0;

    // Split: messages to summarize vs. messages to keep
    final toSummarize = messages.sublist(
      0,
      messages.length - keepRecentCount,
    );

    if (toSummarize.isEmpty) return 0;

    // Build summarization prompt
    final prompt = buildSummarizationPrompt(toSummarize);

    // Call the local model for summarization (non-streaming)
    final summaryText = await _llamaService.generate(
      prompt: prompt,
      maxTokens: 512,
      temperature: 0.3, // Low creativity for factual summaries
    );

    if (summaryText.isEmpty) return 0;

    // Store summary in database
    final summary = Summary(
      id: const Uuid().v4(),
      conversationId: conversationId,
      summaryText: summaryText,
      startMsgId: toSummarize.first.id,
      endMsgId: toSummarize.last.id,
      tokenCount: TokenEstimator.estimate(summaryText),
      createdAt: DateTime.now(),
    );

    await _summaryRepo.saveSummary(summary);
    return toSummarize.length;
  }
}
