import '../../../poi/domain/entities/poi.dart';
import '../../domain/entities/saved_place.dart';

/// JSON serialization helpers for [SavedPlace].
abstract final class SavedPlaceDto {
  static Map<String, Object?> toJson(SavedPlace place) {
    return {
      'id': place.id,
      'name': place.name,
      'category': place.category,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'address': place.address,
      'savedAt': place.savedAt.toUtc().toIso8601String(),
    };
  }

  static SavedPlace? tryFromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }

    final id = _trimmedString(raw['id']);
    final name = _trimmedString(raw['name']);
    final lat = _asDouble(raw['latitude']);
    final lon = _asDouble(raw['longitude']);
    if (id == null ||
        name == null ||
        lat == null ||
        lon == null ||
        !Poi.isValidCoordinate(lat, lon)) {
      return null;
    }

    final savedAtRaw = _trimmedString(raw['savedAt']);
    final savedAt = savedAtRaw == null
        ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
        : (DateTime.tryParse(savedAtRaw)?.toUtc() ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));

    return SavedPlace(
      id: id,
      name: name,
      category: _trimmedString(raw['category']),
      latitude: lat,
      longitude: lon,
      address: _trimmedString(raw['address']),
      savedAt: savedAt,
    );
  }

  static String? _trimmedString(Object? value) {
    if (value is! String) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      final d = value.toDouble();
      return d.isFinite ? d : null;
    }
    return null;
  }
}
