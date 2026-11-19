import 'dart:math' as math;

import '../../poi/domain/entities/poi.dart';

/// Computes Haversine straight-line geographic distances and metric labels.
abstract final class DistanceCalculator {
  static const double _earthRadiusMeters = 6371000.0;

  /// Returns the great-circle distance in metres between two WGS84 points,
  /// or `null` if either coordinate pair is invalid.
  static double? metersBetween({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) {
    if (!Poi.isValidCoordinate(startLatitude, startLongitude) ||
        !Poi.isValidCoordinate(endLatitude, endLongitude)) {
      return null;
    }

    if (startLatitude == endLatitude && startLongitude == endLongitude) {
      return 0.0;
    }

    final dLat = _toRadians(endLatitude - startLatitude);
    final dLon = _toRadians(endLongitude - startLongitude);
    final lat1 = _toRadians(startLatitude);
    final lat2 = _toRadians(endLatitude);

    final sinHalfLat = math.sin(dLat / 2.0);
    final sinHalfLon = math.sin(dLon / 2.0);

    final a =
        sinHalfLat * sinHalfLat +
        math.cos(lat1) * math.cos(lat2) * sinHalfLon * sinHalfLon;
    final c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a));
    return _earthRadiusMeters * c;
  }

  /// Formats [meters] into concise metric units (`m` below 1 km, `km` above).
  static String? formatMeters(double? meters) {
    if (meters == null || !meters.isFinite || meters < 0) {
      return null;
    }

    final roundedMeters = meters.round();
    if (roundedMeters < 1000) {
      return '$roundedMeters m';
    }

    final kilometres = meters / 1000.0;
    return '${kilometres.toStringAsFixed(1)} km';
  }

  static double _toRadians(double degrees) => degrees * (math.pi / 180.0);
}
