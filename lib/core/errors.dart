/// SignalNav - Application Errors & Exceptions
///
/// Production-ready error hierarchy with safe, user-friendly messages.
/// Never expose internal stack traces or sensitive data to the UI.

import 'package:flutter/foundation.dart';

/// Base application exception. All custom exceptions extend this.
@immutable
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final StackTrace? stackTrace;

  const AppException(this.message, {this.code, this.stackTrace});

  /// User-facing message that is safe to display. Override in subclasses
  /// for specific, actionable guidance.
  String get userMessage => message;

  @override
  String toString() => '[$runtimeType${code != null ? ':$code' : ''}] $message';
}

/// Network or connectivity failures.
class NetworkException extends AppException {
  final int? statusCode;

  const NetworkException(
    String message, {
    this.statusCode,
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'NETWORK_ERROR', stackTrace: stackTrace);

  @override
  String get userMessage =>
      statusCode != null
          ? 'Connection issue (code $statusCode). Please try again when you have a stable connection.'
          : 'Unable to connect. Cached data will be used if available.';
}

/// Location/GPS service failures.
class LocationException extends AppException {
  const LocationException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'LOCATION_ERROR', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'Location services are unavailable. Please enable GPS and try again.';
}

/// Permission denied by user or system.
class PermissionException extends AppException {
  const PermissionException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'PERMISSION_DENIED', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'Required permission was denied. Some features may be limited. '
      'You can enable permissions in Settings.';
}

/// Safety violation - user attempted an unsafe action (e.g., UI interaction while moving).
class SafetyViolationException extends AppException {
  const SafetyViolationException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'SAFETY_VIOLATION', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'For your safety, this action is disabled while moving. '
      'Please use voice commands or ask a passenger to help.';
}

/// Validation or business logic failure.
class ValidationException extends AppException {
  const ValidationException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'VALIDATION_ERROR', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'Something went wrong with that request. Please check your input and try again.';
}

/// Firebase / backend service failure.
class BackendException extends AppException {
  const BackendException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'BACKEND_ERROR', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'We\'re having trouble syncing data. Your report is saved locally and will retry automatically.';
}

/// Unexpected / catch-all exception wrapper.
class UnexpectedException extends AppException {
  const UnexpectedException(
    String message, {
    String? code,
    StackTrace? stackTrace,
  }) : super(message, code: code ?? 'UNEXPECTED', stackTrace: stackTrace);

  @override
  String get userMessage =>
      'An unexpected issue occurred. Please restart the app if this continues.';
}

/// Result type for safe error handling without throwing.
/// Inspired by Rust's Result<T, E> and Kotlin's Result.
@immutable
sealed class Result<T> {
  const Result();
}

@immutable
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);
}

@immutable
class Failure<T> extends Result<T> {
  final AppException error;
  const Failure(this.error);
}

/// Helper extension to convert Futures to Results safely.
extension FutureResult<T> on Future<T> {
  Future<Result<T>> toResult() async {
    try {
      final value = await this;
      return Success<T>(value);
    } on AppException catch (e) {
      return Failure<T>(e);
    } catch (e, st) {
      return Failure<T>(
        UnexpectedException(e.toString(), stackTrace: st),
      );
    }
  }
}
