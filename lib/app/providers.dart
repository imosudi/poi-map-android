import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../core/logging/app_logger.dart';
import '../core/network/dio_factory.dart';

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

/// Configured [Dio] HTTP client provider with lifecycle cleanup.
final dioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.create(
    config: ref.watch(appConfigProvider),
    logger: ref.watch(appLoggerProvider),
  );
  ref.onDispose(dio.close);
  return dio;
});
