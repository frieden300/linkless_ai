import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';

class LatexSyntax extends md.InlineSyntax {
  LatexSyntax()
    : super(
        r'(\$\$[\s\S]*?\$\$)|((?<!\$)\$(?!\$)[^$]+?(?<!\$)\$(?!\$))|(\\\[[\s\S]*?\\\])|(\\\([\s\S]*?\\\))|(\\\w+\{[\s\S]*?\})',
      );

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final matchText = match[0]!;

    // Determine the content based on the delimiter type
    String content = '';
    bool isBlock = false;

    if (matchText.startsWith(r'$$')) {
      content = matchText.substring(2, matchText.length - 2);
      isBlock = true;
    } else if (matchText.startsWith(r'$')) {
      content = matchText.substring(1, matchText.length - 1);
    } else if (matchText.startsWith(r'\[')) {
      content = matchText.substring(2, matchText.length - 2);
      isBlock = true;
    } else if (matchText.startsWith(r'\(')) {
      content = matchText.substring(2, matchText.length - 2);
    } else if (matchText.startsWith(r'\')) {
      // Direct command like \textit{code} - keep the whole command but treat as math
      content = matchText;
    }

    final element = md.Element.text('latex', content);
    element.attributes['style'] = isBlock ? 'display' : 'text';

    parser.addNode(element);
    return true;
  }
}

class LatexElementBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final content = element.textContent;
    final isDisplay = element.attributes['style'] == 'display';

    Widget mathWidget = Math.tex(
      content,
      textStyle: preferredStyle?.copyWith(
        color: Colors.white,
        fontSize: isDisplay
            ? (preferredStyle.fontSize ?? 16) * 1.15
            : (preferredStyle.fontSize ?? 16),
        fontWeight: FontWeight.w400,
      ),
      mathStyle: isDisplay ? MathStyle.display : MathStyle.text,
    );

    // Apply color explicitly via DefaultTextStyle as a fallback
    mathWidget = DefaultTextStyle.merge(
      style: const TextStyle(color: Colors.white),
      child: mathWidget,
    );

    // Clean white spaces and newlines for the selection overlay to avoid gaps
    final cleanContent = content.trim().replaceAll('\n', ' ');
    final rawText = isDisplay ? '\$\$$cleanContent\$\$' : '\$$cleanContent\$';

    Widget selectableMath = Stack(
      alignment: Alignment.center,
      children: [
        SelectionContainer.disabled(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: mathWidget,
          ),
        ),
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.fill,
            child: Text(
              rawText,
              style: const TextStyle(
                color: Colors.transparent,
                fontSize: 20, // larger base size
              ),
            ),
          ),
        ),
      ],
    );

    // For display math, we want it to be block-level and centered
    if (isDisplay) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(
          vertical: 4,
        ), // Reduced from 12 to prevent double-spacing
        alignment: Alignment.center,
        child: selectableMath,
      );
    }

    // For inline math, we need to ensure it doesn't block text selection gestures.
    return Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: selectableMath,
            ),
          ),
        ],
      ),
    );
  }
}
