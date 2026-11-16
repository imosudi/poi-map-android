import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/location_service.dart';
import '../state/location_state.dart';

/// Provides the foreground [LocationService].
final locationServiceProvider = Provider<LocationService>((ref) {
  return GeolocatorLocationService();
});

/// Manages on-demand foreground location retrieval without continuous polling.
class LocationNotifier extends Notifier<LocationState> {
  @override
  LocationState build() => const LocationState();

  Future<void> refreshLocation({bool requestPermission = true}) async {
    if (state.status == LocationStatus.loading) return;
    state = LocationState(
      status: LocationStatus.loading,
      coordinate: state.coordinate,
    );

    final result = await ref
        .read(locationServiceProvider)
        .getCurrentLocation(requestPermission: requestPermission);

    switch (result.outcome) {
      case LocationLookupOutcome.success:
        state = LocationState(
          status: LocationStatus.ready,
          coordinate: result.coordinate,
        );
      case LocationLookupOutcome.serviceDisabled:
        state = const LocationState(status: LocationStatus.serviceDisabled);
      case LocationLookupOutcome.permissionDenied:
        state = const LocationState(status: LocationStatus.permissionDenied);
      case LocationLookupOutcome.permissionDeniedForever:
        state = const LocationState(
          status: LocationStatus.permissionDeniedForever,
        );
      case LocationLookupOutcome.unavailable:
        state = LocationState(
          status: LocationStatus.unavailable,
          errorDetail: result.errorMessage,
        );
    }
  }

  Future<void> openSettings() async {
    final service = ref.read(locationServiceProvider);
    if (state.status == LocationStatus.serviceDisabled) {
      await service.openLocationSettings();
    } else {
      await service.openAppSettings();
    }
  }
}

/// Global Riverpod provider for [LocationNotifier].
final locationProvider = NotifierProvider<LocationNotifier, LocationState>(
  LocationNotifier.new,
);

