import 'dart:math' as math;

import '../../domain/entities/geo_coordinate.dart';
import '../../domain/entities/point_of_interest.dart';

/// Pure-Dart distance calculation and formatting helpers for POIs.
abstract final class DistanceCalculator {
  static const double _earthRadiusMeters = 6371000.0;

  /// Calculates great-circle distance in metres using the Haversine formula.
  static double? distanceMeters({
    required GeoCoordinate from,
    required GeoCoordinate to,
  }) {
    if (!from.isValid || !to.isValid) return null;

    final dLat = _toRadians(to.latitude - from.latitude);
    final dLon = _toRadians(to.longitude - from.longitude);
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);

    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    final meters = _earthRadiusMeters * c;

    return meters.isFinite ? meters : null;
  }

  /// Calculates distance in metres from [userCoordinate] to [poi].
  static double? distanceToPoi({
    required GeoCoordinate? userCoordinate,
    required PointOfInterest poi,
  }) {
    if (userCoordinate == null) return null;
    return distanceMeters(
      from: userCoordinate,
      to: GeoCoordinate(latitude: poi.latitude, longitude: poi.longitude),
    );
  }

  /// Formats a distance in metres as `420 m` or `2.3 km`.
  static String? formatMeters(double? meters) {
    if (meters == null || !meters.isFinite || meters < 0) return null;
    if (meters.round() < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// Formats a user-facing distance string such as `420 m away`.
  static String? formatDistanceAway({
    required GeoCoordinate? userCoordinate,
    required PointOfInterest poi,
  }) {
    final meters = distanceToPoi(userCoordinate: userCoordinate, poi: poi);
    final formatted = formatMeters(meters);
    return formatted == null ? null : '$formatted away';
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}

