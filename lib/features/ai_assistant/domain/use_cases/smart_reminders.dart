import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/task_model.dart';
import '../../data/claude_api_client.dart';

enum ReminderUrgency { low, medium, high }

class SmartReminder {
  SmartReminder({
    required this.taskId,
    required this.message,
    required this.urgency,
  });

  final String taskId;
  final String message;
  final ReminderUrgency urgency;
}

/// Use-case C: умные напоминания и приоритизация — фоновая задача.
class SmartRemindersUseCase {
  SmartRemindersUseCase(this._client);
  final ClaudeApiClient _client;

  static const String _systemPrompt = '''
Ты ассистент по тайм-менеджменту. Анализируй список задач пользователя и определи, какие требуют напоминания ПРЯМО СЕЙЧАС.
Учитывай: приближающиеся дедлайны, приоритет, не выполненные задачи на сегодня.
Не отправляй напоминания о завершённых задачах. Не дублируй напоминания о далёких задачах.

Верни СТРОГО валидный JSON-массив (может быть пустым). Без markdown.
[
  {"taskId": "uuid", "message": "короткое мотивирующее сообщение по-русски", "urgency": "low"|"medium"|"high"}
]
''';

  Future<Result<List<SmartReminder>>> call(List<TaskModel> tasks) async {
    if (tasks.isEmpty) {
      return const Success<List<SmartReminder>>(<SmartReminder>[]);
    }

    final DateTime now = DateTime.now();
    final String tasksJson = jsonEncode(tasks
        .where((TaskModel t) => !t.isCompleted)
        .map((TaskModel t) => <String, Object?>{
              'id': t.id,
              'title': t.title,
              'priority': t.priority.value,
              'dueDate': t.dueDate?.toIso8601String(),
              'status': t.status.value,
            })
        .toList());

    final String prompt = '''
Сейчас: ${now.toIso8601String()}

Активные задачи:
$tasksJson

Какие требуют напоминания прямо сейчас? Только JSON.
''';

    final ClaudeRequest req = ClaudeRequest(
      model: AppConstants.fastModel,
      maxTokens: 1024,
      temperature: 0.5,
      system: _systemPrompt,
      messages: <ClaudeMessage>[ClaudeMessage(role: 'user', content: prompt)],
    );

    final Result<ClaudeResponse> response = await _client.sendMessage(req);
    return response.when<Result<List<SmartReminder>>>(
      success: (ClaudeResponse r) => _parse(r.text),
      failure: (Failure f) => FailureResult<List<SmartReminder>>(f),
    );
  }

  Result<List<SmartReminder>> _parse(String text) {
    try {
      final String cleaned = text
          .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();
      final List<dynamic> raw = jsonDecode(cleaned) as List<dynamic>;
      final List<SmartReminder> reminders = raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> j) => SmartReminder(
                taskId: j['taskId'] as String,
                message: j['message'] as String,
                urgency: switch (j['urgency']?.toString()) {
                  'high' => ReminderUrgency.high,
                  'low' => ReminderUrgency.low,
                  _ => ReminderUrgency.medium,
                },
              ))
          .toList();
      return Success<List<SmartReminder>>(reminders);
    } catch (e, st) {
      appLogger.e('Failed to parse reminders', error: e, stackTrace: st);
      return FailureResult<List<SmartReminder>>(ParseFailure('Ошибка парсинга напоминаний: $e'));
    }
  }
}

final Provider<SmartRemindersUseCase> smartRemindersUseCaseProvider =
    Provider<SmartRemindersUseCase>((Ref ref) {
  return SmartRemindersUseCase(ref.watch(claudeApiClientProvider));
});
