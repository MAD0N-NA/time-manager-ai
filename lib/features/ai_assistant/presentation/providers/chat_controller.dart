import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/repositories/ai_conversation_repository.dart';
import '../../data/claude_api_client.dart';

class ChatState {
  ChatState({
    this.messages = const <ChatMessage>[],
    this.isLoading = false,
    this.error,
    this.conversationId,
  });

  final List<ChatMessage> messages;
  final bool isLoading;
  final String? error;
  final String? conversationId;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    String? error,
    String? conversationId,
    bool clearError = false,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        conversationId: conversationId ?? this.conversationId,
      );
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._client, this._repo) : super(ChatState());

  final ClaudeApiClient _client;
  final AiConversationRepository _repo;

  static const String _generalSystemPrompt = '''
Ты — личный AI-ассистент по тайм-менеджменту в мобильном приложении.
Помогай пользователю планировать день, расставлять приоритеты, мотивируй и поддерживай.
Отвечай по-русски, кратко и по делу. Если нужно создать задачу — попроси пользователя нажать кнопку "Создать задачу" внизу.
''';

  Future<void> initIfNeeded() async {
    if (state.conversationId != null) return;
    final String id = await _repo.createConversation();
    state = state.copyWith(conversationId: id);
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    await initIfNeeded();

    final ChatMessage userMsg = ChatMessage(role: 'user', content: text.trim());
    state = state.copyWith(
      messages: <ChatMessage>[...state.messages, userMsg],
      isLoading: true,
      clearError: true,
    );
    await _repo.appendMessage(state.conversationId!, userMsg);

    final List<ClaudeMessage> apiMessages = state.messages
        .where((ChatMessage m) => m.role != 'system')
        .map((ChatMessage m) => ClaudeMessage(role: m.role, content: m.content))
        .toList();

    final Result<ClaudeResponse> result = await _client.sendMessage(
      ClaudeRequest(
        messages: apiMessages,
        system: _generalSystemPrompt,
        maxTokens: 1024,
      ),
    );

    await result.when<Future<void>>(
      success: (ClaudeResponse r) async {
        final ChatMessage assistantMsg = ChatMessage(role: 'assistant', content: r.text);
        state = state.copyWith(
          messages: <ChatMessage>[...state.messages, assistantMsg],
          isLoading: false,
        );
        await _repo.appendMessage(state.conversationId!, assistantMsg);
      },
      failure: (Failure f) async {
        appLogger.e('Chat error: ${f.message}');
        state = state.copyWith(isLoading: false, error: f.message);
      },
    );
  }

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> resetConversation() async {
    state = ChatState();
    await initIfNeeded();
  }
}

final StateNotifierProvider<ChatController, ChatState> chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((Ref ref) {
  return ChatController(
    ref.watch(claudeApiClientProvider),
    ref.watch(aiConversationRepositoryProvider),
  );
});
