import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';

const Uuid _uuid = Uuid();

/// Сообщение в разговоре с AI.
class ChatMessage {
  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  final String role; // 'user' | 'assistant' | 'system'
  final String content;
  final DateTime timestamp;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class AiConversationRepository {
  AiConversationRepository(this._db);
  final AppDatabase _db;

  Stream<List<AiConversationRow>> watchAll() {
    final SimpleSelectStatement<$AiConversationsTable, AiConversationRow> q =
        _db.select(_db.aiConversations)
          ..orderBy(<OrderClauseGenerator<$AiConversationsTable>>[
            ($AiConversationsTable c) => OrderingTerm.desc(c.updatedAt),
          ]);
    return q.watch();
  }

  Future<String> createConversation({String title = 'Новый разговор'}) async {
    final String id = _uuid.v4();
    await _db.into(_db.aiConversations).insert(
          AiConversationsCompanion.insert(
            id: id,
            title: Value<String>(title),
          ),
        );
    return id;
  }

  Future<List<ChatMessage>> getMessages(String conversationId) async {
    final AiConversationRow? row = await (_db.select(_db.aiConversations)
          ..where(($AiConversationsTable c) => c.id.equals(conversationId)))
        .getSingleOrNull();
    if (row == null) return <ChatMessage>[];
    final List<dynamic> raw = jsonDecode(row.messages) as List<dynamic>;
    return raw
        .map((dynamic e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> appendMessage(String conversationId, ChatMessage message) async {
    final List<ChatMessage> existing = await getMessages(conversationId);
    existing.add(message);
    await (_db.update(_db.aiConversations)
          ..where(($AiConversationsTable c) => c.id.equals(conversationId)))
        .write(
      AiConversationsCompanion(
        messages: Value<String>(jsonEncode(existing.map((ChatMessage m) => m.toJson()).toList())),
        updatedAt: Value<DateTime>(DateTime.now()),
      ),
    );
  }

  Future<void> delete(String id) =>
      (_db.delete(_db.aiConversations)..where(($AiConversationsTable c) => c.id.equals(id))).go();
}

final Provider<AiConversationRepository> aiConversationRepositoryProvider =
    Provider<AiConversationRepository>((Ref ref) {
  return AiConversationRepository(ref.watch(appDatabaseProvider));
});
