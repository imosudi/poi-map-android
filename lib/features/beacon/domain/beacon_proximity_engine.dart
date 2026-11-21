import 'beacon_proximity_models.dart';

/// Pure-Dart proximity evaluation engine using EMA RSSI smoothing, entry/exit
/// hysteresis, temporary loss tolerance, and per-beacon discovery cooldowns.
final class BeaconProximityEngine {
  BeaconProximityEngine({this.config = const BeaconProximityConfig()});

  final BeaconProximityConfig config;
  final Map<String, _TrackedBeacon> _tracked = <String, _TrackedBeacon>{};

  Map<String, BeaconProximityRecord> get records => Map.unmodifiable({
    for (final entry in _tracked.entries) entry.key: entry.value.toRecord(),
  });

  /// Evaluates a new RSSI observation for [beaconId] at [observedAt].
  BeaconProximityEvaluationResult evaluateObservation({
    required String beaconId,
    required int rssi,
    required DateTime observedAt,
    String? poiId,
  }) {
    final existing = _tracked[beaconId];

    // Reject impossible RSSI sentinel values without corrupting smoothed state.
    if (rssi < config.minValidRssi || rssi > config.maxValidRssi) {
      final record =
          existing ??
          _TrackedBeacon(
            beaconId: beaconId,
            poiId: poiId,
            state: BeaconProximityState.unknown,
          );
      _tracked[beaconId] = record;
      return BeaconProximityEvaluationResult(recordsByBeaconId: records);
    }

    final previousState = existing?.state ?? BeaconProximityState.unknown;
    final smoothed = existing?.filteredRssi == null
        ? rssi.toDouble()
        : (config.emaAlpha * rssi) +
              ((1.0 - config.emaAlpha) * existing!.filteredRssi!);

    final nextState = _resolveStateWithHysteresis(
      previousState: previousState,
      filteredRssi: smoothed,
    );

    final triggeredEvents = <BeaconDiscoveryEvent>[];
    var lastTriggeredAt = existing?.lastDiscoveryTriggeredAt;

    final enteredProximity =
        nextState == BeaconProximityState.inProximity &&
        previousState != BeaconProximityState.inProximity;

    if (enteredProximity &&
        _isCooldownElapsed(lastTriggeredAt: lastTriggeredAt, now: observedAt)) {
      lastTriggeredAt = observedAt;
      triggeredEvents.add(
        BeaconDiscoveryEvent(
          beaconId: beaconId,
          poiId: poiId ?? existing?.poiId,
          filteredRssi: smoothed,
          triggeredAt: observedAt,
        ),
      );
    }

    _tracked[beaconId] = _TrackedBeacon(
      beaconId: beaconId,
      poiId: poiId ?? existing?.poiId,
      state: nextState,
      rawRssi: rssi,
      filteredRssi: smoothed,
      firstObservedAt: existing?.firstObservedAt ?? observedAt,
      lastObservedAt: observedAt,
      lastDiscoveryTriggeredAt: lastTriggeredAt,
      observationCount: (existing?.observationCount ?? 0) + 1,
    );

    return BeaconProximityEvaluationResult(
      recordsByBeaconId: records,
      triggeredEvents: List<BeaconDiscoveryEvent>.unmodifiable(triggeredEvents),
    );
  }

  /// Evaluates temporary advertisement loss and [BeaconProximityConfig.lostTimeout]
  /// across all tracked beacons at [now].
  BeaconProximityEvaluationResult sweepTimeouts(DateTime now) {
    for (final entry in _tracked.entries.toList(growable: false)) {
      final tracked = entry.value;
      final lastSeen = tracked.lastObservedAt;
      if (lastSeen == null) continue;

      final elapsed = now.difference(lastSeen);
      if (elapsed <= config.temporaryLossGracePeriod) {
        // Temporary advertisement loss: keep current proximity state.
        continue;
      }

      if (elapsed >= config.lostTimeout &&
          tracked.state != BeaconProximityState.lost &&
          tracked.state != BeaconProximityState.unknown) {
        _tracked[entry.key] = tracked.copyWith(
          state: BeaconProximityState.lost,
        );
      }
    }

    return BeaconProximityEvaluationResult(recordsByBeaconId: records);
  }

  void clear() => _tracked.clear();

  BeaconProximityState _resolveStateWithHysteresis({
    required BeaconProximityState previousState,
    required double filteredRssi,
  }) {
    switch (previousState) {
      case BeaconProximityState.inProximity:
        if (filteredRssi < config.nearbyExitRssi) {
          return BeaconProximityState.outOfRange;
        }
        if (filteredRssi < config.inProximityExitRssi) {
          return BeaconProximityState.nearby;
        }
        return BeaconProximityState.inProximity;

      case BeaconProximityState.nearby:
        if (filteredRssi >= config.inProximityEnterRssi) {
          return BeaconProximityState.inProximity;
        }
        if (filteredRssi < config.nearbyExitRssi) {
          return BeaconProximityState.outOfRange;
        }
        return BeaconProximityState.nearby;

      case BeaconProximityState.unknown:
      case BeaconProximityState.outOfRange:
      case BeaconProximityState.lost:
        if (filteredRssi >= config.inProximityEnterRssi) {
          return BeaconProximityState.inProximity;
        }
        if (filteredRssi >= config.nearbyEnterRssi) {
          return BeaconProximityState.nearby;
        }
        return BeaconProximityState.outOfRange;
    }
  }

  bool _isCooldownElapsed({
    required DateTime? lastTriggeredAt,
    required DateTime now,
  }) {
    if (lastTriggeredAt == null) return true;
    return now.difference(lastTriggeredAt) >= config.discoveryCooldown;
  }
}

final class _TrackedBeacon {
  const _TrackedBeacon({
    required this.beaconId,
    required this.state,
    this.poiId,
    this.rawRssi,
    this.filteredRssi,
    this.firstObservedAt,
    this.lastObservedAt,
    this.lastDiscoveryTriggeredAt,
    this.observationCount = 0,
  });

  final String beaconId;
  final String? poiId;
  final BeaconProximityState state;
  final int? rawRssi;
  final double? filteredRssi;
  final DateTime? firstObservedAt;
  final DateTime? lastObservedAt;
  final DateTime? lastDiscoveryTriggeredAt;
  final int observationCount;

  _TrackedBeacon copyWith({BeaconProximityState? state}) {
    return _TrackedBeacon(
      beaconId: beaconId,
      poiId: poiId,
      state: state ?? this.state,
      rawRssi: rawRssi,
      filteredRssi: filteredRssi,
      firstObservedAt: firstObservedAt,
      lastObservedAt: lastObservedAt,
      lastDiscoveryTriggeredAt: lastDiscoveryTriggeredAt,
      observationCount: observationCount,
    );
  }

  BeaconProximityRecord toRecord() {
    return BeaconProximityRecord(
      beaconId: beaconId,
      poiId: poiId,
      state: state,
      rawRssi: rawRssi,
      filteredRssi: filteredRssi,
      firstObservedAt: firstObservedAt,
      lastObservedAt: lastObservedAt,
      lastDiscoveryTriggeredAt: lastDiscoveryTriggeredAt,
      observationCount: observationCount,
    );
  }
}

