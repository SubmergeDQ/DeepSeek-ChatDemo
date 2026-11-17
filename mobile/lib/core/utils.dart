import 'dart:math';

final Random _random = Random();

/// 生成本地唯一 ID。
String newId() {
  final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
  final rand = _random.nextInt(0x7fffffff).toRadixString(36);
  return '$now$rand';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

String conversationTitleFrom(String text) {
  final cleaned = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.isEmpty) return '';
  final runes = cleaned.runes.toList();
  if (runes.length <= 30) return cleaned;
  return '${String.fromCharCodes(runes.take(30))}…';
}

/// 按本地时间把会话分组：今天、昨天、近 7 天、近 30 天、更早。
String dateGroupLabel(DateTime time, DateTime now, {required bool zh}) {
  final day = DateTime(time.year, time.month, time.day);
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return zh ? '今天' : 'Today';
  if (diff == 1) return zh ? '昨天' : 'Yesterday';
  if (diff <= 7) return zh ? '近 7 天' : 'Previous 7 days';
  if (diff <= 30) return zh ? '近 30 天' : 'Previous 30 days';
  return zh ? '更早' : 'Earlier';
}

/// 去掉 Markdown 标记，用于朗读与分享预览。
String stripMarkdown(String input) {
  var text = input;
  text = text.replaceAll(RegExp(r'```[\s\S]*?```'), ' ');
  text = text.replaceAll(RegExp(r'`([^`]*)`'), r'$1');
  text = text.replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), ' ');
  text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
  text = text.replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '');
  text = text.replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '');
  text = text.replaceAll(RegExp(r'[*_~]'), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

bool looksLikeImage(String mimeType, String name) {
  if (mimeType.startsWith('image/')) return true;
  final lower = name.toLowerCase();
  return lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.bmp');
}

String fileExtension(String name) {
  final index = name.lastIndexOf('.');
  if (index <= 0 || index == name.length - 1) return '';
  return name.substring(index).toLowerCase();
}

String mimeForName(String name) {
  switch (fileExtension(name)) {
    case '.png':
      return 'image/png';
    case '.jpg':
    case '.jpeg':
      return 'image/jpeg';
    case '.webp':
      return 'image/webp';
    case '.gif':
      return 'image/gif';
    case '.bmp':
      return 'image/bmp';
    case '.pdf':
      return 'application/pdf';
    case '.doc':
      return 'application/msword';
    case '.docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case '.ppt':
      return 'application/vnd.ms-powerpoint';
    case '.pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case '.txt':
      return 'text/plain';
    case '.md':
      return 'text/markdown';
    case '.json':
      return 'application/json';
    case '.csv':
      return 'text/csv';
    case '.html':
      return 'text/html';
    case '.xml':
      return 'application/xml';
    default:
      return 'application/octet-stream';
  }
}

bool isTextLike(String name, String mimeType) {
  if (mimeType.startsWith('text/')) return true;
  if (mimeType == 'application/json' || mimeType == 'application/xml') return true;
  const exts = {
    '.dart',
    '.js',
    '.ts',
    '.tsx',
    '.jsx',
    '.py',
    '.java',
    '.kt',
    '.go',
    '.rs',
    '.c',
    '.h',
    '.cpp',
    '.cs',
    '.php',
    '.rb',
    '.swift',
    '.sh',
    '.ps1',
    '.sql',
    '.yaml',
    '.yml',
    '.toml',
    '.ini',
    '.conf',
    '.log',
    '.gradle',
    '.properties',
    '.vue',
    '.css',
    '.scss',
  };
  return exts.contains(fileExtension(name));
}
