import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:linkless_ai/core/app_theme.dart';
import 'code_block.dart';
import 'markdown_latex.dart';

class MessageRenderer extends StatelessWidget {
  final String message;
  final bool isUser;

  const MessageRenderer({
    super.key,
    required this.message,
    required this.isUser,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isEmpty) return const SizedBox.shrink();

    String parsedMessage = message;

    // Auto-close open code blocks for streaming
    final codeBlockMatches = RegExp(r'```').allMatches(message).length;
    if (codeBlockMatches % 2 != 0) {
      parsedMessage += '\n```';
    }

    // Auto-close open LaTeX blocks for streaming
    final latexBlockMatches = RegExp(r'\$\$').allMatches(message).length;
    if (latexBlockMatches % 2 != 0) {
      parsedMessage += '\n\$\$';
    }

    // Auto-close open LaTeX environment blocks \[ ... \]
    final bracketMatches = RegExp(r'\\\[|\\\]').allMatches(message);
    int bracketBalance = 0;
    for (final match in bracketMatches) {
      if (match.group(0) == r'\[') {
        bracketBalance++;
      } else {
        bracketBalance--;
      }
    }
    if (bracketBalance > 0) {
      parsedMessage += r'\]';
    }

    return DefaultTextStyle(
      style: const TextStyle(
        color: Color(0xFFE8E8E8),
        fontSize: 15,
        height: 1.6,
      ),
      child: MarkdownBody(
        data: parsedMessage,
        selectable: false, // Handled seamlessly by SelectionArea via Text.rich
        extensionSet:
            md.ExtensionSet(md.ExtensionSet.gitHubFlavored.blockSyntaxes, [
              md.EmojiSyntax(),
              if (!isUser) LatexSyntax(),
              ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
            ]),
        builders: {
          if (!isUser) 'latex': LatexElementBuilder(),
          'code': CodeElementBuilder(isUser: isUser),
        },
        styleSheet: MarkdownStyleSheet(
          // ── Paragraph ──────────────────────────────────────────────────────
          p: const TextStyle(
            color: Color(0xFFE8E8E8),
            fontSize: 15,
            height: 1.6,
          ),
          // ── Inline code ────────────────────────────────────────────────────
          code: TextStyle(
            color: const Color(0xFFF1F5F9),
            fontFamily: 'monospace',
            fontSize: 15, // match paragraph so inline code doesn't look tiny
            background: Paint()
              ..color = Colors.white.withValues(alpha: 0.08)
              ..style = PaintingStyle.fill,
          ),
          codeblockDecoration: const BoxDecoration(color: Colors.transparent),
          codeblockPadding: EdgeInsets.zero,
          // ── Headings ───────────────────────────────────────────────────────
          h1: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
            height: 1.4,
          ),
          h2: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            height: 1.4,
          ),
          h3: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            height: 1.4,
          ),
          h4: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            height: 1.4,
          ),
          h5: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
            height: 1.4,
          ),
          h6: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontWeight: FontWeight.w600,
            fontSize: 14,
            height: 1.4,
          ),
          // ── Inline formatting ──────────────────────────────────────────────
          // fontSize MUST be set here – flutter_markdown sometimes fails to
          // inherit it from the parent paragraph style when merging TextSpans.
          strong: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
          em: const TextStyle(
            color: Color(0xFFE8E8E8),
            fontStyle: FontStyle.italic,
            fontSize: 15,
          ),
          // ── Blockquote ─────────────────────────────────────────────────────
          blockquote: const TextStyle(
            color: Color(0xFFB0B0B0),
            fontStyle: FontStyle.italic,
            fontSize: 15,
          ),
          blockquoteDecoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(4),
            border: Border(left: BorderSide(color: AppTheme.primary, width: 3)),
          ),
          blockquotePadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          // ── Table ──────────────────────────────────────────────────────────
          tableHead: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          tableBody: const TextStyle(
            color: Color(0xFFE8E8E8),
            fontSize: 14,
          ),
          tableHeadAlign: TextAlign.left,
          tableBorder: TableBorder.all(
            color: Colors.white24,
            width: 1,
            borderRadius: BorderRadius.circular(4),
          ),
          tableCellsPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          tableColumnWidth: const FlexColumnWidth(),
          // ── Horizontal rule ────────────────────────────────────────────────
          horizontalRuleDecoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              ),
            ),
          ),
          blockSpacing: 16,
          listIndent: 24,
          listBullet: const TextStyle(color: Color(0xFFE8E8E8), fontSize: 15),
        ),
      ),
    );
  }
}

class CodeElementBuilder extends MarkdownElementBuilder {
  final bool isUser;
  CodeElementBuilder({this.isUser = false});

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // If it's a user message, we don't want to show the custom code block widget
    // with the copy button etc. We'll return null to let it fall back to standard
    // markdown rendering (which will just be a simple styled text block).
    if (isUser) return null;

    String language = '';
    String content = element.textContent;

    if (element.attributes['class'] != null) {
      String cls = element.attributes['class']!;
      if (cls.startsWith('language-')) {
        language = cls.substring(9);
      }
    }

    // Determine if this is block code (multi-line or has language classification)
    bool isBlock = element.attributes['class'] != null || content.contains('\n');

    if (isBlock) {
      return CodeBlockWidget(language: language, code: content);
    }

    // IMPORTANT: Return null for inline code. This prevents the _inlines.isEmpty / 
    // _elements.contains assertion errors and allows flutter_markdown to use 
    // standard TextSpans for inline code (fixing the baseline offset issue natively).
    return null;
  }
}
