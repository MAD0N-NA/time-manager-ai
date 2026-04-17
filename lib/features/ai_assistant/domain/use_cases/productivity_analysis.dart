import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../data/claude_api_client.dart';

class WeeklyStats {
  WeeklyStats({
    required this.tasksCompleted,
    required this.tasksCreated,
    required this.pomodoroCount,
    required this.focusMinutes,
    required this.streakDays,
    required this.completionRate,
    required this.dailyBreakdown,
  });

  final int tasksCompleted;
  final int tasksCreated;
  final int pomodoroCount;
  final int focusMinutes;
  final int streakDays;
  final double completionRate;
  final Map<String, int> dailyBreakdown; // date -> tasks completed
}

class ProductivityReport {
  ProductivityReport({required this.summary, required this.insights, required this.advice});
  final String summary;
  final List<String> insights;
  final List<String> advice;
}

/// Use-case D: еженедельный анализ продуктивности.
class ProductivityAnalysisUseCase {
  ProductivityAnalysisUseCase(this._client);
  final ClaudeApiClient _client;

  static const String _systemPrompt = '''
Ты опытный коуч по продуктивности. Получаешь статистику недели пользователя.
Дай дружелюбный, мотивирующий, но честный отчёт по-русски.

Верни СТРОГО валидный JSON без markdown:
{
  "summary": "2-3 предложения общего вывода о неделе",
  "insights": ["конкретный вывод 1", "вывод 2", "вывод 3"],
  "advice": ["совет на следующую неделю 1", "совет 2", "совет 3"]
}
''';

  Future<Result<ProductivityReport>> call(WeeklyStats stats) async {
    final String json = jsonEncode(<String, Object?>{
      'tasksCompleted': stats.tasksCompleted,
      'tasksCreated': stats.tasksCreated,
      'pomodoroCount': stats.pomodoroCount,
      'focusMinutes': stats.focusMinutes,
      'streakDays': stats.streakDays,
      'completionRate': stats.completionRate,
      'dailyBreakdown': stats.dailyBreakdown,
    });

    final ClaudeRequest req = ClaudeRequest(
      model: AppConstants.defaultModel,
      maxTokens: 1500,
      temperature: 0.7,
      system: _systemPrompt,
      messages: <ClaudeMessage>[
        ClaudeMessage(role: 'user', content: 'Статистика за неделю:\n$json'),
      ],
    );

    final Result<ClaudeResponse> response = await _client.sendMessage(req);
    return response.when<Result<ProductivityReport>>(
      success: (ClaudeResponse r) => _parse(r.text),
      failure: (Failure f) => FailureResult<ProductivityReport>(f),
    );
  }

  Result<ProductivityReport> _parse(String text) {
    try {
      final String cleaned = text
          .replaceAll(RegExp(r'^```(?:json)?', multiLine: true), '')
          .replaceAll(RegExp(r'```$', multiLine: true), '')
          .trim();
      final Map<String, dynamic> j = jsonDecode(cleaned) as Map<String, dynamic>;
      return Success<ProductivityReport>(
        ProductivityReport(
          summary: (j['summary'] as String?) ?? '',
          insights: ((j['insights'] as List<dynamic>?) ?? <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(),
          advice: ((j['advice'] as List<dynamic>?) ?? <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(),
        ),
      );
    } catch (e) {
      // Fallback: возвращаем как обычный текст
      return Success<ProductivityReport>(
        ProductivityReport(summary: text, insights: const <String>[], advice: const <String>[]),
      );
    }
  }
}

final Provider<ProductivityAnalysisUseCase> productivityAnalysisUseCaseProvider =
    Provider<ProductivityAnalysisUseCase>((Ref ref) {
  return ProductivityAnalysisUseCase(ref.watch(claudeApiClientProvider));
});
