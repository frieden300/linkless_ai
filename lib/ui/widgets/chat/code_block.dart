import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import '../../../../core/app_theme.dart';

class CodeBlockWidget extends StatelessWidget {
  final String language;
  final String code;

  const CodeBlockWidget({
    super.key,
    required this.language,
    required this.code,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(
          0xFF0F172A,
        ).withValues(alpha: 0.8), // Deep navy matching app bg
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Bar
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.4), // Glassy surface
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Language Label
                if (language.isNotEmpty)
                  Text(
                    language.toUpperCase(),
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  )
                else
                  const SizedBox(),

                // Copy Button
                _CopyButton(code: code),
              ],
            ),
          ),

          // Code Content
          SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            scrollDirection: Axis.horizontal,
            child: Stack(
              children: [
                // Highlighted visual layer (disabled for selection to avoid conflicts)
                SelectionContainer.disabled(
                  child: HighlightView(
                    code.trim(),
                    language: language.isEmpty ? 'plaintext' : language.toLowerCase(),
                    theme: Map<String, TextStyle>.from(atomOneDarkTheme)..addAll({
                      'root': const TextStyle(
                        backgroundColor: Colors.transparent, // remove background
                        color: Color(0xFFE2E8F0), // maintain default text color
                      ),
                    }),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ),
                // Invisible selectable text overlay layer
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: Text(
                      code.trim(),
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatefulWidget {
  final String code;

  const _CopyButton({required this.code});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _isCopied = false;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _isCopied
          ? null
          : () async {
              await Clipboard.setData(ClipboardData(text: widget.code));
              if (mounted) {
                setState(() => _isCopied = true);

                // Reset icon after delay
                Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) setState(() => _isCopied = false);
                });
              }
            },
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isCopied
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check, color: Colors.greenAccent, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Copied!',
                      style: TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      color: AppTheme.textSecondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Copy',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
