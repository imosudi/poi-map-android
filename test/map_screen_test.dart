import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/core/widgets/app_error_view.dart';
import 'package:poi_map_android/core/widgets/app_loading_view.dart';
import 'package:poi_map_android/features/map/domain/map_camera_calculator.dart';
import 'package:poi_map_android/features/map/domain/user_location.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this._handler);

  final Future<List<Poi>> Function() _handler;
  int callCount = 0;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) {
    callCount++;
    return _handler();
  }
}

void main() {
  const samplePois = [
    Poi(id: '1', name: 'Stephansdom', latitude: 48.2085, longitude: 16.3731),
    Poi(
      id: '2',
      name: 'Schloss Belvedere',
      latitude: 48.1915,
      longitude: 16.3809,
    ),
  ];

  group('MapCameraCalculator', () {
    test('returns Vienna fallback camera for empty dataset', () {
      final spec = MapCameraCalculator.computeInitialCamera(const []);
      expect(spec.latitude, MapCameraCalculator.viennaLatitude);
      expect(spec.longitude, MapCameraCalculator.viennaLongitude);
      expect(spec.zoom, MapCameraCalculator.defaultZoom);
      expect(spec.hasBounds, isFalse);
    });

    test('centres on single POI with closer zoom', () {
      final spec = MapCameraCalculator.computeInitialCamera([samplePois.first]);
      expect(spec.latitude, 48.2085);
      expect(spec.longitude, 16.3731);
      expect(spec.zoom, MapCameraCalculator.singlePoiZoom);
      expect(spec.hasBounds, isFalse);
    });

    test('computes bounding box and midpoint for multiple POIs', () {
      final spec = MapCameraCalculator.computeInitialCamera(samplePois);
      expect(spec.latitude, closeTo(48.2000, 1e-4));
      expect(spec.longitude, closeTo(16.3770, 1e-4));
      expect(spec.hasBounds, isTrue);
      expect(spec.southwestLatitude, 48.1915);
      expect(spec.northeastLatitude, 48.2085);
    });

    test('includes user location in bounds alongside POIs', () {
      final spec = MapCameraCalculator.computeInitialCamera(
        [samplePois.first],
        userLocation: const UserLocation(latitude: 48.2500, longitude: 16.4200),
      );
      expect(spec.hasBounds, isTrue);
      expect(spec.southwestLatitude, 48.2085);
      expect(spec.southwestLongitude, 16.3731);
      expect(spec.northeastLatitude, 48.2500);
      expect(spec.northeastLongitude, 16.4200);
    });
  });

  group('MapScreen', () {
    testWidgets(
      'shows missing-key error state when API key is not configured',
      (WidgetTester tester) async {
        final repo = _FakePoiRepository(() async => samplePois);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              poiRepositoryProvider.overrideWithValue(repo),
              mapApiKeyConfiguredProvider.overrideWith((_) => false),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: MapScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AppErrorView), findsOneWidget);
        expect(find.text('Google Maps key missing'), findsOneWidget);
      },
    );

    testWidgets('shows loading state and retries on POI repository error', (
      WidgetTester tester,
    ) async {
      final completer = Completer<List<Poi>>();
      var failFirst = true;
      final repo = _FakePoiRepository(() {
        if (failFirst) {
          failFirst = false;
          return completer.future;
        }
        return Future.value(samplePois);
      });

      CameraPosition? capturedInitialPosition;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiRepositoryProvider.overrideWithValue(repo),
            mapApiKeyConfiguredProvider.overrideWith((_) => true),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MapScreen(
                mapBuilder: (context, initialPosition, markers, onMapCreated) {
                  capturedInitialPosition = initialPosition;
                  return const ColoredBox(
                    key: Key('stub-map'),
                    color: Colors.grey,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppLoadingView), findsOneWidget);
      expect(find.text('Loading Vienna map...'), findsOneWidget);

      completer.completeError(const NetworkException('Map data unavailable.'));
      await tester.pumpAndSettle();

      expect(find.byType(AppErrorView), findsOneWidget);
      expect(find.text('Map data unavailable.'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('stub-map')), findsOneWidget);
      expect(find.text('Initialising map...'), findsOneWidget);
      expect(capturedInitialPosition?.target.latitude, closeTo(48.2000, 1e-4));
      expect(capturedInitialPosition?.target.longitude, closeTo(16.3770, 1e-4));
    });
  });
}
