/// Foreground device coordinates for the current session only.
final class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
    this.accuracyMeters,
  });

  final double latitude;
  final double longitude;
  final double? accuracyMeters;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is UserLocation &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.accuracyMeters == accuracyMeters;
  }

  @override
  int get hashCode => Object.hash(latitude, longitude, accuracyMeters);
}

/// Outcome of a foreground location request.
enum LocationAccessStatus {
  granted,
  denied,
  permanentlyDenied,
  serviceDisabled,
  error,
}

/// Result returned by [LocationService.requestAndGetCurrentLocation].
final class UserLocationResult {
  const UserLocationResult({required this.status, this.location, this.message});

  final LocationAccessStatus status;
  final UserLocation? location;
  final String? message;

  bool get isGranted =>
      status == LocationAccessStatus.granted && location != null;
}
