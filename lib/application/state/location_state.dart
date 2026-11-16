import '../../domain/entities/geo_coordinate.dart';

/// Status of the device's foreground location permission and fix.
enum LocationStatus {
  initial,
  loading,
  ready,
  permissionDenied,
  permissionDeniedForever,
  serviceDisabled,
  unavailable,
}

/// Immutable state for location-aware exploration.
class LocationState {
  const LocationState({
    this.status = LocationStatus.initial,
    this.coordinate,
    this.errorDetail,
  });

  final LocationStatus status;
  final GeoCoordinate? coordinate;
  final String? errorDetail;

  bool get isAuthorised => status == LocationStatus.ready;

  String? get statusMessage {
    switch (status) {
      case LocationStatus.initial:
        return null;
      case LocationStatus.loading:
        return 'Finding your location…';
      case LocationStatus.ready:
        return null;
      case LocationStatus.permissionDenied:
        return 'Location access is off. Enable it to see your position and distances.';
      case LocationStatus.permissionDeniedForever:
        return 'Location permission is permanently denied. Enable it in Settings to see distances.';
      case LocationStatus.serviceDisabled:
        return 'Location services are turned off on this device.';
      case LocationStatus.unavailable:
        return errorDetail == null
            ? 'Location is currently unavailable.'
            : 'Location unavailable: $errorDetail';
    }
  }
}

