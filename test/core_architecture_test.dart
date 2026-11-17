import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/providers.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/errors/error_handler.dart';
import 'package:poi_map_android/core/logging/app_logger.dart';
import 'package:poi_map_android/core/widgets/app_empty_view.dart';
import 'package:poi_map_android/core/widgets/app_error_view.dart';
import 'package:poi_map_android/core/widgets/app_loading_view.dart';
import 'package:poi_map_android/core/widgets/async_value_view.dart';

void main() {
  test('Core Riverpod providers initialise cleanly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final config = container.read(appConfigProvider);
    final logger = container.read(appLoggerProvider);
    final handler = container.read(errorHandlerProvider);

    expect(config.appName, 'Vienna POI Explorer');
    expect(logger, isA<AppLogger>());
    expect(handler, isA<ErrorHandler>());
  });

  test('AppLogger redacts sensitive tokens and keys', () {
    final redacted = AppLogger.redactText(
      'GET https://example.com?api_key=secret123 Bearer abc.def.ghi',
    );
    expect(redacted, isNot(contains('secret123')));
    expect(redacted, isNot(contains('abc.def.ghi')));
    expect(redacted, contains('[REDACTED]'));

    final context = AppLogger.sanitizeContext({
      'endpoint': 'https://example.com?token=xyz',
      'authorization': 'Bearer secret',
      'count': 5,
    });
    expect(context['authorization'], '[REDACTED]');
    expect(context['endpoint'], isNot(contains('xyz')));
    expect(context['count'], 5);
  });

  test('ErrorHandler maps transport and parsing errors to AppException', () {
    const handler = ErrorHandler(AppLogger());

    final timeoutError = DioException(
      requestOptions: RequestOptions(path: '/pois'),
      type: DioExceptionType.connectionTimeout,
    );
    expect(handler.map(timeoutError), isA<NetworkException>());
    expect(
      handler.map(const SocketException('offline')),
      isA<NetworkException>(),
    );
    expect(
      handler.map(const FormatException('bad json')),
      isA<PoiDataException>(),
    );
    expect(handler.map(StateError('boom')), isA<UnexpectedException>());
  });

  testWidgets('AsyncValueView renders loading, error, empty, and data states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AsyncValueView<List<String>>(
            value: AsyncValue.loading(),
            loadingMessage: 'Loading places...',
            builder: _buildItems,
          ),
        ),
      ),
    );
    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.text('Loading places...'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AsyncValueView<List<String>>(
            value: AsyncValue.error(
              PoiDataException('Service unavailable'),
              StackTrace.empty,
            ),
            builder: _buildItems,
          ),
        ),
      ),
    );
    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('Service unavailable'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AsyncValueView<List<String>>(
            value: const AsyncValue.data(<String>[]),
            isEmpty: (items) => items.isEmpty,
            emptyTitle: 'No places found',
            builder: _buildItems,
          ),
        ),
      ),
    );
    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('No places found'), findsOneWidget);
  });
}

Widget _buildItems(List<String> items) => Text(items.join(', '));
