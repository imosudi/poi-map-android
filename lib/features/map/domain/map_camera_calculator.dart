import 'dart:math' as math;

import '../../poi/domain/entities/poi.dart';
import 'user_location.dart';

/// Immutable camera target computed from a collection of POIs.
final class MapCameraSpec {
  const MapCameraSpec({
    required this.latitude,
    required this.longitude,
    required this.zoom,
    this.southwestLatitude,
    this.southwestLongitude,
    this.northeastLatitude,
    this.northeastLongitude,
  });

  final double latitude;
  final double longitude;
  final double zoom;
  final double? southwestLatitude;
  final double? southwestLongitude;
  final double? northeastLatitude;
  final double? northeastLongitude;

  bool get hasBounds =>
      southwestLatitude != null &&
      southwestLongitude != null &&
      northeastLatitude != null &&
      northeastLongitude != null;
}

/// Computes sensible camera targets from Vienna POI coordinates and optional
/// user location.
abstract final class MapCameraCalculator {
  static const double viennaLatitude = 48.2082;
  static const double viennaLongitude = 16.3738;
  static const double defaultZoom = 12.5;
  static const double singlePoiZoom = 14.5;

  static MapCameraSpec computeInitialCamera(
    List<Poi> pois, {
    UserLocation? userLocation,
  }) {
    final points = <(double lat, double lon)>[
      for (final poi in pois)
        if (Poi.isValidCoordinate(poi.latitude, poi.longitude))
          (poi.latitude, poi.longitude),
      if (userLocation != null &&
          Poi.isValidCoordinate(userLocation.latitude, userLocation.longitude))
        (userLocation.latitude, userLocation.longitude),
    ];

    if (points.isEmpty) {
      return const MapCameraSpec(
        latitude: viennaLatitude,
        longitude: viennaLongitude,
        zoom: defaultZoom,
      );
    }

    if (points.length == 1) {
      final only = points.first;
      return MapCameraSpec(
        latitude: only.$1,
        longitude: only.$2,
        zoom: singlePoiZoom,
      );
    }

    var minLat = points.first.$1;
    var maxLat = points.first.$1;
    var minLon = points.first.$2;
    var maxLon = points.first.$2;

    for (final point in points.skip(1)) {
      minLat = math.min(minLat, point.$1);
      maxLat = math.max(maxLat, point.$1);
      minLon = math.min(minLon, point.$2);
      maxLon = math.max(maxLon, point.$2);
    }

    final centerLat = (minLat + maxLat) / 2.0;
    final centerLon = (minLon + maxLon) / 2.0;
    final maxSpan = math.max(maxLat - minLat, maxLon - minLon);

    final double zoom;
    if (maxSpan <= 0.005) {
      zoom = 15.0;
    } else if (maxSpan <= 0.02) {
      zoom = 13.5;
    } else if (maxSpan <= 0.08) {
      zoom = 12.0;
    } else if (maxSpan <= 0.25) {
      zoom = 11.0;
    } else {
      zoom = 9.5;
    }

    return MapCameraSpec(
      latitude: centerLat,
      longitude: centerLon,
      zoom: zoom,
      southwestLatitude: minLat,
      southwestLongitude: minLon,
      northeastLatitude: maxLat,
      northeastLongitude: maxLon,
    );
  }
}
