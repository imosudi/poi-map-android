import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/config/app_config.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/errors/error_handler.dart';
import 'package:poi_map_android/core/logging/app_logger.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/core/network/dio_factory.dart';
import 'package:poi_map_android/features/poi/data/datasources/vienna_ogd_api_service.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/data/repositories/remote_poi_repository.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';

typedef _AdapterHandler = Future<ResponseBody> Function(RequestOptions options);

final class _MockHttpClientAdapter implements HttpClientAdapter {
  _MockHttpClientAdapter(this._handler);

  final _AdapterHandler _handler;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    lastRequest = options;
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _jsonResponse(String body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    body,
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
    },
  );
}

PoiRepository _buildRepository(_AdapterHandler handler) {
  const config = AppConfig(
    appName: 'Vienna POI Explorer',
    environment: AppEnvironment.development,
    viennaOgdBaseUrl: 'https://data.wien.gv.at/daten/geo',
  );
  const logger = AppLogger();
  final dio = DioFactory.create(
    config: config,
    logger: logger,
    adapter: _MockHttpClientAdapter(handler),
  );
  final service = ViennaOgdApiService(
    dio: dio,
    errorHandler: const ErrorHandler(logger),
  );
  return RemotePoiRepository(apiService: service, logger: logger);
}

void main() {
  group('RemotePoiRepository', () {
    test('retrieves and maps valid Vienna OGD records', () async {
      RequestOptions? captured;
      final repo = _buildRepository((options) async {
        captured = options;
        return _jsonResponse(
          jsonEncode({
            'type': 'FeatureCollection',
            'features': [
              {
                'type': 'Feature',
                'id': 'SEHENSWUERDIGOGD.643871',
                'geometry': {
                  'type': 'Point',
                  'coordinates': [16.37367575, 48.21076056],
                },
                'properties': {
                  'OBJECTID': 643871,
                  'NAME': 'Ankeruhr',
                  'ADRESSE': 'Hoher Markt 10/',
                  'WEITERE_INF':
                      'http://www.wien.info/article.asp?IDArticle=2018',
                  'THUMBNAIL':
                      'https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg',
                },
              },
            ],
          }),
        );
      });

      final pois = await repo.fetchPois();
      expect(pois, hasLength(1));
      expect(pois.first.id, 'SEHENSWUERDIGOGD.643871');
      expect(pois.first.name, 'Ankeruhr');
      expect(
        captured?.queryParameters,
        ViennaOgdApiService.defaultQueryParameters,
      );
    });

    test('returns empty list when dataset has no features', () async {
      final repo = _buildRepository(
        (_) async => _jsonResponse(
          jsonEncode({'type': 'FeatureCollection', 'features': <Object>[]}),
        ),
      );

      final pois = await repo.fetchPois();
      expect(pois, isEmpty);
    });

    test('maps HTTP 500 server error to NetworkException', () async {
      final repo = _buildRepository(
        (_) async => _jsonResponse('Internal Server Error', statusCode: 500),
      );

      await expectLater(repo.fetchPois(), throwsA(isA<NetworkException>()));
    });

    test('maps connection failure to NetworkException', () async {
      final repo = _buildRepository((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          message: 'Failed host lookup',
        );
      });

      await expectLater(repo.fetchPois(), throwsA(isA<NetworkException>()));
    });

    test('maps timeout to NetworkException', () async {
      final repo = _buildRepository((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
        );
      });

      await expectLater(repo.fetchPois(), throwsA(isA<NetworkException>()));
    });

    test('maps malformed JSON response to PoiDataException', () async {
      final repo = _buildRepository(
        (_) async => _jsonResponse('<html>not json</html>'),
      );

      await expectLater(repo.fetchPois(), throwsA(isA<PoiDataException>()));
    });

    test(
      'preserves valid records when dataset contains malformed entries',
      () async {
        final repo = _buildRepository(
          (_) async => _jsonResponse(
            jsonEncode({
              'type': 'FeatureCollection',
              'features': [
                {
                  'type': 'Feature',
                  'id': 'SEHENSWUERDIGOGD.1',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [16.37, 48.20],
                  },
                  'properties': {'OBJECTID': 1, 'NAME': 'Valid Sight'},
                },
                {
                  'type': 'Feature',
                  'id': 'bad-record',
                  'geometry': {
                    'type': 'Point',
                    'coordinates': [16.37, 120.0],
                  },
                  'properties': {'NAME': 'Invalid Latitude'},
                },
              ],
            }),
          ),
        );

        final pois = await repo.fetchPois();
        expect(pois, hasLength(1));
        expect(pois.first.name, 'Valid Sight');
      },
    );

    test(
      'supports request cancellation without leaking DioException',
      () async {
        final token = CancellationToken()..cancel();
        final repo = _buildRepository(
          (_) async =>
              _jsonResponse('{"type":"FeatureCollection","features":[]}'),
        );

        await expectLater(
          repo.fetchPois(cancelToken: token),
          throwsA(isA<NetworkException>()),
        );
      },
    );

    test('poiRepositoryProvider resolves RemotePoiRepository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(poiRepositoryProvider), isA<RemotePoiRepository>());
    });
  });
}
