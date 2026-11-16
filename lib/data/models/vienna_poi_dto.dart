import '../../core/errors/app_exception.dart';
import '../../domain/entities/point_of_interest.dart';

/// Parses and validates Vienna OGD GeoJSON FeatureCollection payloads.
abstract final class ViennaPoiParser {
  static List<PointOfInterest> parseFeatureCollection(dynamic json) {
    if (json is! Map<String, dynamic>) {
      throw const PoiDataException('The Vienna places data could not be read.');
    }

    final type = json['type'];
    final features = json['features'];
    if (type != 'FeatureCollection' || features is! List) {
      throw const PoiDataException('The Vienna places data could not be read.');
    }

    final seenIds = <String>{};
    final places = <PointOfInterest>[];

    for (final rawFeature in features) {
      final poi = _parseFeature(rawFeature);
      if (poi != null && seenIds.add(poi.id)) {
        places.add(poi);
      }
    }

    if (features.isNotEmpty && places.isEmpty) {
      throw const PoiDataException('The Vienna places data could not be read.');
    }

    return places;
  }

  static PointOfInterest? _parseFeature(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    final geometry = raw['geometry'];
    final properties = raw['properties'];
    if (geometry is! Map<String, dynamic> ||
        properties is! Map<String, dynamic>) {
      return null;
    }

    if (geometry['type'] != 'Point') return null;
    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;

    final rawLon = coordinates[0];
    final rawLat = coordinates[1];
    if (rawLon is! num || rawLat is! num) return null;

    final longitude = rawLon.toDouble();
    final latitude = rawLat.toDouble();
    if (!isValidCoordinate(latitude: latitude, longitude: longitude)) {
      return null;
    }

    final name = _nonEmptyString(properties['NAME']);
    if (name == null) return null;

    final featureId = _nonEmptyString(raw['id']);
    final objectId = properties['OBJECTID'];
    final stableId =
        featureId ?? (objectId is int ? objectId.toString() : null);
    if (stableId == null) return null;

    return PointOfInterest(
      id: stableId,
      name: name,
      address: _nonEmptyString(properties['ADRESSE']),
      informationUrl: _validWebUrl(properties['WEITERE_INF']),
      thumbnailUrl: _validWebUrl(properties['THUMBNAIL']),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static bool isValidCoordinate({
    required double latitude,
    required double longitude,
  }) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  static String? _nonEmptyString(dynamic value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Uri? _validWebUrl(dynamic value) {
    final text = _nonEmptyString(value);
    if (text == null) return null;
    final uri = Uri.tryParse(text);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    if ((scheme == 'http' || scheme == 'https') && uri.host.isNotEmpty) {
      return uri;
    }
    return null;
  }
}

