import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/application/providers/location_provider.dart';
import 'package:poi_map_android/application/state/location_state.dart';
import 'package:poi_map_android/data/services/location_service.dart';
import 'package:poi_map_android/domain/entities/geo_coordinate.dart';

class _FakeLocationService implements LocationService {
  _FakeLocationService(this._result);

  LocationLookupResult _result;

  @override
  Future<LocationLookupResult> getCurrentLocation({
    bool requestPermission = true,
  }) async => _result;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  group('LocationNotifier', () {
    test('updates state to ready when coordinate is obtained', () async {
      final service = _FakeLocationService(
        const LocationLookupResult(
          outcome: LocationLookupOutcome.success,
          coordinate: GeoCoordinate(latitude: 48.2082, longitude: 16.3738),
        ),
      );
      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(locationProvider.notifier).refreshLocation();
      final state = container.read(locationProvider);

      expect(state.status, LocationStatus.ready);
      expect(state.isAuthorised, isTrue);
      expect(state.statusMessage, isNull);
    });

    test('reports permission denied and service disabled states', () async {
      final service = _FakeLocationService(
        const LocationLookupResult(
          outcome: LocationLookupOutcome.permissionDenied,
        ),
      );
      final container = ProviderContainer(
        overrides: [locationServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);

      await container.read(locationProvider.notifier).refreshLocation();
      expect(
        container.read(locationProvider).status,
        LocationStatus.permissionDenied,
      );
      expect(
        container.read(locationProvider).statusMessage,
        contains('Location access is off'),
      );

      service._result = const LocationLookupResult(
        outcome: LocationLookupOutcome.serviceDisabled,
      );
      await container.read(locationProvider.notifier).refreshLocation();
      expect(
        container.read(locationProvider).status,
        LocationStatus.serviceDisabled,
      );
      expect(
        container.read(locationProvider).statusMessage,
        contains('turned off'),
      );
    });
  });
}
