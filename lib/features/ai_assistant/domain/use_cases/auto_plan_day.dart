import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../../../data/models/task_model.dart';
import '../../data/claude_api_client.dart';

/// Один блок в предложенном расписании.
class PlanBlock {
  PlanBlock({
    required this.taskId,
    required this.startTime,
    required this.endTime,
    required this.reasoning,
  });

  final String taskId;
  final DateTime startTime;
  final DateTime endTime;
  final String reasoning;
}

/// Use-case B: автопланирование дня с учётом приоритетов и оценок.
class AutoPlanDayUseCase {
  AutoPlanDayUseCase(this._client);
  final ClaudeApiClient _client;

  static const String _systemPrompt = '''
Ты эксперт по тайм-менеджменту. Получаешь список задач на день и рабочие часы.
Составь оптимальное расписание дня. Правила:
- Высокий приоритет — в первой половине дня
- Между задачами 15-минутные перерывы
- Обеденный перерыв 13:00-14:00 (если рабочий день включает это время)
- Учитывай estimatedMinutes
- Не ставь две задачи на одно время
- Все startTime/endTime — в формате ISO8601 в локальной таймзоне пользователя

Возвращай СТРОГО валидный JSON-массив без markdown:
[
  {"taskId": "uuid", "startTime": "ISO8601", "endTime": "ISO8601", "reasoning": "почему именно в это время"}
]
''';

  Future<Result<List<PlanBlock>>> call({
    required List<TaskModel> tasks,
    required int workStartHour,
    required int workEndHour,
  }) async {
    if (tasks.isEmpty) {
      return const Success<List<PlanBlock>>(<PlanBlock>[]);
    }

    final DateTime now = DateTime.now();
    final String tasksJson = jsonEncode(tasks.map((TaskModel t) => <String, Object?>{
          'id': t.id,
          'title': t.title,
          'priority': t.priority.value,
          'estimatedMinutes': t.estimatedMinutes ?? 30,
          'dueDate': t.dueDate?.toIso8601String(),
        }).toList());

    final String prompt = '''
Сегодня: ${now.toIso8601String()}
Рабочие часы: $workStartHour:00 — $workEndHour:00

Задачи:
$tasksJson

Составь расписание. Только JSON-массив.
''';

    final ClaudeRequest req = ClaudeRequest(
      model: AppConstants.defaultModel,
      maxTokens: 2048,
      temperature: 0.4,
      system: _systemPrompt,
      messages: <ClaudeMessage>[ClaudeMessage(role: 'user', content: prompt)],
    );

    final Result<ClaudeResponse> response = await _client.sendMessage(req);
    return response.when<Result<List<PlanBlock>>>(
      success: (ClaudeResponse r) => _parsePlan(r.text),
      failure: (Failure f) => FailureResult<List<PlanBlock>>(f),
    );
  }

  Result<List<PlanBlock>> _parsePlan(String text) {
    try {
      final String cleaned = text
          .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();

      final List<dynamic> raw = jsonDecode(cleaned) as List<dynamic>;
      final List<PlanBlock> blocks = raw
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> j) => PlanBlock(
                taskId: j['taskId'] as String,
                startTime: DateTime.parse(j['startTime'] as String),
                endTime: DateTime.parse(j['endTime'] as String),
                reasoning: (j['reasoning'] as String?) ?? '',
              ))
          .toList();
      return Success<List<PlanBlock>>(blocks);
    } catch (e, st) {
      appLogger.e('Failed to parse plan', error: e, stackTrace: st);
      return FailureResult<List<PlanBlock>>(ParseFailure('Не удалось разобрать план: $e'));
    }
  }
}

final Provider<AutoPlanDayUseCase> autoPlanDayUseCaseProvider = Provider<AutoPlanDayUseCase>((Ref ref) {
  return AutoPlanDayUseCase(ref.watch(claudeApiClientProvider));
});
