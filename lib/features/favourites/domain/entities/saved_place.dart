import '../../../poi/domain/entities/poi.dart';

/// Persistent saved-place record retaining enough data for offline display.
final class SavedPlace {
  const SavedPlace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.savedAt,
    this.category,
    this.address,
  });

  factory SavedPlace.fromPoi(Poi poi, {DateTime? savedAt}) {
    return SavedPlace(
      id: poi.id,
      name: poi.name,
      category: poi.category,
      latitude: poi.latitude,
      longitude: poi.longitude,
      address: poi.address,
      savedAt: (savedAt ?? DateTime.now()).toUtc(),
    );
  }

  final String id;
  final String name;
  final String? category;
  final double latitude;
  final double longitude;
  final String? address;
  final DateTime savedAt;

  /// Converts this saved record into a [Poi] for shared UI presentation.
  Poi toPoi() {
    return Poi(
      id: id,
      name: name,
      category: category,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is SavedPlace &&
        other.id == id &&
        other.name == name &&
        other.category == category &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.address == address &&
        other.savedAt == savedAt;
  }

  @override
  int get hashCode =>
      Object.hash(id, name, category, latitude, longitude, address, savedAt);
}
