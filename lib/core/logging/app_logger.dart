import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Severity levels for structured application logs.
enum LogLevel { debug, info, warning, error }

/// Structured logger that redacts sensitive fields before emitting output.
final class AppLogger {
  const AppLogger({this.minLevel = LogLevel.debug});

  final LogLevel minLevel;

  static const Set<String> _sensitiveKeys = {
    'authorization',
    'api_key',
    'apikey',
    'key',
    'password',
    'secret',
    'token',
    'access_token',
    'refresh_token',
    'cookie',
  };

  static final RegExp _bearerPattern = RegExp(
    r'Bearer\s+[A-Za-z0-9\-._~+/]+=*',
    caseSensitive: false,
  );

  static final RegExp _querySecretPattern = RegExp(
    r'([?&](?:api_key|apikey|key|token|access_token|secret)=)([^&\s]+)',
    caseSensitive: false,
  );

  void debug(
    String tag,
    String message, {
    Map<String, Object?> context = const {},
  }) {
    _log(LogLevel.debug, tag, message, context: context);
  }

  void info(
    String tag,
    String message, {
    Map<String, Object?> context = const {},
  }) {
    _log(LogLevel.info, tag, message, context: context);
  }

  void warning(
    String tag,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.warning,
      tag,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void error(
    String tag,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(
      LogLevel.error,
      tag,
      message,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    LogLevel level,
    String tag,
    String message, {
    Map<String, Object?> context = const {},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) {
      return;
    }

    final safeMessage = redactText(message);
    final safeContext = sanitizeContext(context);
    final contextSuffix = safeContext.isEmpty ? '' : ' | $safeContext';
    final formatted =
        '[${level.name.toUpperCase()}][$tag] $safeMessage$contextSuffix';

    if (kDebugMode) {
      developer.log(
        formatted,
        name: 'ViennaPoiExplorer',
        level: _developerLevel(level),
        error: error == null ? null : redactText(error.toString()),
        stackTrace: stackTrace,
      );
    }
  }

  /// Replaces sensitive tokens or query parameters in [input] with `[REDACTED]`.
  static String redactText(String input) {
    return input
        .replaceAll(_bearerPattern, 'Bearer [REDACTED]')
        .replaceAllMapped(
          _querySecretPattern,
          (match) => '${match.group(1)}[REDACTED]',
        );
  }

  /// Returns a copy of [context] with sensitive keys and values redacted.
  static Map<String, Object?> sanitizeContext(Map<String, Object?> context) {
    if (context.isEmpty) {
      return const {};
    }

    final sanitized = <String, Object?>{};
    for (final entry in context.entries) {
      final normalizedKey = entry.key.trim().toLowerCase();
      if (_sensitiveKeys.contains(normalizedKey)) {
        sanitized[entry.key] = '[REDACTED]';
      } else if (entry.value is String) {
        sanitized[entry.key] = redactText(entry.value! as String);
      } else if (entry.value is Map<String, Object?>) {
        sanitized[entry.key] = sanitizeContext(
          entry.value! as Map<String, Object?>,
        );
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return Map.unmodifiable(sanitized);
  }

  int _developerLevel(LogLevel level) => switch (level) {
    LogLevel.debug => 500,
    LogLevel.info => 800,
    LogLevel.warning => 900,
    LogLevel.error => 1000,
  };
}
