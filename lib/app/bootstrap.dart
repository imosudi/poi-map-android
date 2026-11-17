import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/errors/error_handler.dart';
import '../core/logging/app_logger.dart';
import 'app.dart';

/// Observes Riverpod provider failures and forwards them to [ErrorHandler].
final class AppProviderObserver extends ProviderObserver {
  AppProviderObserver(this._errorHandler);

  final ErrorHandler _errorHandler;

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    _errorHandler.handle(
      error,
      stackTrace: stackTrace,
      tag: 'Riverpod',
      context: {
        'provider':
            context.provider.name ?? context.provider.runtimeType.toString(),
      },
    );
  }
}

/// Initialises core services, global error hooks, and launches the app.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  final logger = AppLogger(
    minLevel: config.enableVerboseLogging ? LogLevel.debug : LogLevel.info,
  );
  final errorHandler = ErrorHandler(logger);

  FlutterError.onError = (details) {
    errorHandler.handle(
      details.exception,
      stackTrace: details.stack,
      tag: 'FlutterError',
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    errorHandler.handle(error, stackTrace: stackTrace, tag: 'PlatformError');
    return true;
  };

  logger.info(
    'Bootstrap',
    'Starting ${config.appName}',
    context: {'environment': config.environment.name},
  );

  runApp(
    ProviderScope(
      observers: [AppProviderObserver(errorHandler)],
      child: const ViennaPoiExplorerApp(),
    ),
  );
}
