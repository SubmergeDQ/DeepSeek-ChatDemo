import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart' as launcher;

import '../../core/theme.dart';

class MarkdownView extends StatefulWidget {
  const MarkdownView({
    super.key,
    required this.data,
    this.streaming = false,
    this.selectable = true,
  });

  final String data;
  final bool streaming;
  final bool selectable;

  @override
  State<MarkdownView> createState() => _MarkdownViewState();
}

class _MarkdownViewState extends State<MarkdownView> {
  String _display = '';
  Timer? _timer;
  String _pending = '';

  @override
  void initState() {
    super.initState();
    _display = widget.data;
    _pending = widget.data;
  }

  @override
  void didUpdateWidget(covariant MarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data == _pending && !widget.streaming) return;
    _pending = widget.data;
    if (!widget.streaming) {
      _timer?.cancel();
      if (_display != _pending) {
        setState(() => _display = _pending);
      }
      return;
    }
    _timer ??= Timer(const Duration(milliseconds: 60), () {
      _timer = null;
      if (!mounted) return;
      if (_display != _pending) {
        setState(() => _display = _pending);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final styleSheet = MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: TextStyle(
        fontSize: 16,
        height: 1.72,
        color: theme.colorScheme.onSurface,
      ),
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: theme.colorScheme.onSurface,
      ),
      h2: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        height: 1.4,
        color: theme.colorScheme.onSurface,
      ),
      h3: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.45,
        color: theme.colorScheme.onSurface,
      ),
      h4: TextStyle(
        fontSize: 16.5,
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
      strong: const TextStyle(fontWeight: FontWeight.w700),
      em: const TextStyle(fontStyle: FontStyle.italic),
      a: const TextStyle(
        color: AppTheme.brand,
        decoration: TextDecoration.none,
      ),
      code: TextStyle(
        fontFamily: 'monospace',
        fontSize: 13.5,
        backgroundColor: isDark ? const Color(0xFF2A2C34) : const Color(0xFFF0F2F7),
        color: isDark ? const Color(0xFFE6E8EF) : const Color(0xFF24262E),
      ),
      blockquote: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
        fontSize: 15.5,
        height: 1.65,
      ),
      blockquoteDecoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2127) : const Color(0xFFF5F6FA),
        border: Border(
          left: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      listBullet: TextStyle(
        fontSize: 16,
        height: 1.72,
        color: theme.colorScheme.onSurface,
      ),
      tableHead: TextStyle(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
        fontSize: 14.5,
      ),
      tableBody: TextStyle(
        color: theme.colorScheme.onSurface,
        fontSize: 14.5,
      ),
      tableBorder: TableBorder.all(
        color: theme.colorScheme.outlineVariant,
        width: 0.8,
      ),
      tableCellsPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.8),
        ),
      ),
      blockSpacing: 10,
    );
    return MarkdownBody(
      data: _display,
      selectable: widget.selectable,
      styleSheet: styleSheet,
      builders: {
        'pre': _CodeBlockBuilder(),
        'math': _MathBuilder(block: false),
        'math-block': _MathBuilder(block: true),
      },
      extensionSet: md.ExtensionSet(
        [...md.ExtensionSet.gitHubWeb.blockSyntaxes, _MathBlockSyntax()],
        [...md.ExtensionSet.gitHubWeb.inlineSyntaxes, _MathInlineSyntax()],
      ),
      onTapLink: (text, href, title) async {
        if (href == null || href.isEmpty) return;
        await openExternal(href);
      },
    );
  }
}

Future<void> openExternal(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  try {
    await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
  } catch (_) {
    // 无法打开链接时忽略。
  }
}

class _CodeBlockBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final codeElement = element.children
        ?.whereType<md.Element>()
        .firstWhereOrNull((child) => child.tag == 'code');
    final className = codeElement?.attributes['class'] ?? '';
    final languageMatch = RegExp(r'language-([\w+#.-]+)').firstMatch(className);
    final language = languageMatch?.group(1) ?? '';
    final code = (codeElement?.textContent ?? element.textContent).replaceFirst(RegExp(r'\n$'), '');
    if (language == 'math' || language == 'latex' || language == 'tex') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        ),
        child: Math.tex(code, mathStyle: MathStyle.display),
      );
    }
    return CodeBlock(code: code, language: language);
  }
}

class CodeBlock extends StatelessWidget {
  const CodeBlock({super.key, required this.code, this.language = ''});

  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF17181D) : const Color(0xFFF8F9FC);
    final languageLabel = language.isEmpty ? 'text' : language;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(left: 12, right: 4, top: 2, bottom: 2),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  width: 0.7,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  languageLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  tooltip: 'Copy',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!context.mounted) return;
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      SnackBar(
                        content: Text(
                          Localizations.localeOf(context).languageCode == 'zh' ? '已复制' : 'Copied',
                        ),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.content_copy_rounded,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: HighlightView(
              code,
              language: language.isEmpty ? 'plaintext' : language,
              theme: isDark ? atomOneDarkTheme : githubTheme,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              textStyle: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MathBuilder extends MarkdownElementBuilder {
  _MathBuilder({required this.block});

  final bool block;

  @override
  bool isBlockElement() => block;

  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final tex = element.textContent.trim();
    if (tex.isEmpty) return null;
    return Padding(
      padding: block
          ? const EdgeInsets.symmetric(vertical: 10, horizontal: 2)
          : const EdgeInsets.symmetric(horizontal: 1),
      child: Math.tex(
        tex,
        mathStyle: block ? MathStyle.display : MathStyle.text,
        textStyle: TextStyle(
          fontSize: block ? 18 : 16,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}

class _MathInlineSyntax extends md.InlineSyntax {
  _MathInlineSyntax() : super(r'\$(?!\$)([^\s$](?:[^$\n]*?[^\s$])?)\$(?!\$)');

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final tex = match.group(1)?.trim() ?? '';
    if (tex.isEmpty) return false;
    parser.addNode(md.Element('math', [md.Text(tex)]));
    return true;
  }
}

class _MathBlockSyntax extends md.BlockSyntax {
  @override
  RegExp get pattern => RegExp(r'^\s*\$\$');

  @override
  md.Node? parse(md.BlockParser parser) {
    final first = parser.current.content;
    final singleLine = RegExp(r'^\s*\$\$(.+?)\$\$\s*$').firstMatch(first);
    if (singleLine != null) {
      parser.advance();
      return md.Element('math-block', [md.Text(singleLine.group(1)!.trim())]);
    }
    final buffer = StringBuffer();
    final rest = first.replaceFirst(RegExp(r'^\s*\$\$'), '').trim();
    if (rest.isNotEmpty) {
      buffer.writeln(rest);
    }
    parser.advance();
    while (!parser.isDone) {
      final line = parser.current.content;
      final end = line.indexOf(r'$$');
      if (end >= 0) {
        final before = line.substring(0, end).trim();
        if (before.isNotEmpty) buffer.writeln(before);
        parser.advance();
        break;
      }
      buffer.writeln(line);
      parser.advance();
    }
    return md.Element('math-block', [md.Text(buffer.toString().trim())]);
  }
}
