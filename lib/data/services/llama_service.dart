import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

class LlamaService {
  final String baseUrl;

  LlamaService({required this.baseUrl});

  // ── Health ────────────────────────────────────────────────────────────────

  /// Returns true if the server process is alive (any HTTP 200 response).
  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Returns true only when the server reports `"status":"ok"` — i.e. the
  /// model AND multimodal encoder have finished warmup.
  Future<bool> checkHealthReady() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      return body?['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ── Model list ────────────────────────────────────────────────────────────

  Future<List<String>> getModels() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/v1/models'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['data'] as List?;
        if (models != null) {
          return models.map((m) => m['id'] as String).toList();
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  // ── Non-streaming (summaries, background tasks) ───────────────────────────

  Future<String> generate({
    required String prompt,
    int maxTokens = 512,
    double temperature = 0.3,
  }) async {
    final url = Uri.parse('$baseUrl/v1/chat/completions');
    final requestBody = jsonEncode({
      'messages': [
        {'role': 'user', 'content': prompt},
      ],
      'stream': false,
      'temperature': temperature,
      'max_tokens': maxTokens,
    });

    try {
      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'}, body: requestBody)
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) return '';

      final json = jsonDecode(response.body);
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? '';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  // ── Text-only streaming ────────────────────────────────────────────────────

  /// Streams an assistant response for a plain-text conversation.
  /// [messages] is the full message list from PromptBuilder (text only).
  Stream<dynamic> generateStreaming({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = -1,
    bool cachePrompt = true,
  }) async* {
    final url = Uri.parse('$baseUrl/v1/chat/completions');

    // Text messages pass straight through — no image processing here.
    final requestBody = jsonEncode({
      'messages': messages,
      'stream': true,
      'stream_options': {'include_usage': true},
      'temperature': temperature,
      'max_tokens': maxTokens,
      'cache_prompt': cachePrompt,
    });

    yield* _streamRequest(url, requestBody);
  }

  /// Converts image bytes to a format that llama.cpp (stb_image) can decode.
  ///
  /// stb_image supports: JPEG, PNG, BMP, GIF.
  /// It does NOT support: WebP, TIFF, AVIF, HEIC.
  ///
  /// Returns a (bytes, mimeType) tuple — either the original bytes (JPEG/PNG)
  /// or re-encoded JPEG bytes for everything else.
  (Uint8List, String) _prepareImageBytes(Uint8List raw, String ext) {
    // Detect actual format from magic bytes (don't trust the extension).
    bool isJpeg = raw.length >= 3 &&
        raw[0] == 0xFF && raw[1] == 0xD8 && raw[2] == 0xFF;
    bool isPng = raw.length >= 8 &&
        raw[0] == 0x89 && raw[1] == 0x50 && raw[2] == 0x4E && raw[3] == 0x47;

    if (isJpeg) return (raw, 'image/jpeg');
    if (isPng) return (raw, 'image/png');

    // Unsupported format (WebP, TIFF, AVIF, etc.) — convert to JPEG.
    debugPrint('[Vision] Converting $ext → JPEG (stb_image does not support $ext)');
    try {
      final decoded = img.decodeImage(raw);
      if (decoded == null) {
        debugPrint('[Vision] image package could not decode $ext, sending raw anyway');
        return (raw, 'image/jpeg');
      }
      final jpegBytes = Uint8List.fromList(img.encodeJpg(decoded, quality: 92));
      debugPrint('[Vision] Converted: ${raw.length} bytes → ${jpegBytes.length} bytes JPEG');
      return (jpegBytes, 'image/jpeg');
    } catch (e) {
      debugPrint('[Vision] Conversion failed for $ext: $e — sending raw');
      return (raw, 'image/jpeg');
    }
  }

  // ── Vision streaming ───────────────────────────────────────────────────────

  /// Streams an assistant response for a conversation that may contain images.
  /// Any message in [messages] that has the 'image_paths' key will be
  /// converted to an OpenAI-style multimodal payload.
  Stream<dynamic> generateStreamingVision({
    required List<Map<String, dynamic>> messages,
    double temperature = 0.7,
    int maxTokens = -1,
  }) async* {
    final url = Uri.parse('$baseUrl/v1/chat/completions');
    final List<Map<String, dynamic>> finalMessages = [];

    // Local cache for base64 encoded images to avoid re-reading/encoding
    // the same image if it appears multiple times in history.
    final Map<String, String> b64Cache = {};

    for (final m in messages) {
      final role = m['role'];
      final content = m['content'] as String;
      final rawPaths = m['image_paths'];
      final imagePaths = rawPaths is List ? rawPaths.cast<String>() : null;

      if (imagePaths != null && imagePaths.isNotEmpty) {
        final List<Map<String, dynamic>> multiContent = [];
        
        // 1. Process images for this message
        for (final path in imagePaths) {
          if (b64Cache.containsKey(path)) {
            multiContent.add({
              'type': 'image_url',
              'image_url': {'url': b64Cache[path]!},
            });
            continue;
          }

          final file = File(path);
          if (!file.existsSync()) {
            debugPrint('[Vision] Image not found in cache, encoding: $path');
            continue;
          }

          try {
            final bytes = file.readAsBytesSync();
            final ext = path.split('.').last.toLowerCase();
            final (preparedBytes, mime) = _prepareImageBytes(Uint8List.fromList(bytes), ext);
            final b64 = base64Encode(preparedBytes);
            final dataUrl = 'data:$mime;base64,$b64';
            
            b64Cache[path] = dataUrl;
            multiContent.add({
              'type': 'image_url',
              'image_url': {'url': dataUrl},
            });
            debugPrint('[Vision] Encoded image: $path (${preparedBytes.length} bytes, $mime)');
          } catch (e) {
            debugPrint('[Vision] Failed to encode image $path: $e');
          }
        }

        // 2. Add text last
        multiContent.add({'type': 'text', 'text': content});
        finalMessages.add({'role': role, 'content': multiContent});
      } else {
        // Plain text message
        finalMessages.add({'role': role, 'content': content});
      }
    }

    final requestBody = jsonEncode({
      'messages': finalMessages,
      'stream': true,
      'stream_options': {'include_usage': true},
      'temperature': temperature,
      'max_tokens': maxTokens,
      'cache_prompt': false, // Multimodal doesn't support KV cache in standard llama-server
    });

    debugPrint('[Vision] Sending vision request: ${finalMessages.length} messages, '
        '${b64Cache.length} total unique images');

    yield* _streamRequest(url, requestBody);
  }

  // ── Shared SSE parser ─────────────────────────────────────────────────────

  Stream<dynamic> _streamRequest(Uri url, String body) async* {
    final request = http.Request('POST', url);
    request.headers['Content-Type'] = 'application/json';
    request.body = body;

    try {
      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        debugPrint('[LlamaService] Server error ${streamedResponse.statusCode}: $errorBody');
        throw Exception('Server returned ${streamedResponse.statusCode}: $errorBody');
      }

      await for (final line in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (!line.startsWith('data: ')) continue;
        final data = line.substring(6).trim();
        if (data == '[DONE]') return;

        try {
          final json = jsonDecode(data);

          if (json['usage'] != null) {
            yield {'type': 'usage', 'data': json['usage']};
          }

          final choices = json['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final content = choices[0]['delta']['content'];
            if (content != null) yield content as String;
          }
        } catch (_) {
          // Ignore malformed SSE chunks
        }
      }
    } catch (e) {
      throw Exception('Connection failed: $e');
    }
  }
}
