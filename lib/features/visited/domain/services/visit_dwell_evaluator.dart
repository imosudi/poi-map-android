import '../../../beacon/domain/beacon_proximity_models.dart';
import '../entities/visited_place.dart';

/// Validated visit candidate produced after dwell-time and cooldown checks.
final class ValidatedVisitCandidate {
  const ValidatedVisitCandidate({
    required this.poiId,
    required this.visitedAt,
    this.beaconId,
  });

  final String poiId;
  final DateTime visitedAt;
  final String? beaconId;
}

/// Evaluates whether registered beacons in [BeaconProximityState.inProximity]
/// satisfy dwell-time and cooldown requirements to record a visit.
final class VisitDwellEvaluator {
  VisitDwellEvaluator({
    this.config = const VisitedPlaceConfig(),
    Map<String, DateTime> initialLastVisitsByPoiId = const <String, DateTime>{},
  }) : _lastVisitAtByPoiId = Map<String, DateTime>.from(
         initialLastVisitsByPoiId,
       );

  final VisitedPlaceConfig config;
  final Map<String, DateTime> _dwellStartByPoiId = <String, DateTime>{};
  final Map<String, DateTime> _lastVisitAtByPoiId;

  /// Seeds persisted visit timestamps (e.g. after application restart).
  void seedLastVisits(Iterable<VisitedPlace> places) {
    for (final place in places) {
      final existing = _lastVisitAtByPoiId[place.poiId];
      if (existing == null || place.lastVisitedAt.isAfter(existing)) {
        _lastVisitAtByPoiId[place.poiId] = place.lastVisitedAt;
      }
    }
  }

  /// Clears in-memory dwell and cooldown tracking (e.g. when history is cleared).
  void clearTracking() {
    _dwellStartByPoiId.clear();
    _lastVisitAtByPoiId.clear();
  }

  /// Evaluates current proximity records and returns newly validated visits.
  ///
  /// Unregistered beacons (`poiId == null`) are ignored. Multiple beacons
  /// mapped to the same `poiId` share one dwell timer and one cooldown.
  List<ValidatedVisitCandidate> evaluate(
    Map<String, BeaconProximityRecord> recordsByBeaconId,
  ) {
    final activeInProximityByPoi = <String, BeaconProximityRecord>{};

    for (final record in recordsByBeaconId.values) {
      final poiId = record.poiId;
      if (poiId == null || poiId.trim().isEmpty) {
        // Unregistered beacons cannot generate visited POI records.
        continue;
      }
      if (record.state != BeaconProximityState.inProximity) {
        continue;
      }
      final observedAt = record.lastObservedAt;
      if (observedAt == null) {
        continue;
      }
      final current = activeInProximityByPoi[poiId];
      if (current == null || observedAt.isAfter(current.lastObservedAt!)) {
        activeInProximityByPoi[poiId] = record;
      }
    }

    // Reset dwell timers for POIs that are no longer in proximity.
    _dwellStartByPoiId.removeWhere(
      (poiId, _) => !activeInProximityByPoi.containsKey(poiId),
    );

    final candidates = <ValidatedVisitCandidate>[];
    for (final entry in activeInProximityByPoi.entries) {
      final poiId = entry.key;
      final record = entry.value;
      final observedAt = record.lastObservedAt!;

      final dwellStart = _dwellStartByPoiId.putIfAbsent(
        poiId,
        () => observedAt,
      );
      if (observedAt.difference(dwellStart) < config.dwellDuration) {
        continue;
      }

      final lastVisit = _lastVisitAtByPoiId[poiId];
      if (lastVisit != null &&
          observedAt.difference(lastVisit) < config.visitCooldown) {
        continue;
      }

      _lastVisitAtByPoiId[poiId] = observedAt;
      candidates.add(
        ValidatedVisitCandidate(
          poiId: poiId,
          visitedAt: observedAt,
          beaconId: record.beaconId,
        ),
      );
    }

    return List<ValidatedVisitCandidate>.unmodifiable(candidates);
  }
}
