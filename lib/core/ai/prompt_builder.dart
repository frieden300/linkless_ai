import '../../data/models/fact.dart';
import '../../data/models/message.dart';
import 'token_estimator.dart';

/// Assembles the canonical structured prompt for the LLM.
///
/// Format:
///   [SYSTEM] — strict rules + user instructions
///   [FACTS]  — key-value pairs from facts table
///   [SUMMARY] — compressed older conversation
///   [RECENT MESSAGES] — last N user/assistant exchanges
///   [USER] — current query (already part of recent messages)
class PromptBuilder {
  /// The hardcoded behavioral rules that prevent hallucination.
  static const String _coreSystemRules = '''
RULES:
- You have NO persistent memory beyond this conversation.
- Use ONLY information provided in the "Known Facts" and "Conversation Summary" sections below.
- If asked about something not in your context, honestly say you don't have that information.
- Never fabricate facts or claim to remember things not provided to you.''';

  /// Builds the full message list for the LLM API call.
  static List<Map<String, dynamic>> build({
    required String userSystemPrompt,
    required List<Fact> facts,
    required String? conversationSummary,
    required List<Message> recentMessages,
    required int tokenBudget,
    required int messageWindow,
  }) {
    final result = <Map<String, dynamic>>[];

    // --- 1. SYSTEM BLOCK (Combined) ---
    final combinedSystem = StringBuffer(_buildSystemBlock(userSystemPrompt));

    if (facts.isNotEmpty) {
      combinedSystem.write('\n\n${_buildFactsBlock(facts)}');
    }

    if (conversationSummary != null && conversationSummary.isNotEmpty) {
      combinedSystem.write(
        '\n\nConversation Summary (older context):\n$conversationSummary',
      );
    }

    result.add({'role': 'system', 'content': combinedSystem.toString()});

    // --- 4. RECENT MESSAGES (token-aware trimming) ---
    // Calculate remaining token budget
    int usedTokens = 0;
    for (final msg in result) {
      usedTokens += TokenEstimator.estimate(msg['content'] as String);
    }
    final remainingBudget = tokenBudget - usedTokens;

    final trimmedMessages = _trimMessages(
      messages: recentMessages,
      tokenBudget: remainingBudget,
      messageWindow: messageWindow,
    );

    result.addAll(trimmedMessages);
    return result;
  }

  /// Builds the system block with core rules + user instructions.
  static String _buildSystemBlock(String userPrompt) {
    final buffer = StringBuffer();

    if (userPrompt.isNotEmpty) {
      buffer.writeln(userPrompt);
      buffer.writeln();
    } else {
      buffer.writeln('You are a helpful AI assistant.');
      buffer.writeln();
    }

    // Always enforce English so multilingual VL models don't default to Korean etc.
    buffer.writeln(
      'IMPORTANT: Always respond in English, regardless of model language defaults.',
    );
    buffer.writeln();

    buffer.write(_coreSystemRules);
    return buffer.toString();
  }

  /// Builds the facts block as a readable list.
  static String _buildFactsBlock(List<Fact> facts) {
    final buffer = StringBuffer('Known Facts about the user:\n');
    for (final fact in facts) {
      buffer.writeln('- ${fact.key}: ${fact.value}');
    }
    return buffer.toString();
  }

  /// Trims messages to fit within token budget, prioritizing recent messages.
  static List<Map<String, dynamic>> _trimMessages({
    required List<Message> messages,
    required int tokenBudget,
    required int messageWindow,
  }) {
    // Convert to API format (keeping image paths for vision context)
    final apiMessages = messages.map((msg) {
      return {
        'role': msg.role,
        'content': msg.content,
        if (msg.imagePaths != null && msg.imagePaths!.isNotEmpty)
          'image_paths': msg.imagePaths,
      };
    }).toList();

    // Limit to message window
    final windowed = apiMessages.length > messageWindow
        ? apiMessages.sublist(apiMessages.length - messageWindow)
        : apiMessages;

    // Trim from oldest to fit token budget
    int currentTokens = 0;
    final result = <Map<String, dynamic>>[];

    for (int i = windowed.length - 1; i >= 0; i--) {
      final msg = windowed[i];
      final msgTokens = TokenEstimator.estimateMessages([msg]);

      if (currentTokens + msgTokens <= tokenBudget) {
        result.insert(0, msg);
        currentTokens += msgTokens;
      } else {
        break;
      }
    }

    return result;
  }

  /// Estimates total tokens that would be used by a built prompt.
  static int estimatePromptTokens({
    required String userSystemPrompt,
    required List<Fact> facts,
    required String? conversationSummary,
    required List<Message> recentMessages,
  }) {
    int total = TokenEstimator.estimate(_buildSystemBlock(userSystemPrompt));

    if (facts.isNotEmpty) {
      total += TokenEstimator.estimate(_buildFactsBlock(facts));
    }

    if (conversationSummary != null) {
      total += TokenEstimator.estimate(conversationSummary);
    }

    total += TokenEstimator.estimateMessages(
      recentMessages
          .map(
            (msg) => {
              'role': msg.role,
              'content': msg.content,
              if (msg.imagePaths != null && msg.imagePaths!.isNotEmpty)
                'image_paths': msg.imagePaths,
            },
          )
          .toList(),
    );

    return total;
  }
}
