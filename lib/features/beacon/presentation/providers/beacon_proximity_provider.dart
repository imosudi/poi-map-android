import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/beacon_proximity_engine.dart';
import '../../domain/beacon_proximity_models.dart';
import '../../domain/ble_scan_models.dart';
import 'beacon_registry_provider.dart';
import 'ble_scan_provider.dart';

/// Configurable proximity thresholds, EMA alpha, and cooldown settings.
final beaconProximityConfigProvider = Provider<BeaconProximityConfig>((ref) {
  return const BeaconProximityConfig();
});

/// Riverpod state exposing evaluated beacon proximity records and discovery events.
final class BeaconProximityViewState {
  const BeaconProximityViewState({
    this.recordsByBeaconId = const <String, BeaconProximityRecord>{},
    this.discoveryEvents = const <BeaconDiscoveryEvent>[],
  });

  final Map<String, BeaconProximityRecord> recordsByBeaconId;
  final List<BeaconDiscoveryEvent> discoveryEvents;
}

/// Controller evaluating RSSI sightings through [BeaconProximityEngine].
final beaconProximityProvider =
    NotifierProvider<BeaconProximityController, BeaconProximityViewState>(
      BeaconProximityController.new,
    );

/// Convenience provider returning beacons currently in [BeaconProximityState.inProximity].
final inProximityBeaconsProvider = Provider<List<BeaconProximityRecord>>((ref) {
  final state = ref.watch(beaconProximityProvider);
  return state.recordsByBeaconId.values
      .where((r) => r.state == BeaconProximityState.inProximity)
      .toList(growable: false);
});

/// Convenience provider returning beacons currently [BeaconProximityState.nearby]
/// or [BeaconProximityState.inProximity].
final nearbyBeaconsProvider = Provider<List<BeaconProximityRecord>>((ref) {
  final state = ref.watch(beaconProximityProvider);
  return state.recordsByBeaconId.values
      .where(
        (r) =>
            r.state == BeaconProximityState.nearby ||
            r.state == BeaconProximityState.inProximity,
      )
      .toList(growable: false);
});

final class BeaconProximityController
    extends Notifier<BeaconProximityViewState> {
  late BeaconProximityEngine _engine;
  final Map<String, DateTime> _lastProcessedTimestampByDevice =
      <String, DateTime>{};

  @override
  BeaconProximityViewState build() {
    final config = ref.watch(beaconProximityConfigProvider);
    _engine = BeaconProximityEngine(config: config);
    _lastProcessedTimestampByDevice.clear();

    ref.listen<List<BleRawScanResult>>(bleScanResultsProvider, (
      previous,
      next,
    ) {
      _processRawResults(next);
    });

    return const BeaconProximityViewState();
  }

  void _processRawResults(List<BleRawScanResult> rawResults) {
    final parser = ref.read(poiBeaconParserProvider);
    final registry = ref.read(beaconRegistryProvider).asData?.value;
    final newEvents = <BeaconDiscoveryEvent>[];

    for (final raw in rawResults) {
      final lastSeen = _lastProcessedTimestampByDevice[raw.deviceId];
      if (lastSeen != null && !raw.timestamp.isAfter(lastSeen)) {
        continue;
      }
      _lastProcessedTimestampByDevice[raw.deviceId] = raw.timestamp;

      final parsed = parser.parse(raw);
      final adv = parsed.advertisement;
      if (adv == null) continue;

      final entry = registry?.findByBeaconId(adv.beaconId);
      if (registry != null && entry == null) {
        continue;
      }

      final evaluation = _engine.evaluateObservation(
        beaconId: adv.beaconId,
        poiId: entry?.poiId,
        rssi: adv.rssi,
        observedAt: adv.observedAt,
      );
      newEvents.addAll(evaluation.triggeredEvents);
    }

    if (newEvents.isEmpty && _engine.records.isEmpty) {
      return;
    }

    state = BeaconProximityViewState(
      recordsByBeaconId: _engine.records,
      discoveryEvents: newEvents.isEmpty
          ? state.discoveryEvents
          : List<BeaconDiscoveryEvent>.unmodifiable([
              ...state.discoveryEvents,
              ...newEvents,
            ]),
    );
  }

  /// Evaluates temporary advertisement loss and lost timeouts at [now].
  void sweepTimeouts([DateTime? now]) {
    final evaluation = _engine.sweepTimeouts(now ?? DateTime.now().toUtc());
    state = BeaconProximityViewState(
      recordsByBeaconId: evaluation.recordsByBeaconId,
      discoveryEvents: state.discoveryEvents,
    );
  }

  /// Resets all tracked proximity state.
  void reset() {
    _engine.clear();
    _lastProcessedTimestampByDevice.clear();
    state = const BeaconProximityViewState();
  }
}

