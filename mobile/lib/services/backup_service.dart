import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';

class BackupException implements Exception {
  BackupException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 对话历史的 JSON 导入导出（不包含 API Key 与设置）。
class BackupService {
  Future<void> export(List<Conversation> conversations) async {
    final dir = await getTemporaryDirectory();
    final name = 'deepchat-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.json';
    final file = File(p.join(dir.path, name));
    final data = {
      'app': 'DeepChat',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'conversations': conversations.map((item) => item.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(data));
    await SharePlus.instance.share(
      ShareParams(
        text: 'DeepChat 对话备份',
        files: [XFile(file.path)],
        fileNameOverrides: [name],
      ),
    );
  }

  Future<List<Conversation>> pickAndRead() async {
    const group = XTypeGroup(label: 'JSON', extensions: ['json'], mimeTypes: ['application/json']);
    final picked = await openFile(acceptedTypeGroups: const [group]);
    if (picked == null) return [];
    final raw = await File(picked.path).readAsString();
    Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      throw BackupException('文件不是有效的 JSON');
    }
    if (decoded is! Map) {
      throw BackupException('备份文件格式不正确');
    }
    final list = decoded['conversations'];
    if (list is! List) {
      throw BackupException('备份文件中没有对话数据');
    }
    final conversations = <Conversation>[];
    for (final item in list) {
      if (item is! Map) continue;
      try {
        conversations.add(Conversation.fromJson(Map<String, dynamic>.from(item)));
      } catch (_) {
        // 跳过单条损坏数据。
      }
    }
    if (conversations.isEmpty) {
      throw BackupException('备份文件中没有可导入的对话');
    }
    return conversations;
  }
}
