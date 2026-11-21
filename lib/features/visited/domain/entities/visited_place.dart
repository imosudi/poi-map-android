/// Persistent record of a Vienna Point of Interest visited via validated
/// proximity dwell time.
final class VisitedPlace {
  const VisitedPlace({
    required this.poiId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.firstVisitedAt,
    required this.lastVisitedAt,
    this.category,
    this.address,
    this.visitCount = 1,
    this.lastBeaconId,
  });

  /// Vienna OGD POI identifier (`Poi.id`).
  final String poiId;
  final String name;
  final String? category;
  final String? address;
  final double latitude;
  final double longitude;
  final DateTime firstVisitedAt;
  final DateTime lastVisitedAt;
  final int visitCount;
  final String? lastBeaconId;

  VisitedPlace copyWith({
    DateTime? lastVisitedAt,
    int? visitCount,
    String? lastBeaconId,
  }) {
    return VisitedPlace(
      poiId: poiId,
      name: name,
      category: category,
      address: address,
      latitude: latitude,
      longitude: longitude,
      firstVisitedAt: firstVisitedAt,
      lastVisitedAt: lastVisitedAt ?? this.lastVisitedAt,
      visitCount: visitCount ?? this.visitCount,
      lastBeaconId: lastBeaconId ?? this.lastBeaconId,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VisitedPlace &&
        other.poiId == poiId &&
        other.name == name &&
        other.category == category &&
        other.address == address &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.firstVisitedAt == firstVisitedAt &&
        other.lastVisitedAt == lastVisitedAt &&
        other.visitCount == visitCount &&
        other.lastBeaconId == lastBeaconId;
  }

  @override
  int get hashCode => Object.hash(
    poiId,
    name,
    category,
    address,
    latitude,
    longitude,
    firstVisitedAt,
    lastVisitedAt,
    visitCount,
    lastBeaconId,
  );
}

/// Configurable dwell-time and cooldown thresholds for recording POI visits.
final class VisitedPlaceConfig {
  const VisitedPlaceConfig({
    this.dwellDuration = const Duration(seconds: 8),
    this.visitCooldown = const Duration(minutes: 10),
  });

  /// Minimum continuous time a POI must remain in proximity before a visit
  /// is recorded.
  final Duration dwellDuration;

  /// Minimum interval before another visit is recorded for the same POI.
  final Duration visitCooldown;
}
