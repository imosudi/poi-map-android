/// Immutable domain entity representing a Vienna Point of Interest.
final class Poi {
  const Poi({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.category,
    this.address,
    this.infoUrl,
    this.thumbnailUrl,
    this.sourceObjectId,
  });

  /// Stable identifier for this POI.
  final String id;

  /// Display name of the sight or landmark.
  final String name;

  /// Optional category label when supplied by the dataset.
  final String? category;

  /// WGS84 latitude in decimal degrees.
  final double latitude;

  /// WGS84 longitude in decimal degrees.
  final double longitude;

  /// Street address in Vienna, when provided by the dataset.
  final String? address;

  /// External information URL, when provided and valid.
  final Uri? infoUrl;

  /// Preview image URL, when provided and valid.
  final Uri? thumbnailUrl;

  /// Original numeric `OBJECTID` from the source dataset, if present.
  final int? sourceObjectId;

  /// Validates that [latitude] and [longitude] are finite WGS84 coordinates.
  static bool isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Poi &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.infoUrl == infoUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.sourceObjectId == sourceObjectId;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    category,
    latitude,
    longitude,
    address,
    infoUrl,
    thumbnailUrl,
    sourceObjectId,
  );

  @override
  String toString() =>
      'Poi(id: $id, name: $name, lat: $latitude, lon: $longitude)';
}
