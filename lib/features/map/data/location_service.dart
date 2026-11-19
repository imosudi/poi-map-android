import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/logging/app_logger.dart';
import '../domain/user_location.dart';

/// Platform abstraction over [Geolocator] for testable foreground location checks.
abstract interface class LocationPlatformAdapter {
  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
  Future<Position> getCurrentPosition();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}

final class GeolocatorPlatformAdapter implements LocationPlatformAdapter {
  const GeolocatorPlatformAdapter();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();

  @override
  Future<Position> getCurrentPosition() => Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 10),
    ),
  );

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();
}

/// Dedicated foreground location service with permission-aware error handling.
final class LocationService {
  const LocationService({LocationPlatformAdapter? adapter, AppLogger? logger})
    : _adapter = adapter ?? const GeolocatorPlatformAdapter(),
      _logger = logger;

  final LocationPlatformAdapter _adapter;
  final AppLogger? _logger;

  /// Requests foreground location permission if needed and retrieves the
  /// device's current position once without storing location history.
  Future<UserLocationResult> requestAndGetCurrentLocation() async {
    try {
      final serviceEnabled = await _adapter.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const UserLocationResult(
          status: LocationAccessStatus.serviceDisabled,
          message:
              'Location services are turned off. Enable GPS to centre on your position.',
        );
      }

      var permission = await _adapter.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _adapter.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        return const UserLocationResult(
          status: LocationAccessStatus.denied,
          message:
              'Location access was declined. You can continue browsing Vienna sights.',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        return const UserLocationResult(
          status: LocationAccessStatus.permanentlyDenied,
          message:
              'Location permission is permanently denied. Enable it in app settings to show your position.',
        );
      }

      final position = await _adapter.getCurrentPosition();
      if (!position.latitude.isFinite || !position.longitude.isFinite) {
        return const UserLocationResult(
          status: LocationAccessStatus.error,
          message: 'Unable to read a valid GPS position right now.',
        );
      }

      return UserLocationResult(
        status: LocationAccessStatus.granted,
        location: UserLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracyMeters: position.accuracy.isFinite ? position.accuracy : null,
        ),
      );
    } on TimeoutException catch (error, stackTrace) {
      _logger?.warning(
        'LocationService',
        'Location request timed out',
        error: error,
        stackTrace: stackTrace,
      );
      return const UserLocationResult(
        status: LocationAccessStatus.error,
        message: 'Location request timed out. Please try again.',
      );
    } on LocationServiceDisabledException catch (error, stackTrace) {
      _logger?.warning(
        'LocationService',
        'Device location service disabled',
        error: error,
        stackTrace: stackTrace,
      );
      return const UserLocationResult(
        status: LocationAccessStatus.serviceDisabled,
        message:
            'Location services are turned off. Enable GPS to centre on your position.',
      );
    } on PermissionDeniedException catch (error, stackTrace) {
      _logger?.warning(
        'LocationService',
        'Location permission denied',
        error: error,
        stackTrace: stackTrace,
      );
      return const UserLocationResult(
        status: LocationAccessStatus.denied,
        message:
            'Location access was declined. You can continue browsing Vienna sights.',
      );
    } catch (error, stackTrace) {
      _logger?.error(
        'LocationService',
        'Failed to retrieve current location',
        error: error,
        stackTrace: stackTrace,
      );
      return const UserLocationResult(
        status: LocationAccessStatus.error,
        message: 'Unable to determine your current location right now.',
      );
    }
  }

  Future<bool> openAppSettings() => _adapter.openAppSettings();

  Future<bool> openLocationSettings() => _adapter.openLocationSettings();
}
