import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Configuration for a single Gemini model+endpoint attempt
class _ModelConfig {
  final String apiVersion;
  final String modelId;
  final Map<String, dynamic> searchTool;

  const _ModelConfig({
    required this.apiVersion,
    required this.modelId,
    required this.searchTool,
  });

  String get url =>
      'https://generativelanguage.googleapis.com/$apiVersion/models/$modelId:streamGenerateContent';
}

/// Cascade of Gemini models, tried in order until one succeeds.
/// Covers 2.5, 2.0, and 1.5 model families across v1/v1beta endpoints.
const List<_ModelConfig> _modelCascade = [
  // ── Gemini 2.5 ─────────────────────────────────────────────────────────────
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-2.5-flash-preview-04-17',
    searchTool: {'google_search': {}},
  ),
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-2.5-flash',
    searchTool: {'google_search': {}},
  ),
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-2.5-flash-latest',
    searchTool: {'google_search': {}},
  ),
  // ── Gemini 2.0 ─────────────────────────────────────────────────────────────
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-2.0-flash',
    searchTool: {'google_search': {}},
  ),
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-2.0-flash-lite',
    searchTool: {'google_search': {}},
  ),
  // ── Gemini 1.5 (different tool name) ───────────────────────────────────────
  _ModelConfig(
    apiVersion: 'v1beta',
    modelId: 'gemini-1.5-flash-latest',
    searchTool: {
      'google_search_retrieval': {
        'dynamic_retrieval_config': {'mode': 'MODE_DYNAMIC'},
      }
    },
  ),
  _ModelConfig(
    apiVersion: 'v1',
    modelId: 'gemini-1.5-flash-latest',
    searchTool: {
      'google_search_retrieval': {
        'dynamic_retrieval_config': {'mode': 'MODE_DYNAMIC'},
      }
    },
  ),
];

class GeminiSearchService {
  /// Streams Gemini answer tokens with Google Search grounding.
  /// Automatically tries models until one succeeds.
  static Stream<String> search({
    required List<Map<String, dynamic>> messages,
    required String apiKey,
  }) async* {
    // Build alternating history for Gemini
    final List<Map<String, dynamic>> contents = [];
    String? currentRole;
    String currentText = '';

    for (final m in messages) {
      final role = m['role'] == 'assistant' ? 'model' : 'user';
      final text = (m['content'] as String).trim();
      if (text.isEmpty) continue;

      if (role == currentRole) {
        currentText += '\n\n$text';
      } else {
        if (currentRole != null) {
          contents.add({
            'role': currentRole,
            'parts': [{'text': currentText}],
          });
        }
        currentRole = role;
        currentText = text;
      }
    }
    if (currentRole != null) {
      contents.add({
        'role': currentRole,
        'parts': [{'text': currentText}],
      });
    }

    Exception? lastError;

    for (final config in _modelCascade) {
      debugPrint('[GeminiSearch] Trying ${config.modelId} (${config.apiVersion})...');

      final url = Uri.parse('${config.url}?key=$apiKey&alt=sse');
      final body = jsonEncode({
        'contents': contents,
        'tools': [config.searchTool],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 8192,
        },
      });

      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.body = body;

      http.StreamedResponse response;
      try {
        response = await request.send();
      } catch (e) {
        lastError = Exception('Network error: $e');
        continue;
      }

      // 404 → model not found for this key/region → try next
      if (response.statusCode == 404) {
        await response.stream.drain<void>();
        debugPrint('[GeminiSearch] 404 for ${config.modelId} – trying next');
        lastError = Exception('${config.modelId} not available (${response.statusCode})');
        continue;
      }

      // 429 → check if limit is 0 (model-level zero quota) vs actual exhaustion
      if (response.statusCode == 429) {
        final errBody = await response.stream.bytesToString();
        debugPrint('[GeminiSearch] 429 for ${config.modelId}: $errBody');

        final isModelLevelZero = errBody.contains('"limit": 0') ||
            errBody.contains('"limit":0');

        if (isModelLevelZero) {
          // This model has 0 quota in their project — cascade to next model
          debugPrint('[GeminiSearch] limit:0 for ${config.modelId} – trying next model');
          lastError = Exception('${config.modelId} has no quota on your project');
          continue;
        }

        // Real rate-limit exhaustion (limit > 0 but currently exceeded) – surface to user
        throw Exception(_extractMessage(errBody, 429));
      }

      // 403 → invalid API key → stop immediately, nothing else will work
      if (response.statusCode == 403) {
        final errBody = await response.stream.bytesToString();
        throw Exception(_extractMessage(errBody, 403));
      }

      // Any other non-200 → surface to user
      if (response.statusCode != 200) {
        final errBody = await response.stream.bytesToString();
        throw Exception(_extractMessage(errBody, response.statusCode));
      }

      // ── 200 OK: parse SSE stream ─────────────────────────────────────────
      debugPrint('[GeminiSearch] ✓ Using ${config.modelId}');
      bool yieldedAny = false;

      try {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          for (final line in chunk.split('\n')) {
            if (!line.startsWith('data: ')) continue;
            final data = line.substring(6).trim();
            if (data.isEmpty || data == '[DONE]') continue;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final candidates = json['candidates'] as List<dynamic>?;
              if (candidates == null || candidates.isEmpty) continue;

              final content =
                  candidates[0]['content'] as Map<String, dynamic>?;
              final parts = content?['parts'] as List<dynamic>?;
              if (parts == null) continue;

              for (final part in parts) {
                final text =
                    (part as Map<String, dynamic>)['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  yieldedAny = true;
                  yield text;
                }
              }
            } catch (_) {
              // Skip malformed SSE lines
            }
          }
        }
      } catch (e) {
        debugPrint('[GeminiSearch] Stream error with ${config.modelId}: $e');
        if (yieldedAny) return; // Partial response is good enough
        lastError = Exception('Stream error: $e');
        continue;
      }

      if (yieldedAny) return; // Success
    }

    // All models exhausted
    throw lastError ??
        Exception(
          'No Gemini model is available for your API key/region.\n'
          'Make sure your key is from aistudio.google.com and the Gemini API is enabled.',
        );
  }

  static String _extractMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body);
      final msg = json['error']?['message'] as String?;
      if (msg != null && msg.isNotEmpty) {
        if (statusCode == 429) {
          return '⏱ Rate limit reached. Please wait a moment and try again.\n\n${msg.split('\n').first}';
        }
        if (statusCode == 403) {
          return '🔑 Invalid API key (403). Please check your key in Settings → AI Behavior.';
        }
        return msg;
      }
    } catch (_) {}
    return 'Gemini API error ($statusCode)';
  }
}
