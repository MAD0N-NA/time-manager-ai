import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/logger.dart';

/// Сообщение для AI.
/// Имена классов оставлены как ClaudeXxx, чтобы не переписывать use-cases.
/// Внутри — запросы идут в OpenRouter (OpenAI-совместимый API).
class ClaudeMessage {
  ClaudeMessage({required this.role, required this.content});
  final String role; // 'user' | 'assistant' | 'system'
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
      };
}

class ClaudeRequest {
  ClaudeRequest({
    required this.messages,
    this.model = AppConstants.defaultModel,
    this.maxTokens = 1024,
    this.temperature = 0.7,
    this.system,
  });

  final List<ClaudeMessage> messages;
  final String model;
  final int maxTokens;
  final double temperature;
  final String? system;

  /// Формат OpenAI / OpenRouter.
  Map<String, Object?> toOpenAiJson() {
    final List<Map<String, Object?>> allMessages = <Map<String, Object?>>[];
    if (system != null && system!.isNotEmpty) {
      allMessages.add(<String, Object?>{
        'role': 'system',
        'content': system,
      });
    }
    allMessages.addAll(messages.map((ClaudeMessage m) => m.toJson()));

    return <String, Object?>{
      'model': model,
      'messages': allMessages,
      'max_tokens': maxTokens,
      'temperature': temperature,
    };
  }
}

class ClaudeResponse {
  ClaudeResponse({
    required this.id,
    required this.text,
    required this.stopReason,
    required this.inputTokens,
    required this.outputTokens,
    required this.model,
  });

  final String id;
  final String text;
  final String? stopReason;
  final int inputTokens;
  final int outputTokens;
  final String model;
}

/// HTTP-клиент для OpenRouter (имя ClaudeApiClient сохранено).
class ClaudeApiClient {
  ClaudeApiClient({
    required FlutterSecureStorage storage,
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 120),
                sendTimeout: const Duration(seconds: 30),
              ),
            );

  final FlutterSecureStorage _storage;
  final Dio _dio;

  Future<String?> _readApiKey() => _storage.read(key: AppConstants.secureStorageApiKey);

  Future<bool> hasApiKey() async => (await _readApiKey())?.isNotEmpty ?? false;

  Future<void> saveApiKey(String key) =>
      _storage.write(key: AppConstants.secureStorageApiKey, value: key);

  Future<void> clearApiKey() => _storage.delete(key: AppConstants.secureStorageApiKey);

  /// Отправка запроса с retry и exponential backoff.
  Future<Result<ClaudeResponse>> sendMessage(ClaudeRequest request) async {
    final String? apiKey = await _readApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      return const FailureResult<ClaudeResponse>(
        AuthFailure('API-ключ не указан. Введите его в настройках.'),
      );
    }

    const int maxRetries = 2;
    Duration delay = const Duration(seconds: 2);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final Response<dynamic> response = await _dio.post<dynamic>(
          AppConstants.openRouterBaseUrl,
          data: request.toOpenAiJson(),
          options: Options(
            headers: <String, String>{
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              // Рекомендованные OpenRouter заголовки (для atrribution на их сайте).
              'HTTP-Referer': 'https://github.com/MAD0N-NA/time-manager-ai',
              'X-Title': 'TimeManager AI',
            },
            responseType: ResponseType.json,
          ),
        );

        final Map<String, dynamic> data = response.data as Map<String, dynamic>;

        // Извлекаем текст: choices[0].message.content
        final List<dynamic> choices = (data['choices'] as List<dynamic>? ?? <dynamic>[]);
        String text = '';
        String? finishReason;
        if (choices.isNotEmpty) {
          final Map<String, dynamic> first = choices.first as Map<String, dynamic>;
          finishReason = first['finish_reason']?.toString();
          final Map<String, dynamic>? message = first['message'] as Map<String, dynamic>?;
          text = message?['content']?.toString().trim() ?? '';
        }

        final Map<String, dynamic> usage =
            (data['usage'] as Map<String, dynamic>? ?? <String, dynamic>{});

        return Success<ClaudeResponse>(
          ClaudeResponse(
            id: data['id']?.toString() ?? '',
            text: text,
            stopReason: finishReason,
            inputTokens: (usage['prompt_tokens'] as int?) ?? 0,
            outputTokens: (usage['completion_tokens'] as int?) ?? 0,
            model: data['model']?.toString() ?? request.model,
          ),
        );
      } on DioException catch (e) {
        appLogger.w('OpenRouter API error (attempt ${attempt + 1}): ${e.message}');
        final int? code = e.response?.statusCode;

        if (code == 401 || code == 403) {
          return FailureResult<ClaudeResponse>(
            AuthFailure('Неверный API-ключ или нет доступа.', e),
          );
        }

        if (code == 400) {
          final String body = jsonEncode(e.response?.data ?? <String, dynamic>{});
          return FailureResult<ClaudeResponse>(ApiFailure('Некорректный запрос: $body', code, e));
        }

        if (code == 404) {
          return FailureResult<ClaudeResponse>(
            ApiFailure('Модель не найдена на OpenRouter. Проверьте slug в настройках.', code, e),
          );
        }

        if (code == 429) {
          return FailureResult<ClaudeResponse>(
            ApiFailure(
              'Превышен дневной лимит бесплатных запросов OpenRouter (50/день). '
              'Попробуйте завтра или пополните баланс на openrouter.ai/credits.',
              code,
              e,
            ),
          );
        }

        // Retry только на 5xx и таймауты
        if (attempt == maxRetries - 1) {
          return FailureResult<ClaudeResponse>(
            NetworkFailure('Не удалось связаться с OpenRouter: ${e.message}', e),
          );
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      } catch (e, st) {
        appLogger.e('Unexpected OpenRouter API error', error: e, stackTrace: st);
        return FailureResult<ClaudeResponse>(UnknownFailure(e.toString(), e));
      }
    }
    return const FailureResult<ClaudeResponse>(NetworkFailure('Превышено число попыток'));
  }
}

final Provider<FlutterSecureStorage> secureStorageProvider = Provider<FlutterSecureStorage>((Ref ref) {
  return const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
});

final Provider<ClaudeApiClient> claudeApiClientProvider = Provider<ClaudeApiClient>((Ref ref) {
  return ClaudeApiClient(storage: ref.watch(secureStorageProvider));
});
