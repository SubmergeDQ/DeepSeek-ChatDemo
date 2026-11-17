import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/ext.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';
import '../../models/models.dart';
import '../../services/files/attachment_service.dart';
import '../../services/speech/speech_service.dart';
import '../../state/chat_controller.dart';
import 'common.dart';

class ChatInput extends StatefulWidget {
  const ChatInput({
    super.key,
    required this.controller,
    required this.conversationId,
    required this.draft,
    required this.onOpenSettings,
  });

  final ChatController controller;
  final String conversationId;
  final String draft;
  final VoidCallback onOpenSettings;

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _text = TextEditingController();
  final FocusNode _focus = FocusNode();
  final List<Attachment> _attachments = [];
  Timer? _recordTimer;
  bool _recording = false;
  bool _transcribing = false;
  int _recordSeconds = 0;

  @override
  void initState() {
    super.initState();
    _text.text = widget.draft;
    _text.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant ChatInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      if (_recording) {
        _recordTimer?.cancel();
        context.read<SpeechService>().cancelRecording();
      }
      _text.removeListener(_onTextChanged);
      _text.text = widget.draft;
      _text.addListener(_onTextChanged);
      _attachments.clear();
      _recording = false;
      _transcribing = false;
      _recordSeconds = 0;
    }
  }

  void _onTextChanged() {
    final controller = widget.controller;
    controller.setDraft(_text.text);
    setState(() {});
  }

  @override
  void dispose() {
    _text
      ..removeListener(_onTextChanged)
      ..dispose();
    _focus.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final controller = widget.controller;
    if (controller.isStreaming) return;
    final l10n = context.l10n;
    final provider = context.read<SettingsStore>().activeProvider;
    if (_recording) {
      await _cancelRecording();
      if (!mounted) return;
    }
    final text = _text.text.trim();
    if (text.isEmpty && _attachments.isEmpty) {
      showToast(context, l10n.emptyMessage);
      return;
    }
    final files = List<Attachment>.from(_attachments);
    if (provider == null || provider.apiKey.trim().isEmpty) {
      showToast(context, l10n.noApiKeyForProvider);
      return;
    }
    _text.clear();
    setState(() => _attachments.clear());
    controller.setDraft('');
    unawaited(
      controller.send(text, attachments: files).catchError((Object error) {
        if (!mounted) return;
        _text.text = text;
        setState(() => _attachments.addAll(files));
        controller.setDraft(text);
        if (error is ChatException) {
          showToast(context, error.message);
        } else {
          showToast(context, error.toString());
        }
      }),
    );
  }

  Future<void> _addAttachment(Future<Attachment?> Function() pick) async {
    if (_attachments.length >= 4) {
      showToast(context, context.zh ? '最多添加 4 个附件' : 'Up to 4 attachments');
      return;
    }
    try {
      final attachment = await pick();
      if (attachment == null) return;
      if (!mounted) return;
      setState(() => _attachments.add(attachment));
    } on AttachmentException catch (error) {
      if (!mounted) return;
      showToast(context, error.message);
    } catch (error) {
      if (!mounted) return;
      showToast(context, error.toString());
    }
  }

  Future<void> _showAttachmentPicker() async {
    final l10n = context.l10n;
    final service = context.read<AttachmentService>();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image_outlined),
              title: Text(l10n.photo),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addAttachment(service.pickImage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: Text(l10n.file),
              subtitle: Text(
                sheetContext.zh ? '支持图片、PDF、Word、PPT 与文本文件' : 'Images, PDF, Word, PPT and text files',
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _addAttachment(service.pickDocument);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_transcribing) return;
    if (_recording) {
      await _finishRecording();
      return;
    }
    final speech = context.read<SpeechService>();
    final started = await speech.startRecording();
    if (!started) {
      if (!mounted) return;
      showToast(context, context.l10n.micPermissionDenied);
      return;
    }
    _recordSeconds = 0;
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recordSeconds += 1);
      if (_recordSeconds >= 120) {
        _finishRecording();
      }
    });
    setState(() {
      _recording = true;
      _transcribing = false;
    });
  }

  Future<void> _finishRecording() async {
    _recordTimer?.cancel();
    final speech = context.read<SpeechService>();
    final path = await speech.stopRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _transcribing = true;
    });
    if (path == null) {
      setState(() => _transcribing = false);
      return;
    }
    try {
      final text = (await widget.controller.transcribe(path))?.trim() ?? '';
      if (!mounted) return;
      if (text.isNotEmpty) {
        final existing = _text.text;
        final needsSpace = existing.isNotEmpty && !existing.endsWith(' ');
        _text.text = '$existing${needsSpace ? ' ' : ''}$text';
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      }
    } catch (error) {
      if (!mounted) return;
      showToast(
        context,
        '${context.l10n.voiceFailed}：${error is ChatException ? error.message : error}',
      );
    } finally {
      if (mounted) setState(() => _transcribing = false);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await context.read<SpeechService>().cancelRecording();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _recordSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final l10n = settings.l10n;
    final provider = settings.activeProvider;
    final model = settings.activeModel;
    final controller = widget.controller;
    final scheme = context.scheme;
    final hasKey = provider?.apiKey.trim().isNotEmpty ?? false;
    final canThink = model?.thinking ?? false;
    final canSearch = settings.canUseSearch;
    final canVoice = provider?.type.supportsAsr ?? false;
    final isStreaming = controller.isStreaming;
    final hasContent = _text.text.trim().isNotEmpty || _attachments.isNotEmpty;
    final images = _attachments.where((item) => item.isImage).toList();
    final files = _attachments.where((item) => !item.isImage).toList();

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!hasKey)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: AppTheme.brand.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onOpenSettings,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        child: Row(
                          children: [
                            const Icon(Icons.key_rounded, size: 15, color: AppTheme.brand),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                l10n.noApiKeyForProvider,
                                style: const TextStyle(fontSize: 12, color: AppTheme.brand),
                              ),
                            ),
                            Text(
                              l10n.goSettings,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.brand,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scheme.outlineVariant, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (images.isNotEmpty || files.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final image in images) _DraftImage(attachment: image, onRemove: () => _remove(image)),
                            for (final file in files) _DraftFile(attachment: file, onRemove: () => _remove(file)),
                          ],
                        ),
                      ),
                    if (_recording)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_recordSeconds),
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.recordingHint,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: scheme.onSurface.withValues(alpha: 0.45),
                                ),
                              ),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _cancelRecording,
                              icon: const Icon(Icons.close_rounded, size: 18),
                              color: scheme.onSurface.withValues(alpha: 0.5),
                            ),
                            FilledButton(
                              onPressed: _finishRecording,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                              child: Text(l10n.done, style: const TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    if (_transcribing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.brand),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.transcribing,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurface.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                      ),
                    TextField(
                      controller: _text,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(fontSize: 15.5, height: 1.45),
                      decoration: InputDecoration(
                        hintText: l10n.inputHint,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        IconButton(
                          onPressed: isStreaming ? null : _showAttachmentPicker,
                          icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
                          color: scheme.onSurface.withValues(alpha: 0.5),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          tooltip: l10n.attach,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                if (canThink)
                                  _ToggleChip(
                                    icon: Icons.psychology_outlined,
                                    label: l10n.deepThink,
                                    active: settings.thinking,
                                    onTap: () => settings.setThinking(!settings.thinking),
                                  ),
                                if (canThink && canSearch) const SizedBox(width: 6),
                                if (canSearch)
                                  _ToggleChip(
                                    icon: Icons.travel_explore_rounded,
                                    label: l10n.webSearch,
                                    active: settings.search,
                                    onTap: () => settings.setSearch(!settings.search),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        if (canVoice)
                          IconButton(
                            onPressed: isStreaming ? null : _toggleRecording,
                            icon: Icon(
                              _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                              size: 22,
                            ),
                            color: _recording
                                ? Colors.redAccent
                                : scheme.onSurface.withValues(alpha: 0.5),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                            tooltip: l10n.voice,
                          ),
                        const SizedBox(width: 4),
                        if (isStreaming)
                          _CircleButton(
                            icon: Icons.stop_rounded,
                            background: AppTheme.brand,
                            foreground: Colors.white,
                            onTap: controller.stop,
                            tooltip: l10n.stopGenerating,
                          )
                        else
                          _CircleButton(
                            icon: Icons.arrow_upward_rounded,
                            background: canSendStyle(hasContent, isStreaming)
                                ? AppTheme.brand
                                : scheme.surfaceContainerHighest,
                            foreground: canSendStyle(hasContent, isStreaming)
                                ? Colors.white
                                : scheme.onSurface.withValues(alpha: 0.3),
                            onTap: canSendStyle(hasContent, isStreaming) ? _send : null,
                            tooltip: l10n.send,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool canSendStyle(bool hasContent, bool isStreaming) => hasContent && !isStreaming;

  void _remove(Attachment attachment) {
    setState(() => _attachments.removeWhere((item) => item.id == attachment.id));
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _DraftImage extends StatelessWidget {
  const _DraftImage({required this.attachment, required this.onRemove});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final path = attachment.localPath;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: path != null && File(path).existsSync()
              ? Image.file(
                  File(path),
                  width: 58,
                  height: 58,
                  fit: BoxFit.cover,
                )
              : Container(
                  width: 58,
                  height: 58,
                  color: context.scheme.surfaceContainerHighest,
                  child: const Icon(Icons.image_outlined, size: 20),
                ),
        ),
        Positioned(
          right: -6,
          top: -6,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _DraftFile extends StatelessWidget {
  const _DraftFile({required this.attachment, required this.onRemove});

  final Attachment attachment;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.fromLTRB(9, 6, 4, 6),
      decoration: BoxDecoration(
        color: context.scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 16,
            color: context.scheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: context.scheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: context.scheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Material(
      color: active ? AppTheme.brand.withValues(alpha: 0.1) : Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active
                  ? AppTheme.brand.withValues(alpha: 0.35)
                  : scheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? AppTheme.brand : scheme.onSurface.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: active ? AppTheme.brand : scheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 19, color: foreground),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}
