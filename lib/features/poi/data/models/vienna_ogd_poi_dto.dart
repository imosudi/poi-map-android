import 'dart:convert';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/poi.dart';
import '../../domain/services/poi_category_classifier.dart';

/// GeoJSON FeatureCollection transfer model for `ogdwien:SEHENSWUERDIGOGD`.
final class ViennaOgdFeatureCollectionDto {
  const ViennaOgdFeatureCollectionDto({
    required this.features,
    this.totalFeatures,
    this.numberReturned,
    this.timeStamp,
    this.skippedFeatureCount = 0,
  });

  final List<ViennaOgdPoiDto> features;
  final int? totalFeatures;
  final int? numberReturned;
  final DateTime? timeStamp;
  final int skippedFeatureCount;

  /// Decodes a raw GeoJSON string into a [ViennaOgdFeatureCollectionDto].
  static ViennaOgdFeatureCollectionDto parseJsonString(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw PoiDataException(
        'Received malformed GeoJSON data from Vienna OGD.',
        cause: error,
      );
    }

    if (decoded is! Map) {
      throw const PoiDataException(
        'Expected a GeoJSON FeatureCollection object.',
      );
    }

    return ViennaOgdFeatureCollectionDto.fromJson(
      Map<String, dynamic>.from(decoded),
    );
  }

  factory ViennaOgdFeatureCollectionDto.fromJson(Map<String, dynamic> json) {
    final rawFeatures = json['features'];
    if (rawFeatures is! List) {
      throw const PoiDataException(
        'GeoJSON response is missing a valid features list.',
      );
    }

    final parsed = <ViennaOgdPoiDto>[];
    var skipped = 0;

    for (final item in rawFeatures) {
      final dto = ViennaOgdPoiDto.tryFromJson(item);
      if (dto == null) {
        skipped++;
      } else {
        parsed.add(dto);
      }
    }

    return ViennaOgdFeatureCollectionDto(
      features: List.unmodifiable(parsed),
      totalFeatures: _asInt(json['totalFeatures']),
      numberReturned: _asInt(json['numberReturned']),
      timeStamp: _asDateTime(json['timeStamp']),
      skippedFeatureCount: skipped,
    );
  }

  /// Maps all valid feature DTOs into domain [Poi] entities.
  List<Poi> toDomainList() {
    final entities = <Poi>[];
    for (final feature in features) {
      final poi = feature.toDomain();
      if (poi != null) {
        entities.add(poi);
      }
    }
    return List.unmodifiable(entities);
  }
}

/// GeoJSON Feature transfer model for a single Vienna sight record.
final class ViennaOgdPoiDto {
  const ViennaOgdPoiDto({
    required this.name,
    required this.longitude,
    required this.latitude,
    this.featureId,
    this.objectId,
    this.address,
    this.infoUrl,
    this.thumbnailUrl,
  });

  final String? featureId;
  final int? objectId;
  final String name;
  final double longitude;
  final double latitude;
  final String? address;
  final String? infoUrl;
  final String? thumbnailUrl;

  /// Attempts to parse a GeoJSON feature map, returning `null` if malformed.
  static ViennaOgdPoiDto? tryFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    final geometry = raw['geometry'];
    if (geometry is! Map) {
      return null;
    }

    final geometryType = _asTrimmedString(geometry['type']);
    if (geometryType != 'Point') {
      return null;
    }

    final rawCoords = geometry['coordinates'];
    if (rawCoords is! List || rawCoords.length < 2) {
      return null;
    }

    final lon = _asDouble(rawCoords[0]);
    final lat = _asDouble(rawCoords[1]);
    if (lon == null || lat == null || !Poi.isValidCoordinate(lat, lon)) {
      return null;
    }

    final properties = raw['properties'];
    if (properties is! Map) {
      return null;
    }

    final name = _asTrimmedString(properties['NAME']);
    if (name == null) {
      return null;
    }

    return ViennaOgdPoiDto(
      featureId: _asIdString(raw['id']),
      objectId: _asInt(properties['OBJECTID']),
      name: name,
      longitude: lon,
      latitude: lat,
      address: _asTrimmedString(properties['ADRESSE']),
      infoUrl: _asTrimmedString(properties['WEITERE_INF']),
      thumbnailUrl: _asTrimmedString(properties['THUMBNAIL']),
    );
  }

  /// Maps this transfer model into a domain [Poi], or `null` if invalid.
  Poi? toDomain() {
    if (!Poi.isValidCoordinate(latitude, longitude)) {
      return null;
    }

    return Poi(
      id: resolveStableId(),
      name: name,
      category: PoiCategoryClassifier.classify(name),
      latitude: latitude,
      longitude: longitude,
      address: address,
      infoUrl: _parseHttpUri(infoUrl),
      thumbnailUrl: _parseHttpUri(thumbnailUrl),
      sourceObjectId: objectId,
    );
  }

  /// Resolves a stable identifier, using a deterministic hash only when no
  /// source identifier (`feature.id` or `OBJECTID`) is available.
  String resolveStableId() {
    final rawFeatureId = featureId;
    if (rawFeatureId != null && rawFeatureId.isNotEmpty) {
      return rawFeatureId;
    }
    if (objectId != null) {
      return 'SEHENSWUERDIGOGD.$objectId';
    }
    final fingerprint =
        '${name.toLowerCase()}|${latitude.toStringAsFixed(6)}|${longitude.toStringAsFixed(6)}';
    return 'poi_${_fnv1a64Hex(fingerprint)}';
  }
}

String? _asTrimmedString(Object? value) {
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _asIdString(Object? value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  if (value is int) {
    return value.toString();
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value.trim());
  }
  return null;
}

double? _asDouble(Object? value) {
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  return null;
}

DateTime? _asDateTime(Object? value) {
  if (value is! String) {
    return null;
  }
  return DateTime.tryParse(value.trim());
}

Uri? _parseHttpUri(String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
    return null;
  }
  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'http' && scheme != 'https') {
    return null;
  }
  return uri;
}

String _fnv1a64Hex(String input) {
  final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
  final prime = BigInt.parse('100000001b3', radix: 16);
  final mask = (BigInt.one << 64) - BigInt.one;

  var hash = offsetBasis;
  for (final byte in utf8.encode(input)) {
    hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}
