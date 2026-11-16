import 'package:geolocator/geolocator.dart';

import '../../domain/entities/geo_coordinate.dart';

/// Result of a one-shot location lookup.
enum LocationLookupOutcome {
  success,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unavailable,
}

class LocationLookupResult {
  const LocationLookupResult({
    required this.outcome,
    this.coordinate,
    this.errorMessage,
  });

  final LocationLookupOutcome outcome;
  final GeoCoordinate? coordinate;
  final String? errorMessage;
}

/// Contract for obtaining the device's current location without background polling.
abstract interface class LocationService {
  Future<LocationLookupResult> getCurrentLocation({bool requestPermission});
  Future<bool> openLocationSettings();
  Future<bool> openAppSettings();
}

/// Geolocator-backed implementation of [LocationService].
class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationLookupResult> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationLookupResult(
          outcome: LocationLookupOutcome.serviceDisabled,
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const LocationLookupResult(
          outcome: LocationLookupOutcome.permissionDenied,
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const LocationLookupResult(
          outcome: LocationLookupOutcome.permissionDeniedForever,
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      final coordinate = GeoCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!coordinate.isValid) {
        return const LocationLookupResult(
          outcome: LocationLookupOutcome.unavailable,
          errorMessage: 'Received invalid device coordinates.',
        );
      }

      return LocationLookupResult(
        outcome: LocationLookupOutcome.success,
        coordinate: coordinate,
      );
    } catch (error) {
      return LocationLookupResult(
        outcome: LocationLookupOutcome.unavailable,
        errorMessage: error.toString(),
      );
    }
  }

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();
}
