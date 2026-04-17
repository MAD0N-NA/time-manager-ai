import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/logger.dart';

/// Сообщение для Claude API.
class ClaudeMessage {
  ClaudeMessage({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
      };
}

/// Параметры запроса к Claude.
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

  Map<String, Object?> toJson() => <String, Object?>{
        'model': model,
        'max_tokens': maxTokens,
        'temperature': temperature,
        if (system != null) 'system': system,
        'messages': messages.map((ClaudeMessage m) => m.toJson()).toList(),
      };
}

/// Ответ Claude.
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

/// HTTP-клиент для Claude API.
class ClaudeApiClient {
  ClaudeApiClient({
    required FlutterSecureStorage storage,
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 90),
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

    const int maxRetries = 3;
    Duration delay = const Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final Response<dynamic> response = await _dio.post<dynamic>(
          AppConstants.claudeBaseUrl,
          data: request.toJson(),
          options: Options(
            headers: <String, String>{
              'x-api-key': apiKey,
              'anthropic-version': AppConstants.claudeApiVersion,
              'content-type': 'application/json',
            },
            responseType: ResponseType.json,
          ),
        );

        final Map<String, dynamic> data = response.data as Map<String, dynamic>;
        final List<dynamic> content = (data['content'] as List<dynamic>? ?? <dynamic>[]);
        final String text = content
            .whereType<Map<String, dynamic>>()
            .where((Map<String, dynamic> b) => b['type'] == 'text')
            .map((Map<String, dynamic> b) => b['text']?.toString() ?? '')
            .join('\n')
            .trim();

        final Map<String, dynamic> usage = (data['usage'] as Map<String, dynamic>? ?? <String, dynamic>{});
        return Success<ClaudeResponse>(
          ClaudeResponse(
            id: data['id']?.toString() ?? '',
            text: text,
            stopReason: data['stop_reason']?.toString(),
            inputTokens: (usage['input_tokens'] as int?) ?? 0,
            outputTokens: (usage['output_tokens'] as int?) ?? 0,
            model: data['model']?.toString() ?? request.model,
          ),
        );
      } on DioException catch (e) {
        appLogger.w('Claude API error (attempt ${attempt + 1}): ${e.message}');
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

        // Retry на 429/5xx и таймауты
        if (attempt == maxRetries - 1) {
          return FailureResult<ClaudeResponse>(
            NetworkFailure('Не удалось связаться с Claude: ${e.message}', e),
          );
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      } catch (e, st) {
        appLogger.e('Unexpected Claude API error', error: e, stackTrace: st);
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
