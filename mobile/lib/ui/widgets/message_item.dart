import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../models/models.dart';
import 'common.dart';
import 'markdown_view.dart';

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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  color: AppTheme.brand,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(
                    color: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Logo(size: 28, radius: 9),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (waiting)
                  _WaitingIndicator(searchPhase: searchPhase)
                else if (searchPhase != null)
                  _SearchStrip(searchPhase: searchPhase!),
                if (showThinking) ...[
                  if (!waiting) _ReasoningBlock(variant: variant, active: isThinkingOnly),
                  if (content.isNotEmpty) const SizedBox(height: 8),
                ],
                if (content.isNotEmpty)
                  MarkdownView(
                    data: content,
                    streaming: streaming,
                  ),
                if (waiting && searchPhase != null) const SizedBox(height: 4),
                if (hasError)
                  _ErrorCard(
                    message: variant.error ?? l10n.errorOccurred,
                    onRetry: onRegenerate,
                  ),
                if (!streaming && variant.citations.isNotEmpty)
                  _Citations(citations: variant.citations),
                if (!streaming && (content.isNotEmpty || hasError))
                  _Actions(
                    message: message,
                    variant: variant,
                    isLast: isLast,
                    speaking: speaking,
                    canContinue: canContinue,
                    onCopy: onCopy,
                    onRegenerate: onRegenerate,
                    onReadAloud: onReadAloud,
                    onShare: onShare,
                    onContinue: onContinue,
                    onVariant: onVariant,
                  ),
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
        ],
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
            : '${l10n.thoughtFor} $seconds${l10n.thoughtSeconds}';
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
                Icon(
                  Icons.psychology_outlined,
                  size: 15,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
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
              : Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 2, bottom: 4),
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant, width: 0.7),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: SingleChildScrollView(
                      child: Text(
                        widget.variant.reasoning,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.65,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _Citations extends StatelessWidget {
  const _Citations({required this.citations});

  final List<Citation> citations;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = context.scheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 14, color: scheme.onSurface.withValues(alpha: 0.4)),
              const SizedBox(width: 5),
              Text(
                l10n.sources,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < citations.length; i++)
                _CitationChip(citation: citations[i], index: i + 1),
            ],
          ),
        ],
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({required this.citation, required this.index});

  final Citation citation;
  final int index;

  @override
  Widget build(BuildContext context) {
    final label = citation.siteName?.trim().isNotEmpty == true
        ? citation.siteName!
        : (citation.title?.trim().isNotEmpty == true
            ? citation.title!
            : (Uri.tryParse(citation.url)?.host ?? citation.url));
    return Material(
      color: context.scheme.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => openExternal(citation.url),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 220),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.scheme.outlineVariant, width: 0.7),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$index',
                style: const TextStyle(fontSize: 10, color: AppTheme.brand, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: context.scheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
              const SizedBox(width: 6),
              Text(
                context.l10n.errorOccurred,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.error),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: scheme.onSurface.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(context.l10n.retry),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.message,
    required this.variant,
    required this.isLast,
    required this.speaking,
    required this.canContinue,
    required this.onCopy,
    required this.onRegenerate,
    required this.onReadAloud,
    required this.onShare,
    required this.onContinue,
    required this.onVariant,
  });

  final ChatMessage message;
  final MessageVariant variant;
  final bool isLast;
  final bool speaking;
  final bool canContinue;
  final VoidCallback onCopy;
  final VoidCallback onRegenerate;
  final VoidCallback onReadAloud;
  final VoidCallback onShare;
  final VoidCallback onContinue;
  final ValueChanged<int> onVariant;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = context.scheme.onSurface.withValues(alpha: 0.42);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          _ActionIcon(
            icon: Icons.content_copy_rounded,
            tooltip: l10n.copy,
            color: color,
            onPressed: onCopy,
          ),
          if (isLast)
            _ActionIcon(
              icon: Icons.refresh_rounded,
              tooltip: l10n.regenerate,
              color: color,
              onPressed: onRegenerate,
            ),
          _ActionIcon(
            icon: speaking ? Icons.stop_circle_outlined : Icons.volume_up_outlined,
            tooltip: speaking ? l10n.stopReading : l10n.readAloud,
            color: speaking ? AppTheme.brand : color,
            onPressed: onReadAloud,
          ),
          _ActionIcon(
            icon: Icons.ios_share_rounded,
            tooltip: l10n.share,
            color: color,
            onPressed: onShare,
          ),
          if (canContinue)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: TextButton.icon(
                onPressed: onContinue,
                icon: const Icon(Icons.play_arrow_rounded, size: 15),
                label: Text(l10n.continueGeneration, style: const TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  foregroundColor: color,
                ),
              ),
            ),
          const Spacer(),
          if (message.variants.length > 1)
            Container(
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
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
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      child: Icon(Icons.chevron_right_rounded, size: 16, color: color),
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
      icon: Icon(icon, size: 17),
      color: color,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}
