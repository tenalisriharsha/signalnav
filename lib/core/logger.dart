/// SignalNav - Privacy-Respecting Event Logger
///
/// All logging goes through this channel. We NEVER log:
/// - Raw GPS coordinates (rounded to ~100m before logging if at all)
/// - User identifiers (Firebase UIDs are hashed)
/// - Personal identifiable information (PII)
///
/// Logging is primarily for debugging and safety audits. In production,
/// sensitive logs are stripped via tree-shaking or build flags.

import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Log levels aligned with production needs.
enum LogLevel { verbose, debug, info, warning, error, fatal }

/// Categories for filtering and routing logs.
enum LogCategory {
  safety,
  navigation,
  signal,
  audio,
  network,
  location,
  privacy,
  lifecycle,
}

/// A privacy-respecting log entry.
@immutable
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final LogCategory category;
  final String message;
  final Map<String, dynamic>? safeContext;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.category,
    required this.message,
    this.safeContext,
  });

  Map<String, dynamic> toJson() => {
    'ts': timestamp.toIso8601String(),
    'lvl': level.name,
    'cat': category.name,
    'msg': message,
    if (safeContext != null) 'ctx': safeContext,
  };
}

/// Central logger interface.
abstract class AppLogger {
  void log(LogLevel level, LogCategory category, String message,
      {Map<String, dynamic>? safeContext});
}

/// Development logger that outputs to dart:developer console.
/// In production, this should be replaced with a no-op or crashlytics-only logger.
class DevelopmentLogger implements AppLogger {
  static const _maxContextLength = 500;

  @override
  void log(LogLevel level, LogCategory category, String message,
      {Map<String, dynamic>? safeContext}) {
    // In release builds, only log warnings and above
    if (kReleaseMode &&
        level.index < LogLevel.warning.index) {
      return;
    }

    final entry = LogEntry(
      timestamp: DateTime.now().toUtc(),
      level: level,
      category: category,
      message: message,
      safeContext: _sanitizeContext(safeContext),
    );

    final output = '[${entry.category.name.toUpperCase()}] ${entry.message}';

    switch (level) {
      case LogLevel.fatal:
      case LogLevel.error:
        developer.log(
          output,
          name: 'SIGNALNAV_ERROR',
          error: entry.toJson(),
        );
        break;
      case LogLevel.warning:
        developer.log(
          output,
          name: 'SIGNALNAV_WARN',
          error: entry.toJson(),
        );
        break;
      default:
        developer.log(
          output,
          name: 'SIGNALNAV',
        );
    }
  }

  /// Remove any potentially sensitive fields from context.
  Map<String, dynamic>? _sanitizeContext(Map<String, dynamic>? ctx) {
    if (ctx == null) return null;
    final sanitized = <String, dynamic>{};
    for (final entry in ctx.entries) {
      final key = entry.key.toLowerCase();
      // Never log these keys
      if (key.contains('uid') ||
          key.contains('token') ||
          key.contains('password') ||
          key.contains('email') ||
          key.contains('phone') ||
          key.contains('lat') ||
          key.contains('lng') ||
          key.contains('location')) {
        sanitized[entry.key] = '[REDACTED]';
      } else {
        final value = entry.value.toString();
        sanitized[entry.key] =
            value.length > _maxContextLength
                ? '${value.substring(0, _maxContextLength)}...'
                : value;
      }
    }
    return sanitized;
  }
}

/// Production logger that only reports errors and safety events.
/// No debug logs are emitted to minimize overhead and data exposure.
class ProductionLogger implements AppLogger {
  @override
  void log(LogLevel level, LogCategory category, String message,
      {Map<String, dynamic>? safeContext}) {
    // Only log warnings, errors, and safety events in production
    if (level.index < LogLevel.warning.index && category != LogCategory.safety) {
      return;
    }

    // TODO: Integrate with Firebase Crashlytics for error/fatal logs
    // TODO: Integrate with privacy-compliant analytics for aggregated safety metrics
    developer.log(
      '[${category.name}] $message',
      name: 'SIGNALNAV_PROD',
    );
  }
}

/// Global logger instance. Switch based on build mode.
final AppLogger appLogger =
    kDebugMode ? DevelopmentLogger() : ProductionLogger();

/// Convenience methods.
void logDebug(LogCategory cat, String msg, {Map<String, dynamic>? ctx}) =>
    appLogger.log(LogLevel.debug, cat, msg, safeContext: ctx);

void logInfo(LogCategory cat, String msg, {Map<String, dynamic>? ctx}) =>
    appLogger.log(LogLevel.info, cat, msg, safeContext: ctx);

void logWarning(LogCategory cat, String msg, {Map<String, dynamic>? ctx}) =>
    appLogger.log(LogLevel.warning, cat, msg, safeContext: ctx);

void logError(LogCategory cat, String msg, {Map<String, dynamic>? ctx}) =>
    appLogger.log(LogLevel.error, cat, msg, safeContext: ctx);

void logSafety(String msg, {Map<String, dynamic>? ctx}) =>
    appLogger.log(LogLevel.warning, LogCategory.safety, msg, safeContext: ctx);
