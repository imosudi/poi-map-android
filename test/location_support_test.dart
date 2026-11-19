import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/map/data/location_service.dart';
import 'package:poi_map_android/features/map/domain/user_location.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';

final class _FakeLocationAdapter implements LocationPlatformAdapter {
  _FakeLocationAdapter({
    this.serviceEnabled = true,
    this.initialPermission = LocationPermission.whileInUse,
    this.requestedPermission = LocationPermission.whileInUse,
    this.errorOnGetPosition,
  });

  final bool serviceEnabled;
  final LocationPermission initialPermission;
  final LocationPermission requestedPermission;
  final Object? errorOnGetPosition;

  bool requestCalled = false;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => initialPermission;

  @override
  Future<LocationPermission> requestPermission() async {
    requestCalled = true;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition() async {
    if (errorOnGetPosition != null) {
      throw errorOnGetPosition!;
    }
    return Position(
      latitude: 48.2082,
      longitude: 16.3738,
      timestamp: DateTime(2026, 11, 19),
      accuracy: 12.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

final class _FakePoiRepository implements PoiRepository {
  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    return const [
      Poi(id: '1', name: 'Stephansdom', latitude: 48.2085, longitude: 16.3731),
    ];
  }
}

void main() {
  group('LocationService', () {
    test('returns serviceDisabled when device location is off', () async {
      final service = LocationService(
        adapter: _FakeLocationAdapter(serviceEnabled: false),
      );

      final result = await service.requestAndGetCurrentLocation();
      expect(result.status, LocationAccessStatus.serviceDisabled);
      expect(result.isGranted, isFalse);
      expect(result.message, contains('Location services are turned off'));
    });

    test(
      'requests permission when denied and handles declined result',
      () async {
        final adapter = _FakeLocationAdapter(
          initialPermission: LocationPermission.denied,
          requestedPermission: LocationPermission.denied,
        );
        final service = LocationService(adapter: adapter);

        final result = await service.requestAndGetCurrentLocation();
        expect(adapter.requestCalled, isTrue);
        expect(result.status, LocationAccessStatus.denied);
        expect(result.isGranted, isFalse);
      },
    );

    test('handles permanently denied permission', () async {
      final service = LocationService(
        adapter: _FakeLocationAdapter(
          initialPermission: LocationPermission.deniedForever,
        ),
      );

      final result = await service.requestAndGetCurrentLocation();
      expect(result.status, LocationAccessStatus.permanentlyDenied);
      expect(result.message, contains('permanently denied'));
    });

    test('retrieves current position when permission is granted', () async {
      final service = LocationService(adapter: _FakeLocationAdapter());

      final result = await service.requestAndGetCurrentLocation();
      expect(result.isGranted, isTrue);
      expect(result.location?.latitude, 48.2082);
      expect(result.location?.longitude, 16.3738);
    });

    test('handles timeout when retrieving current position', () async {
      final service = LocationService(
        adapter: _FakeLocationAdapter(
          errorOnGetPosition: TimeoutException('timed out'),
        ),
      );

      final result = await service.requestAndGetCurrentLocation();
      expect(result.status, LocationAccessStatus.error);
      expect(result.message, contains('timed out'));
    });
  });

  group('MapScreen location controls', () {
    testWidgets('adds user_location marker when My location succeeds', (
      WidgetTester tester,
    ) async {
      Set<Marker> capturedMarkers = {};
      final service = LocationService(adapter: _FakeLocationAdapter());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiRepositoryProvider.overrideWithValue(_FakePoiRepository()),
            mapApiKeyConfiguredProvider.overrideWith((_) => true),
            locationServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MapScreen(
                mapBuilder: (context, initialPosition, markers, onMapCreated) {
                  capturedMarkers = markers;
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
      await tester.pump();

      expect(
        capturedMarkers.any((m) => m.markerId.value == 'user_location'),
        isFalse,
      );

      tester
          .widget<FloatingActionButton>(
            find.byWidgetPredicate(
              (w) => w is FloatingActionButton && w.tooltip == 'My location',
            ),
          )
          .onPressed
          ?.call();
      await tester.pump();
      await tester.pump();

      expect(
        capturedMarkers.any((m) => m.markerId.value == 'user_location'),
        isTrue,
      );
    });

    testWidgets('shows SnackBar with Settings action when permanently denied', (
      WidgetTester tester,
    ) async {
      final service = LocationService(
        adapter: _FakeLocationAdapter(
          initialPermission: LocationPermission.deniedForever,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiRepositoryProvider.overrideWithValue(_FakePoiRepository()),
            mapApiKeyConfiguredProvider.overrideWith((_) => true),
            locationServiceProvider.overrideWithValue(service),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: MapScreen(
                mapBuilder: (context, initialPosition, markers, onMapCreated) {
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
      await tester.pump();

      tester
          .widget<FloatingActionButton>(
            find.byWidgetPredicate(
              (w) => w is FloatingActionButton && w.tooltip == 'My location',
            ),
          )
          .onPressed
          ?.call();
      await tester.pump();
      await tester.pump();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.byKey(const Key('stub-map')), findsOneWidget);
    });
  });
}
