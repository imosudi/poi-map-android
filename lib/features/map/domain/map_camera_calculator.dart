import 'dart:math' as math;

import '../../poi/domain/entities/poi.dart';

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

/// Computes sensible initial camera targets from Vienna POI coordinates.
abstract final class MapCameraCalculator {
  static const double viennaLatitude = 48.2082;
  static const double viennaLongitude = 16.3738;
  static const double defaultZoom = 12.5;
  static const double singlePoiZoom = 14.5;

  static MapCameraSpec computeInitialCamera(List<Poi> pois) {
    if (pois.isEmpty) {
      return const MapCameraSpec(
        latitude: viennaLatitude,
        longitude: viennaLongitude,
        zoom: defaultZoom,
      );
    }

    if (pois.length == 1) {
      final only = pois.first;
      return MapCameraSpec(
        latitude: only.latitude,
        longitude: only.longitude,
        zoom: singlePoiZoom,
      );
    }

    var minLat = pois.first.latitude;
    var maxLat = pois.first.latitude;
    var minLon = pois.first.longitude;
    var maxLon = pois.first.longitude;

    for (final poi in pois.skip(1)) {
      minLat = math.min(minLat, poi.latitude);
      maxLat = math.max(maxLat, poi.latitude);
      minLon = math.min(minLon, poi.longitude);
      maxLon = math.max(maxLon, poi.longitude);
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
