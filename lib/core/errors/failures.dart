import 'package:flutter/foundation.dart';

/// Базовый класс для бизнес-ошибок приложения.
@immutable
sealed class Failure {
  const Failure(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => '$runtimeType($message)';
}

class NetworkFailure extends Failure {
  const NetworkFailure(super.message, [super.cause]);
}

class ApiFailure extends Failure {
  const ApiFailure(super.message, [this.statusCode, super.cause]);
  final int? statusCode;
}

class AuthFailure extends Failure {
  const AuthFailure(super.message, [super.cause]);
}

class StorageFailure extends Failure {
  const StorageFailure(super.message, [super.cause]);
}

class ParseFailure extends Failure {
  const ParseFailure(super.message, [super.cause]);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, [super.cause]);
}

class UnknownFailure extends Failure {
  const UnknownFailure(super.message, [super.cause]);
}

/// Простая реализация Result<T> вместо Either.
@immutable
sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is FailureResult<T>;

  T? get valueOrNull => switch (this) {
        Success<T>(value: final v) => v,
        FailureResult<T>() => null,
      };

  Failure? get failureOrNull => switch (this) {
        Success<T>() => null,
        FailureResult<T>(failure: final f) => f,
      };

  R when<R>({
    required R Function(T value) success,
    required R Function(Failure failure) failure,
  }) =>
      switch (this) {
        Success<T>(value: final v) => success(v),
        FailureResult<T>(failure: final f) => failure(f),
      };
}

class Success<T> extends Result<T> {
  const Success(this.value);
  final T value;
}

class FailureResult<T> extends Result<T> {
  const FailureResult(this.failure);
  final Failure failure;
}
