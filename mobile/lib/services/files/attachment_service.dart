import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/utils.dart';
import '../../models/models.dart';

class AttachmentException implements Exception {
  AttachmentException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AttachmentService {
  static const int maxBytes = 20 * 1024 * 1024;
  static const int maxTextChars = 100000;

  Future<Attachment?> pickImage() async {
    const group = XTypeGroup(
      label: 'Images',
      extensions: ['png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp'],
      mimeTypes: ['image/*'],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return null;
    return importFile(file);
  }

  Future<Attachment?> pickDocument() async {
    const group = XTypeGroup(
      label: 'Files',
      extensions: [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'gif',
        'pdf',
        'doc',
        'docx',
        'ppt',
        'pptx',
        'txt',
        'md',
        'json',
        'csv',
        'html',
        'xml',
        'yaml',
        'yml',
        'dart',
        'js',
        'ts',
        'tsx',
        'jsx',
        'py',
        'java',
        'kt',
        'go',
        'rs',
        'c',
        'h',
        'cpp',
        'cs',
        'php',
        'rb',
        'swift',
        'sh',
        'ps1',
        'sql',
        'log',
      ],
    );
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return null;
    return importFile(file);
  }

  Future<Attachment> importFile(XFile file) async {
    final length = await file.length();
    if (length > maxBytes) {
      throw AttachmentException('文件过大（单个最大 20 MB）');
    }
    final name = file.name.isEmpty ? p.basename(file.path) : file.name;
    var mimeType = file.mimeType ?? mimeForName(name);
    if (mimeType.isEmpty || mimeType == 'application/octet-stream') {
      mimeType = mimeForName(name);
    }
    final attachmentsDir = await _attachmentsDirectory();
    final id = newId();
    final target = p.join(attachmentsDir.path, '$id${fileExtension(name)}');
    await File(file.path).copy(target);
    final isImage = looksLikeImage(mimeType, name);
    String? textContent;
    if (!isImage && isTextLike(name, mimeType)) {
      try {
        final raw = await File(target).readAsBytes();
        final text = utf8.decode(raw, allowMalformed: true);
        textContent = text.length > maxTextChars
            ? '${text.substring(0, maxTextChars)}\n…（已截断）'
            : text;
      } catch (_) {
        textContent = null;
      }
    }
    return Attachment(
      id: id,
      name: name,
      mimeType: mimeType,
      size: length,
      localPath: target,
      isImage: isImage,
      textContent: textContent,
    );
  }

  Future<Directory> _attachmentsDirectory() async {
    final dir = await getApplicationDocumentsDirectory();
    final attachmentsDir = Directory(p.join(dir.path, 'attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
    return attachmentsDir;
  }

  /// 删除会话时清理本机附件原件。
  Future<void> deleteForConversations(Iterable<Conversation> conversations) async {
    for (final conversation in conversations) {
      for (final message in conversation.messages) {
        for (final attachment in message.attachments) {
          final path = attachment.localPath;
          if (path == null || path.isEmpty) continue;
          final file = File(path);
          if (await file.exists()) {
            try {
              await file.delete();
            } catch (_) {
              // 单个文件删除失败不影响其它清理。
            }
          }
        }
      }
    }
  }

  Future<void> clearAll() async {
    final directory = await _attachmentsDirectory();
    try {
      await directory.delete(recursive: true);
    } catch (_) {
      // ignore
    }
  }
}
