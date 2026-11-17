import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';

import '../logging/app_logger.dart';
import 'app_exception.dart';

/// Centralised error mapper and reporter for application layers.
final class ErrorHandler {
  const ErrorHandler(this._logger);

  final AppLogger _logger;

  /// Converts an arbitrary [error] into a user-safe [AppException].
  AppException map(Object error) {
    if (error is AppException) {
      return error;
    }

    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.connectionError => NetworkException(
          'Unable to reach the server. Please check your connection.',
          cause: error,
        ),
        DioExceptionType.badResponse => NetworkException(
          'The server returned an unexpected response (${error.response?.statusCode ?? 'unknown'}).',
          cause: error,
        ),
        _ => NetworkException(
          'A network error occurred. Please try again.',
          cause: error,
        ),
      };
    }

    if (error is SocketException || error is TimeoutException) {
      return NetworkException(
        'Connection timed out. Please check your internet access.',
        cause: error,
      );
    }

    if (error is FormatException) {
      return PoiDataException(
        'Received malformed data from the service.',
        cause: error,
      );
    }

    return UnexpectedException(
      'Something went wrong. Please try again.',
      error,
    );
  }

  /// Logs [error] safely and returns the mapped [AppException].
  AppException handle(
    Object error, {
    StackTrace? stackTrace,
    String tag = 'ErrorHandler',
    Map<String, Object?> context = const {},
  }) {
    final mapped = map(error);
    _logger.error(
      tag,
      mapped.message,
      context: context,
      error: mapped.cause ?? mapped,
      stackTrace: stackTrace,
    );
    return mapped;
  }
}

