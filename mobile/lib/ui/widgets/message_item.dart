import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import 'markdown_view.dart';
import 'search_results_sheet.dart';

class MessageItem extends StatelessWidget {
  const MessageItem({
    super.key,
    required this.message,
    required this.index,
    required this.isLast,
    required this.streaming,
    required this.searchPhase,
    required this.speaking,
    required this.canContinue,
    required this.onCopy,
    required this.onEdit,
    required this.onRegenerate,
    required this.onReadAloud,
    required this.onShare,
    required this.onContinue,
    required this.onVariant,
    required this.onFeedback,
  });

  final ChatMessage message;
  final int index;
  final bool isLast;
  final bool streaming;
  final String? searchPhase;
  final bool speaking;
  final bool canContinue;
  final VoidCallback onCopy;
  final VoidCallback onEdit;
  final VoidCallback onRegenerate;
  final VoidCallback onReadAloud;
  final VoidCallback onShare;
  final VoidCallback onContinue;
  final ValueChanged<int> onVariant;
  final ValueChanged<int> onFeedback;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _UserMessage(
        message: message,
        onLongPress: () => _showUserActions(context),
      );
    }
    return _AssistantMessage(
      message: message,
      index: index,
      isLast: isLast,
      streaming: streaming,
      searchPhase: searchPhase,
      speaking: speaking,
      canContinue: canContinue,
      onCopy: onCopy,
      onRegenerate: onRegenerate,
      onReadAloud: onReadAloud,
      onShare: onShare,
      onContinue: onContinue,
      onVariant: onVariant,
      onFeedback: onFeedback,
    );
  }

  void _showUserActions(BuildContext context) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy_rounded, size: 20),
              title: Text(l10n.copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.content));
                Navigator.of(sheetContext).pop();
                onCopy();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, size: 20),
              title: Text(l10n.edit),
              subtitle: Text(
                l10n.editMessageHint,
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onEdit();
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _UserMessage extends StatelessWidget {
  const _UserMessage({required this.message, required this.onLongPress});

  final ChatMessage message;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final images = message.attachments.where((item) => item.isImage).toList();
    final files = message.attachments.where((item) => !item.isImage).toList();
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 10, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final image in images) _ImageThumb(attachment: image),
                ],
              ),
            ),
          if (files.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final file in files) _FileChip(attachment: file),
                ],
              ),
            ),
          if (message.content.trim().isNotEmpty)
            GestureDetector(
              onLongPress: onLongPress,
              child: Container(
                constraints: BoxConstraints(maxWidth: maxWidth),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF2A2E3B)
                      : const Color(0xFFEEF1FA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15.5,
                    height: 1.55,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final path = attachment.localPath;
    if (path == null || !File(path).existsSync()) {
      return _FileChip(attachment: attachment);
    }
    return GestureDetector(
      onTap: () => _openViewer(context, path),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(path),
          width: 118,
          height: 118,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _FileChip(attachment: attachment),
        ),
      ),
    );
  }

  void _openViewer(BuildContext context, String path) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(child: Image.file(File(path))),
            ),
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            right: 12,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              style: IconButton.styleFrom(backgroundColor: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  const _FileChip({required this.attachment});

  final Attachment attachment;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_outlined, size: 18, color: scheme.onSurface.withValues(alpha: 0.55)),
          const SizedBox(width: 7),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.8)),
                ),
                Text(
                  formatBytes(attachment.size),
                  style: TextStyle(fontSize: 10.5, color: scheme.onSurface.withValues(alpha: 0.4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistantMessage extends StatelessWidget {
  const _AssistantMessage({
    required this.message,
    required this.index,
    required this.isLast,
    required this.streaming,
    required this.searchPhase,
    required this.speaking,
    required this.canContinue,
    required this.onCopy,
    required this.onRegenerate,
    required this.onReadAloud,
    required this.onShare,
    required this.onContinue,
    required this.onVariant,
    required this.onFeedback,
  });

  final ChatMessage message;
  final int index;
  final bool isLast;
  final bool streaming;
  final String? searchPhase;
  final bool speaking;
  final bool canContinue;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onReadAloud;
  final VoidCallback onShare;
  final VoidCallback onContinue;
  final ValueChanged<int> onVariant;
  final ValueChanged<int> onFeedback;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final variant = message.variant;
    if (variant == null) return const SizedBox.shrink();
    final content = variant.content;
    final reasoning = variant.reasoning;
    final hasError = variant.status == MessageStatus.error;
    final showThinking = reasoning.isNotEmpty;
    final waiting = streaming && content.isEmpty && reasoning.isEmpty;
    final isThinkingOnly = streaming && content.isEmpty && reasoning.isNotEmpty;
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: streaming || (content.isEmpty && !hasError)
            ? null
            : () => _showActions(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (waiting)
              _WaitingIndicator(searchPhase: searchPhase)
            else if (searchPhase != null)
              _SearchStrip(searchPhase: searchPhase!),
            if (showThinking) ...[
              if (!waiting) _ReasoningBlock(variant: variant, active: isThinkingOnly),
              if (content.isNotEmpty) const SizedBox(height: 6),
            ],
            if (content.isNotEmpty)
              MarkdownView(
                data: content,
                streaming: streaming,
                selectable: false,
              ),
            if (waiting && searchPhase != null) const SizedBox(height: 4),
            if (hasError)
              _ErrorCard(
                message: variant.error ?? l10n.errorOccurred,
                onRetry: onRegenerate,
              ),
            if (!streaming && variant.citations.isNotEmpty)
              _SourcesPill(citations: variant.citations),
            if (!streaming && content.isNotEmpty)
              _MessageActions(
                variant: variant,
                isLast: isLast,
                speaking: speaking,
                onFeedback: onFeedback,
                onReadAloud: onReadAloud,
                onShare: onShare,
                onRegenerate: onRegenerate,
              ),
            if (!streaming && message.variants.length > 1)
              _VariantSwitcher(message: message, onVariant: onVariant),
            if (!streaming && canContinue)
              _ContinueButton(onTap: onContinue),
            if (!streaming && variant.stopReason == 'max_tokens' && !canContinue)
              Padding(
                padding: const EdgeInsets.only(left: 2, top: 4),
                child: Text(
                  l10n.maxTokensReached,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    final l10n = context.l10n;
    final variant = message.variant;
    final hasContent = variant?.content.trim().isNotEmpty ?? false;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasContent)
              ListTile(
                leading: const Icon(Icons.content_copy_rounded, size: 20),
                title: Text(l10n.copy),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onCopy();
                },
              ),
            if (isLast)
              ListTile(
                leading: const Icon(Icons.refresh_rounded, size: 20),
                title: Text(l10n.regenerate),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onRegenerate();
                },
              ),
            if (hasContent)
              ListTile(
                leading: Icon(
                  speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
                  size: 20,
                ),
                title: Text(speaking ? l10n.stopReading : l10n.readAloud),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onReadAloud();
                },
              ),
            if (hasContent)
              ListTile(
                leading: const Icon(Icons.ios_share_rounded, size: 20),
                title: Text(l10n.share),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onShare();
                },
              ),
            if (canContinue)
              ListTile(
                leading: const Icon(Icons.play_arrow_rounded, size: 20),
                title: Text(l10n.continueGeneration),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onContinue();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _VariantSwitcher extends StatelessWidget {
  const _VariantSwitcher({required this.message, required this.onVariant});

  final ChatMessage message;
  final ValueChanged<int> onVariant;

  @override
  Widget build(BuildContext context) {
    final color = context.scheme.onSurface.withValues(alpha: 0.4);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.scheme.outlineVariant, width: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: () => onVariant(-1),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.chevron_left_rounded, size: 16, color: color),
              ),
            ),
            Text(
              '${message.activeVariant + 1}/${message.variants.length}',
              style: TextStyle(fontSize: 11, color: color),
            ),
            InkWell(
              onTap: () => onVariant(1),
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: Icon(Icons.chevron_right_rounded, size: 16, color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: TextButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.play_arrow_rounded, size: 16),
        label: Text(
          context.l10n.continueGeneration,
          style: const TextStyle(fontSize: 12),
        ),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: Size.zero,
          foregroundColor: context.scheme.onSurface.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

class _WaitingIndicator extends StatelessWidget {
  const _WaitingIndicator({this.searchPhase});

  final String? searchPhase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (searchPhase) {
      'searching' => l10n.searchInProgress,
      'reading' => l10n.readLinkInProgress,
      _ => l10n.thinking,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.scheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: context.scheme.onSurface.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchStrip extends StatelessWidget {
  const _SearchStrip({required this.searchPhase});

  final String searchPhase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: context.scheme.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.scheme.outlineVariant, width: 0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.brand),
            ),
            const SizedBox(width: 7),
            Text(
              searchPhase == 'reading' ? l10n.readLinkInProgress : l10n.searchInProgress,
              style: TextStyle(
                fontSize: 12,
                color: context.scheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasoningBlock extends StatefulWidget {
  const _ReasoningBlock({required this.variant, required this.active});

  final MessageVariant variant;
  final bool active;

  @override
  State<_ReasoningBlock> createState() => _ReasoningBlockState();
}

class _ReasoningBlockState extends State<_ReasoningBlock> {
  bool _expanded = false;
  bool _userToggled = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.active;
  }

  @override
  void didUpdateWidget(covariant _ReasoningBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userToggled) {
      final next = widget.active;
      if (next != _expanded) {
        setState(() => _expanded = next);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.scheme;
    final seconds = widget.variant.reasoningSeconds;
    final title = widget.variant.status == MessageStatus.streaming
        ? l10n.thinking
        : seconds == null
            ? l10n.thoughtFor
            : l10n.thoughtForSeconds(seconds);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() {
            _expanded = !_expanded;
            _userToggled = true;
          }),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: scheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(width: 1),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.chevron_right_rounded,
                  size: 17,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !_expanded
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 6, right: 8),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: SingleChildScrollView(
                      child: _ReasoningTimeline(variant: widget.variant),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _ReasoningTimeline extends StatelessWidget {
  const _ReasoningTimeline({required this.variant});

  final MessageVariant variant;

  @override
  Widget build(BuildContext context) {
    final paragraphs = variant.reasoning
        .split(RegExp(r'\n\s*\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final scheme = context.scheme;
    final children = <Widget>[];
    for (var i = 0; i < paragraphs.length; i++) {
      if (i > 0) children.add(const SizedBox(height: 10));
      children.add(_TimelineEntry(text: paragraphs[i]));
      if (i == 0 && variant.citations.isNotEmpty) {
        children.add(const SizedBox(height: 10));
        children.add(_SearchSummaryEntry(citations: variant.citations));
      }
      if (i == 0 && variant.didBrowsePage) {
        children.add(const SizedBox(height: 8));
        children.add(_TimelineRow(
          icon: Icons.language_rounded,
          text: context.l10n.browsePages,
        ));
      }
    }
    if (paragraphs.isEmpty && variant.citations.isNotEmpty) {
      children.add(_SearchSummaryEntry(citations: variant.citations));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.isEmpty
          ? [
              Text(
                variant.reasoning,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.65,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ]
          : children,
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 3),
          child: Container(
            width: 4.5,
            height: 4.5,
            decoration: BoxDecoration(
              color: context.scheme.onSurface.withValues(alpha: 0.28),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: context.scheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchSummaryEntry extends StatelessWidget {
  const _SearchSummaryEntry({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final sites = <Citation>[];
    final seen = <String>{};
    for (final citation in citations) {
      final name = _citationSite(citation);
      if (name.isNotEmpty && seen.add(name)) sites.add(citation);
      if (sites.length == 3) break;
    }
    return Row(
      children: [
        Icon(
          Icons.search_rounded,
          size: 15,
          color: context.scheme.onSurface.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 6),
        Text(
          '${context.l10n.searchedPages} ${context.l10n.webPagesCount(citations.length)}',
          style: TextStyle(
            fontSize: 13,
            color: context.scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        if (sites.isNotEmpty) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 18.0 + (sites.length - 1) * 10.0,
            height: 18,
            child: Stack(
              children: [
                for (var i = 0; i < sites.length; i++)
                  Positioned(
                    left: i * 10.0,
                    child: _MiniSite(
                      name: _citationSite(sites[i]),
                      iconUrl: sites[i].siteIcon,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: context.scheme.onSurface.withValues(alpha: 0.4)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: context.scheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
      ],
    );
  }
}

class _SourcesPill extends StatelessWidget {
  const _SourcesPill({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final sites = <Citation>[];
    final seen = <String>{};
    for (final citation in citations) {
      final name = _citationSite(citation);
      if (name.isNotEmpty && seen.add(name)) {
        sites.add(citation);
      }
      if (sites.length == 3) break;
    }
    final avatarsWidth = sites.isEmpty ? 0.0 : 18.0 + (sites.length - 1) * 10.0;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => showSearchResultsSheet(context, citations),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 9, 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outlineVariant, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.public_rounded,
                  size: 14,
                  color: scheme.onSurface.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 6),
                if (sites.isNotEmpty) ...[
                  SizedBox(
                    width: avatarsWidth,
                    height: 18,
                    child: Stack(
                      children: [
                        for (var i = 0; i < sites.length; i++)
                          Positioned(
                            left: i * 10.0,
                            child: _MiniSite(
                              name: _citationSite(sites[i]),
                              iconUrl: sites[i].siteIcon,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  context.l10n.webPagesCount(citations.length),
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurface.withValues(alpha: 0.62),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: scheme.onSurface.withValues(alpha: 0.35),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniSite extends StatelessWidget {
  const _MiniSite({required this.name, this.iconUrl});

  final String name;
  final String? iconUrl;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim().substring(0, 1).toUpperCase();
    final fallback = Center(
      child: Text(
        letter,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: context.scheme.onSurface.withValues(alpha: 0.55),
        ),
      ),
    );
    final url = iconUrl?.trim() ?? '';
    return Container(
      width: 18,
      height: 18,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: context.scheme.surfaceContainerHighest,
        border: Border.all(color: context.scheme.surface, width: 1.4),
      ),
      child: url.isEmpty
          ? fallback
          : Image.network(
              url,
              width: 18,
              height: 18,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => fallback,
            ),
    );
  }
}

String _citationSite(Citation citation) {
  final name = citation.siteName?.trim();
  if (name != null && name.isNotEmpty) return name;
  return Uri.tryParse(citation.url)?.host ?? '';
}

class _MessageActions extends StatelessWidget {
  const _MessageActions({
    required this.variant,
    required this.isLast,
    required this.speaking,
    required this.onFeedback,
    required this.onReadAloud,
    required this.onShare,
    required this.onRegenerate,
  });

  final MessageVariant variant;
  final bool isLast;
  final bool speaking;
  final ValueChanged<int> onFeedback;
  final VoidCallback onReadAloud;
  final VoidCallback onShare;
  final VoidCallback onRegenerate;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final color = scheme.onSurface.withValues(alpha: 0.4);
    final liked = variant.feedback == 1;
    final disliked = variant.feedback == -1;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          _ActionIcon(
            icon: liked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
            tooltip: context.l10n.like,
            color: liked ? AppTheme.brand : color,
            onPressed: () => onFeedback(1),
          ),
          _ActionIcon(
            icon: disliked ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
            tooltip: context.l10n.dislike,
            color: disliked ? AppTheme.brand : color,
            onPressed: () => onFeedback(-1),
          ),
          _ActionIcon(
            icon: speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            tooltip: speaking ? context.l10n.stopReading : context.l10n.readAloud,
            color: speaking ? AppTheme.brand : color,
            onPressed: onReadAloud,
          ),
          _ActionIcon(
            icon: Icons.ios_share_rounded,
            tooltip: context.l10n.share,
            color: color,
            onPressed: onShare,
          ),
          const Spacer(),
          if (isLast)
            _ActionIcon(
              icon: Icons.refresh_rounded,
              tooltip: context.l10n.regenerate,
              color: color,
              onPressed: onRegenerate,
            ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF202127) : const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: scheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: scheme.onSurface.withValues(alpha: 0.62),
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: AppTheme.brand,
            ),
            child: Text(context.l10n.retry, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

