import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_manager_ai/core/errors/failures.dart';
import 'package:time_manager_ai/data/models/task_model.dart';
import 'package:time_manager_ai/features/ai_assistant/data/claude_api_client.dart';
import 'package:time_manager_ai/features/ai_assistant/domain/use_cases/create_task_from_voice.dart';

/// Тестовый дублёр клиента — возвращает заранее заданный текст.
class FakeClaudeClient extends ClaudeApiClient {
  FakeClaudeClient(this.payload) : super(storage: const FlutterSecureStorage());
  final String payload;

  @override
  Future<Result<ClaudeResponse>> sendMessage(ClaudeRequest request) async {
    return Success<ClaudeResponse>(
      ClaudeResponse(
        id: 'test',
        text: payload,
        stopReason: 'end_turn',
        inputTokens: 10,
        outputTokens: 50,
        model: request.model,
      ),
    );
  }
}

void main() {
  group('CreateTaskFromVoiceUseCase', () {
    test('parses valid JSON response', () async {
      const String payload = '''{
        "title": "Купить молоко",
        "description": null,
        "dueDate": "2026-04-20T18:00:00",
        "priority": 1,
        "estimatedMinutes": 15,
        "tags": ["шопинг"]
      }''';

      final CreateTaskFromVoiceUseCase useCase =
          CreateTaskFromVoiceUseCase(FakeClaudeClient(payload));
      final Result<TaskModel> result = await useCase('Купить молоко завтра в 6 вечера');

      expect(result.isSuccess, isTrue);
      final TaskModel task = result.valueOrNull!;
      expect(task.title, 'Купить молоко');
      expect(task.priority, TaskPriority.medium);
      expect(task.estimatedMinutes, 15);
      expect(task.tags, contains('шопинг'));
    });

    test('handles markdown-wrapped JSON', () async {
      const String payload = '```json\n'
          '{"title": "Test", "description": null, "dueDate": null, '
          '"priority": 0, "estimatedMinutes": null, "tags": []}\n'
          '```';
      final CreateTaskFromVoiceUseCase useCase =
          CreateTaskFromVoiceUseCase(FakeClaudeClient(payload));
      final Result<TaskModel> result = await useCase('test');
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.title, 'Test');
      expect(result.valueOrNull!.priority, TaskPriority.low);
    });

    test('returns ParseFailure on invalid JSON', () async {
      const String payload = 'not a json at all';
      final CreateTaskFromVoiceUseCase useCase =
          CreateTaskFromVoiceUseCase(FakeClaudeClient(payload));
      final Result<TaskModel> result = await useCase('test');
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<ParseFailure>());
    });
  });
}
