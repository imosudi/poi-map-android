/// Configurable qualitative proximity states derived from filtered RSSI.
///
/// These states reflect radio signal strength trends rather than precise
/// physical distance.
enum BeaconProximityState { unknown, outOfRange, nearby, inProximity, lost }

/// Configuration for RSSI smoothing, hysteresis thresholds, and cooldowns.
final class BeaconProximityConfig {
  const BeaconProximityConfig({
    this.emaAlpha = 0.35,
    this.minValidRssi = -120,
    this.maxValidRssi = 0,
    this.inProximityEnterRssi = -65.0,
    this.inProximityExitRssi = -72.0,
    this.nearbyEnterRssi = -80.0,
    this.nearbyExitRssi = -86.0,
    this.temporaryLossGracePeriod = const Duration(seconds: 4),
    this.lostTimeout = const Duration(seconds: 10),
    this.discoveryCooldown = const Duration(seconds: 30),
  }) : assert(emaAlpha > 0 && emaAlpha <= 1.0),
       assert(inProximityExitRssi < inProximityEnterRssi),
       assert(nearbyExitRssi < nearbyEnterRssi),
       assert(nearbyEnterRssi < inProximityExitRssi);

  /// Exponential moving average smoothing factor (0 < alpha <= 1).
  final double emaAlpha;

  /// Lower sanity bound for RSSI readings in dBm.
  final int minValidRssi;

  /// Upper sanity bound for RSSI readings in dBm.
  final int maxValidRssi;

  /// Filtered RSSI threshold to enter [BeaconProximityState.inProximity].
  final double inProximityEnterRssi;

  /// Filtered RSSI threshold below which [BeaconProximityState.inProximity] exits.
  final double inProximityExitRssi;

  /// Filtered RSSI threshold to enter [BeaconProximityState.nearby].
  final double nearbyEnterRssi;

  /// Filtered RSSI threshold below which [BeaconProximityState.nearby] exits.
  final double nearbyExitRssi;

  /// Window during which missed advertisements do not mark the beacon lost.
  final Duration temporaryLossGracePeriod;

  /// Inactivity duration after which a beacon transitions to [BeaconProximityState.lost].
  final Duration lostTimeout;

  /// Minimum time before the same beacon can emit another discovery event.
  final Duration discoveryCooldown;
}

/// Immutable proximity snapshot for a single tracked beacon.
final class BeaconProximityRecord {
  const BeaconProximityRecord({
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeaconProximityRecord &&
        other.beaconId == beaconId &&
        other.poiId == poiId &&
        other.state == state &&
        other.rawRssi == rawRssi &&
        other.filteredRssi == filteredRssi &&
        other.firstObservedAt == firstObservedAt &&
        other.lastObservedAt == lastObservedAt &&
        other.lastDiscoveryTriggeredAt == lastDiscoveryTriggeredAt &&
        other.observationCount == observationCount;
  }

  @override
  int get hashCode => Object.hash(
    beaconId,
    poiId,
    state,
    rawRssi,
    filteredRssi,
    firstObservedAt,
    lastObservedAt,
    lastDiscoveryTriggeredAt,
    observationCount,
  );
}

/// Event emitted when a beacon enters [BeaconProximityState.inProximity] outside
/// its discovery cooldown window.
final class BeaconDiscoveryEvent {
  const BeaconDiscoveryEvent({
    required this.beaconId,
    required this.filteredRssi,
    required this.triggeredAt,
    this.poiId,
  });

  final String beaconId;
  final String? poiId;
  final double filteredRssi;
  final DateTime triggeredAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BeaconDiscoveryEvent &&
        other.beaconId == beaconId &&
        other.poiId == poiId &&
        other.filteredRssi == filteredRssi &&
        other.triggeredAt == triggeredAt;
  }

  @override
  int get hashCode => Object.hash(beaconId, poiId, filteredRssi, triggeredAt);
}

/// Outcome returned after evaluating a beacon observation or timeout sweep.
final class BeaconProximityEvaluationResult {
  const BeaconProximityEvaluationResult({
    required this.recordsByBeaconId,
    this.triggeredEvents = const <BeaconDiscoveryEvent>[],
  });

  final Map<String, BeaconProximityRecord> recordsByBeaconId;
  final List<BeaconDiscoveryEvent> triggeredEvents;
}

