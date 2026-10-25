import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class SpeechState {
  /// Whether the speech engine is actively listening.
  final bool isListening;

  /// Whether the device supports speech recognition.
  final bool isAvailable;

  /// The live recognised words during the current session.
  final String recognizedText;

  /// Microphone sound level in dB (-2 … 10 typical range from the plugin).
  /// Used to drive the waveform animation.
  final double soundLevel;

  const SpeechState({
    this.isListening = false,
    this.isAvailable = false,
    this.recognizedText = '',
    this.soundLevel = 0.0,
  });

  SpeechState copyWith({
    bool? isListening,
    bool? isAvailable,
    String? recognizedText,
    double? soundLevel,
  }) {
    return SpeechState(
      isListening: isListening ?? this.isListening,
      isAvailable: isAvailable ?? this.isAvailable,
      recognizedText: recognizedText ?? this.recognizedText,
      soundLevel: soundLevel ?? this.soundLevel,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class SpeechNotifier extends StateNotifier<SpeechState> {
  final SpeechToText _speech = SpeechToText();

  SpeechNotifier() : super(const SpeechState()) {
    _init();
  }

  /// Must be called once to initialise the speech engine.
  Future<void> _init() async {
    try {
      final available = await _speech.initialize(
        onStatus: _onStatus,
        onError: _onError,
      );
      
      // -- WINDOWS PLUGIN BUG FIX --
      if (defaultTargetPlatform == TargetPlatform.windows) {
        final originalHandler = SpeechToTextPlatform.instance.onTextRecognition;
        SpeechToTextPlatform.instance.onTextRecognition = (String resultJson) {
           Future.microtask(() {
             try {
               final Map<String, dynamic> map = jsonDecode(resultJson);
               if (map['alternates'] == null) {
                 map['alternates'] = [
                   {
                     "recognizedWords": map['recognizedWords'] ?? "",
                     "confidence": 1.0,
                   }
                 ];
               }
               originalHandler?.call(jsonEncode(map));
             } catch(e) {
               debugPrint("Error repairing speech JSON on Windows: $e");
               originalHandler?.call(resultJson);
             }
           });
        };
      }

      state = state.copyWith(isAvailable: available);
    } catch (e) {
      debugPrint('[SpeechProvider] Init error: $e');
      state = state.copyWith(isAvailable: false);
    }
  }

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Start listening. Provide a [textController] so that recognised words
  /// are appended to it in real-time (live-typing effect).
  Future<void> startListening({
    required void Function(String text) onUpdate,
  }) async {
    if (!state.isAvailable) {
      // Try re-initialising in case this is first call
      await _init();
      if (!state.isAvailable) {
        debugPrint('[SpeechProvider] Speech recognition not available.');
        return;
      }
    }
    if (state.isListening) return;

    state = state.copyWith(recognizedText: '', soundLevel: 0.0);

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        Future.microtask(() {
          try {
            final words = result.recognizedWords;
            if (words.isNotEmpty) {
              state = state.copyWith(recognizedText: words);
              onUpdate(words);
            }
          } catch (e) {
            debugPrint('[SpeechProvider] Windows Result Error: $e');
          }
        });
      },
      onSoundLevelChange: (level) {
        // Clamp to a 0..1 range useful for the waveform widget
        final normalized = ((level + 2) / 12).clamp(0.0, 1.0);
        state = state.copyWith(soundLevel: normalized);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
      ),
    );

    state = state.copyWith(isListening: true);
  }

  /// Stop listening. Returns the final recognised text.
  Future<String> stopListening() async {
    await _speech.stop();
    final result = state.recognizedText;
    state = state.copyWith(isListening: false, soundLevel: 0.0);
    return result;
  }

  // ── Internal callbacks ──────────────────────────────────────────────────────

  void _onStatus(String status) {
    debugPrint('[SpeechProvider] Status: $status');
    // Plugin signals "done" / "notListening" when it stops on its own
    if (status == 'done' || status == 'notListening') {
      state = state.copyWith(isListening: false, soundLevel: 0.0);
    }
  }

  void _onError(dynamic error) {
    debugPrint('[SpeechProvider] Error: $error');
    state = state.copyWith(isListening: false, soundLevel: 0.0);
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final speechProvider =
    StateNotifierProvider<SpeechNotifier, SpeechState>(
  (ref) => SpeechNotifier(),
);
