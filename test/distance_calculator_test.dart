import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/map/data/location_service.dart';
import 'package:poi_map_android/features/map/domain/distance_calculator.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/widgets/selected_poi_card.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';

final class _FakePoiRepository implements PoiRepository {
  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    return const [
      Poi(id: '1', name: 'Stephansdom', latitude: 48.2085, longitude: 16.3731),
      Poi(
        id: '2',
        name: 'Schloss Schönbrunn',
        latitude: 48.1845,
        longitude: 16.3122,
      ),
    ];
  }
}

final class _FixedLocationAdapter implements LocationPlatformAdapter {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<Position> getCurrentPosition() async => Position(
    latitude: 48.2108,
    longitude: 16.3737,
    timestamp: DateTime(2026, 11, 19),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('DistanceCalculator', () {
    test('returns zero for identical coordinates', () {
      final meters = DistanceCalculator.metersBetween(
        startLatitude: 48.2085,
        startLongitude: 16.3731,
        endLatitude: 48.2085,
        endLongitude: 16.3731,
      );
      expect(meters, 0.0);
      expect(DistanceCalculator.formatMeters(meters), '0 m');
    });

    test('calculates short distances within Vienna in metres', () {
      final meters = DistanceCalculator.metersBetween(
        startLatitude: 48.2085,
        startLongitude: 16.3731,
        endLatitude: 48.2108,
        endLongitude: 16.3737,
      );
      expect(meters, isNotNull);
      expect(meters!, closeTo(259, 10));
      expect(DistanceCalculator.formatMeters(meters), endsWith(' m'));
    });

    test('calculates longer distances in kilometres', () {
      final meters = DistanceCalculator.metersBetween(
        startLatitude: 48.2085,
        startLongitude: 16.3731,
        endLatitude: 48.1845,
        endLongitude: 16.3122,
      );
      expect(meters, isNotNull);
      expect(meters!, closeTo(5250, 150));
      expect(DistanceCalculator.formatMeters(meters), endsWith(' km'));
    });

    test('calculates distances across different geographic regions', () {
      final meters = DistanceCalculator.metersBetween(
        startLatitude: 51.5074,
        startLongitude: -0.1278,
        endLatitude: 48.8566,
        endLongitude: 2.3522,
      );
      expect(meters, isNotNull);
      expect(meters! / 1000.0, closeTo(343.6, 2.0));
    });

    test('returns null for invalid coordinates', () {
      expect(
        DistanceCalculator.metersBetween(
          startLatitude: 95.0,
          startLongitude: 16.37,
          endLatitude: 48.20,
          endLongitude: 16.37,
        ),
        isNull,
      );
      expect(
        DistanceCalculator.metersBetween(
          startLatitude: 48.20,
          startLongitude: double.nan,
          endLatitude: 48.20,
          endLongitude: 16.37,
        ),
        isNull,
      );
      expect(
        DistanceCalculator.metersBetween(
          startLatitude: 48.20,
          startLongitude: 16.37,
          endLatitude: 48.20,
          endLongitude: -181.0,
        ),
        isNull,
      );
    });

    test('formats and rounds metric units consistently', () {
      expect(DistanceCalculator.formatMeters(null), isNull);
      expect(DistanceCalculator.formatMeters(-5), isNull);
      expect(DistanceCalculator.formatMeters(double.infinity), isNull);
      expect(DistanceCalculator.formatMeters(0.4), '0 m');
      expect(DistanceCalculator.formatMeters(999.4), '999 m');
      expect(DistanceCalculator.formatMeters(999.6), '1.0 km');
      expect(DistanceCalculator.formatMeters(1249), '1.2 km');
    });
  });

  group('selectedPoiDistanceLabelProvider', () {
    test(
      'returns null when location or selection is missing and updates on change',
      () async {
        final container = ProviderContainer(
          overrides: [
            poiRepositoryProvider.overrideWithValue(_FakePoiRepository()),
            locationServiceProvider.overrideWithValue(
              LocationService(adapter: _FixedLocationAdapter()),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(poiCatalogueProvider.future);
        expect(container.read(selectedPoiDistanceLabelProvider), isNull);

        container.read(selectedPoiIdProvider.notifier).select('1');
        expect(container.read(selectedPoiDistanceLabelProvider), isNull);

        await container.read(userLocationProvider.notifier).locateUser();
        final labelA = container.read(selectedPoiDistanceLabelProvider);
        expect(labelA, startsWith('Direct distance: '));
        expect(labelA, endsWith(' m'));

        container.read(selectedPoiIdProvider.notifier).select('2');
        final labelB = container.read(selectedPoiDistanceLabelProvider);
        expect(labelB, startsWith('Direct distance: '));
        expect(labelB, endsWith(' km'));
      },
    );
  });

  testWidgets('SelectedPoiCard renders distance label when provided', (
    WidgetTester tester,
  ) async {
    const poi = Poi(
      id: '1',
      name: 'Stephansdom',
      latitude: 48.2085,
      longitude: 16.3731,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SelectedPoiCard(
            poi: poi,
            distanceLabel: 'Direct distance: 260 m',
            onDismiss: () {},
          ),
        ),
      ),
    );
    expect(find.text('Direct distance: 260 m'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SelectedPoiCard(poi: poi, onDismiss: () {}),
        ),
      ),
    );
    expect(find.text('Direct distance: 260 m'), findsNothing);
    expect(
      find.text('Grant location access for distance information.'),
      findsOneWidget,
    );
  });
}
