import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../core/logging/app_logger.dart';

/// Application configuration provider.
final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig.fromEnvironment();
});

/// Structured application logger provider.
final appLoggerProvider = Provider<AppLogger>((ref) {
  final config = ref.watch(appConfigProvider);
  return AppLogger(
    minLevel: config.enableVerboseLogging ? LogLevel.debug : LogLevel.info,
  );
});

/// Centralised error handler provider.
final errorHandlerProvider = Provider<ErrorHandler>((ref) {
  final logger = ref.watch(appLoggerProvider);
  return ErrorHandler(logger);
});

