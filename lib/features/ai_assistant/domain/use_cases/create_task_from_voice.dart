import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/task_model.dart';
import '../../data/claude_api_client.dart';

/// Use-case A: создание задачи из произвольного текста/голоса.
class CreateTaskFromVoiceUseCase {
  CreateTaskFromVoiceUseCase(this._client);
  final ClaudeApiClient _client;

  static const String _systemPrompt = '''
Ты помощник для создания задач в тайм-менеджере. Пользователь описывает задачу свободным текстом (по-русски или по-английски).
Твоя задача — вернуть СТРОГО валидный JSON-объект, без markdown, без объяснений, без обёрток.

Схема:
{
  "title": "string, обязательное, до 200 символов",
  "description": "string или null",
  "dueDate": "ISO8601 datetime или null (учитывай 'сегодня', 'завтра', 'в пятницу' исходя из текущего времени из контекста)",
  "priority": 0 | 1 | 2 | 3 (low/medium/high/urgent),
  "estimatedMinutes": число или null,
  "tags": ["string", ...] или []
}

Если в тексте указано конкретное время — установи dueDate. Если только дата — установи время на 09:00.
Возвращай ТОЛЬКО JSON. Никакого текста до или после.
''';

  Future<Result<TaskModel>> call(String userInput) async {
    final DateTime now = DateTime.now();
    final String contextLine = 'Текущее время: ${now.toIso8601String()}, день недели: ${_dayOfWeek(now)}';

    final ClaudeRequest req = ClaudeRequest(
      model: AppConstants.fastModel,
      maxTokens: 800,
      temperature: 0.3,
      system: _systemPrompt,
      messages: <ClaudeMessage>[
        ClaudeMessage(role: 'user', content: '$contextLine\n\nЗадача: $userInput'),
      ],
    );

    final Result<ClaudeResponse> response = await _client.sendMessage(req);
    return response.when<Result<TaskModel>>(
      success: (ClaudeResponse r) => _parseTask(r.text),
      failure: (Failure f) => FailureResult<TaskModel>(f),
    );
  }

  Result<TaskModel> _parseTask(String text) {
    try {
      // Иногда модель оборачивает в ```json ... ```
      final String cleaned = text
          .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();

      final Map<String, dynamic> json = jsonDecode(cleaned) as Map<String, dynamic>;
      final DateTime? dueDate = json['dueDate'] == null
          ? null
          : DateTime.tryParse(json['dueDate'].toString());

      final List<dynamic> tagsRaw = (json['tags'] as List<dynamic>?) ?? <dynamic>[];

      final TaskModel task = TaskModel(
        id: const Uuid().v4(),
        title: (json['title'] as String?) ?? 'Без названия',
        description: json['description'] as String?,
        dueDate: dueDate,
        priority: TaskPriority.fromValue((json['priority'] as int?) ?? 1),
        status: TaskStatus.pending,
        tags: tagsRaw.map((dynamic e) => e.toString()).toList(),
        estimatedMinutes: json['estimatedMinutes'] as int?,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return Success<TaskModel>(task);
    } catch (e, st) {
      appLogger.e('Failed to parse task from AI', error: e, stackTrace: st);
      return FailureResult<TaskModel>(ParseFailure('Не удалось разобрать ответ AI: $e'));
    }
  }

  String _dayOfWeek(DateTime d) {
    const List<String> names = <String>[
      'понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье',
    ];
    return names[d.weekday - 1];
  }
}

final Provider<CreateTaskFromVoiceUseCase> createTaskFromVoiceUseCaseProvider =
    Provider<CreateTaskFromVoiceUseCase>((Ref ref) {
  return CreateTaskFromVoiceUseCase(ref.watch(claudeApiClientProvider));
});
