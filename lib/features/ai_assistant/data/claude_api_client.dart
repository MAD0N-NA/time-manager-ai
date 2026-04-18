import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../core/utils/logger.dart';

/// Сообщение для AI.
/// Имена классов оставлены как ClaudeXxx, чтобы не переписывать use-cases,
/// но внутри клиент ходит в Gemini API.
class ClaudeMessage {
  ClaudeMessage({required this.role, required this.content});
  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, Object?> toJson() => <String, Object?>{
        'role': role,
        'content': content,
      };
}

/// Параметры запроса к AI.
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

  /// Преобразование в формат Gemini API.
  Map<String, Object?> toGeminiJson() {
    final List<Map<String, Object?>> contents = messages
        .map((ClaudeMessage m) => <String, Object?>{
              // Gemini использует 'user' и 'model' (не 'assistant').
              'role': m.role == 'assistant' ? 'model' : 'user',
              'parts': <Map<String, Object?>>[
                <String, Object?>{'text': m.content},
              ],
            })
        .toList();

    final Map<String, Object?> body = <String, Object?>{
      'contents': contents,
      'generationConfig': <String, Object?>{
        'temperature': temperature,
        'maxOutputTokens': maxTokens,
      },
    };

    if (system != null && system!.isNotEmpty) {
      body['systemInstruction'] = <String, Object?>{
        'parts': <Map<String, Object?>>[
          <String, Object?>{'text': system},
        ],
      };
    }

    return body;
  }
}

/// Ответ AI.
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

/// HTTP-клиент для Gemini API (имя сохранено ради обратной совместимости).
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

    // Gemini кладёт ключ в query-параметр.
    final String url =
        '${AppConstants.geminiBaseUrl}/${request.model}:generateContent?key=$apiKey';

    const int maxRetries = 3;
    Duration delay = const Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final Response<dynamic> response = await _dio.post<dynamic>(
          url,
          data: request.toGeminiJson(),
          options: Options(
            headers: <String, String>{
              'content-type': 'application/json',
            },
            responseType: ResponseType.json,
          ),
        );

        final Map<String, dynamic> data = response.data as Map<String, dynamic>;

        // Извлекаем текст: candidates[0].content.parts[*].text
        final List<dynamic> candidates = (data['candidates'] as List<dynamic>? ?? <dynamic>[]);
        String text = '';
        String? finishReason;
        if (candidates.isNotEmpty) {
          final Map<String, dynamic> first = candidates.first as Map<String, dynamic>;
          finishReason = first['finishReason']?.toString();
          final Map<String, dynamic>? content = first['content'] as Map<String, dynamic>?;
          if (content != null) {
            final List<dynamic> parts = (content['parts'] as List<dynamic>? ?? <dynamic>[]);
            text = parts
                .whereType<Map<String, dynamic>>()
                .map((Map<String, dynamic> p) => p['text']?.toString() ?? '')
                .join('\n')
                .trim();
          }
        }

        final Map<String, dynamic> usage =
            (data['usageMetadata'] as Map<String, dynamic>? ?? <String, dynamic>{});

        return Success<ClaudeResponse>(
          ClaudeResponse(
            id: data['responseId']?.toString() ?? '',
            text: text,
            stopReason: finishReason,
            inputTokens: (usage['promptTokenCount'] as int?) ?? 0,
            outputTokens: (usage['candidatesTokenCount'] as int?) ?? 0,
            model: data['modelVersion']?.toString() ?? request.model,
          ),
        );
      } on DioException catch (e) {
        appLogger.w('Gemini API error (attempt ${attempt + 1}): ${e.message}');
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
            NetworkFailure('Не удалось связаться с Gemini: ${e.message}', e),
          );
        }
        await Future<void>.delayed(delay);
        delay *= 2;
      } catch (e, st) {
        appLogger.e('Unexpected Gemini API error', error: e, stackTrace: st);
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
