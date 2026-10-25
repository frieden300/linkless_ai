import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A reactive waveform widget driven by a 0..1 [soundLevel] value.
///
/// When [isListening] is false the bars gently idle. When the user
/// speaks the bars grow proportionally to [soundLevel].
class VoiceWaveform extends StatefulWidget {
  final bool isListening;

  /// 0.0 → silence, 1.0 → loudest. Typically from the speech plugin
  /// after normalisation.
  final double soundLevel;

  final Color color;
  final int barCount;
  final double height;
  final double width;

  const VoiceWaveform({
    super.key,
    required this.isListening,
    this.soundLevel = 0.0,
    this.color = Colors.white,
    this.barCount = 5,
    this.height = 32,
    this.width = 48,
  });

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  static const _idleAmp = 0.2;

  @override
  void initState() {
    super.initState();
    final count = widget.barCount;
    _controllers = List.generate(count, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 80),
      )..repeat(reverse: true);
    });

    _animations = List.generate(count, (i) {
      // offset each bar's phase so they look like a wave
      final begin = _idleAmp * math.sin(i * math.pi / count).abs();
      return Tween<double>(begin: begin, end: _idleAmp).animate(
        CurvedAnimation(parent: _controllers[i], curve: Curves.easeInOut),
      );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  double _targetAmp(int index) {
    if (!widget.isListening) return _idleAmp * 0.4;
    final base = widget.soundLevel;
    // each bar gets a slightly different amp so they form a wave shape
    final factor = math.sin((index + 1) * math.pi / (widget.barCount + 1));
    return (base * factor).clamp(0.08, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: Listenable.merge(_controllers),
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(widget.barCount, (i) {
              // Blend idle animation with live sound level
              final idleFactor = _animations[i].value;
              final targetFactor = _targetAmp(i);
              // Simple lerp for smooth updates
              final factor = widget.isListening
                  ? targetFactor
                  : idleFactor;

              final barHeight = (widget.height * factor).clamp(
                4.0,
                widget.height,
              );

              return AnimatedContainer(
                duration: const Duration(milliseconds: 80),
                curve: Curves.easeOut,
                width: (widget.width / widget.barCount) * 0.55,
                height: barHeight,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(99),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
