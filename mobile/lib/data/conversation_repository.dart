import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// 会话与消息的本地 SQLite 存储。
class ConversationRepository {
  Database? _db;

  Future<Database> _open() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final db = await openDatabase(
      p.join(dir, 'deepchat.db'),
      version: 1,
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            data TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            seq INTEGER NOT NULL,
            data TEXT NOT NULL
          )
        ''');
        await database.execute(
          'CREATE INDEX idx_messages_conversation ON messages(conversation_id, seq)',
        );
      },
    );
    _db = db;
    return db;
  }

  Future<List<ConversationSummary>> listConversations() async {
    final db = await _open();
    final rows = await db.query(
      'conversations',
      columns: ['id', 'title', 'created_at', 'updated_at'],
      orderBy: 'updated_at DESC',
    );
    return rows
        .map((row) => ConversationSummary(
              id: row['id'] as String,
              title: row['title'] as String? ?? '',
              createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
              updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  Future<Conversation?> loadConversation(String id) async {
    final db = await _open();
    final rows = await db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    Map<String, dynamic> data;
    try {
      data = jsonDecode(row['data'] as String) as Map<String, dynamic>;
    } catch (_) {
      data = <String, dynamic>{};
    }
    final messageRows = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [id],
      orderBy: 'seq ASC',
    );
    final messages = <ChatMessage>[];
    for (final messageRow in messageRows) {
      try {
        messages.add(
          ChatMessage.fromJson(
            jsonDecode(messageRow['data'] as String) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        // 跳过损坏的消息。
      }
    }
    return Conversation(
      id: row['id'] as String,
      title: row['title'] as String? ?? '',
      createdAt: (row['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (row['updated_at'] as num?)?.toInt() ?? 0,
      draft: data['draft'] as String? ?? '',
      titleAuto: data['titleAuto'] as bool? ?? true,
      messages: messages,
    );
  }

  Future<void> saveConversation(Conversation conversation) async {
    final db = await _open();
    await db.insert(
      'conversations',
      {
        'id': conversation.id,
        'title': conversation.title,
        'created_at': conversation.createdAt,
        'updated_at': conversation.updatedAt,
        'data': jsonEncode({
          'draft': conversation.draft,
          'titleAuto': conversation.titleAuto,
        }),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMessage(
    String conversationId,
    int seq,
    ChatMessage message,
  ) async {
    final db = await _open();
    await db.insert(
      'messages',
      {
        'id': message.id,
        'conversation_id': conversationId,
        'seq': seq,
        'data': jsonEncode(message.toJson()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> replaceMessages(
    String conversationId,
    List<ChatMessage> messages,
  ) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete(
        'messages',
        where: 'conversation_id = ?',
        whereArgs: [conversationId],
      );
      for (var i = 0; i < messages.length; i++) {
        await txn.insert('messages', {
          'id': messages[i].id,
          'conversation_id': conversationId,
          'seq': i,
          'data': jsonEncode(messages[i].toJson()),
        });
      }
    });
  }

  Future<void> deleteConversation(String id) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('messages', where: 'conversation_id = ?', whereArgs: [id]);
      await txn.delete('conversations', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<void> clearAll() async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
    });
  }

  Future<void> replaceAll(List<Conversation> conversations) async {
    final db = await _open();
    await db.transaction((txn) async {
      await txn.delete('messages');
      await txn.delete('conversations');
      for (final conversation in conversations) {
        await txn.insert('conversations', {
          'id': conversation.id,
          'title': conversation.title,
          'created_at': conversation.createdAt,
          'updated_at': conversation.updatedAt,
          'data': jsonEncode({
            'draft': conversation.draft,
            'titleAuto': conversation.titleAuto,
          }),
        });
        for (var i = 0; i < conversation.messages.length; i++) {
          await txn.insert('messages', {
            'id': conversation.messages[i].id,
            'conversation_id': conversation.id,
            'seq': i,
            'data': jsonEncode(conversation.messages[i].toJson()),
          });
        }
      }
    });
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
