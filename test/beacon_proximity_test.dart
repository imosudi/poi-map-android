import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/features/beacon/data/beacon_registry_local_data_source.dart';
import 'package:poi_map_android/features/beacon/data/ble_scan_data_source.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_proximity_engine.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_proximity_models.dart';
import 'package:poi_map_android/features/beacon/domain/ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_proximity_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_registry_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';

final class _InMemoryRegistryDataSource
    implements BeaconRegistryLocalDataSource {
  @override
  Future<String?> readPersistedJson() async => null;

  @override
  Future<String> readSeedAssetJson() async => '''
{
  "version": 1,
  "beacons": [
    {
      "beaconId": "5649450000000001",
      "poiId": "SEHENSWUERDIGOGD.643871",
      "label": "Ankeruhr",
      "enabled": true
    }
  ]
}
''';

  @override
  Future<void> writePersistedJson(String rawJson) async {}
}

final class _FakeBlePermissionService implements BlePermissionService {
  @override
  Future<BlePermissionStatus> checkPermission() async =>
      BlePermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<BlePermissionStatus> requestPermission() async =>
      BlePermissionStatus.granted;
}

final class _FakeBleScanDataSource implements BleScanDataSource {
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<List<BleRawScanResult>> _resultsController =
      StreamController<List<BleRawScanResult>>.broadcast();
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();
  bool _scanning = false;

  @override
  Stream<BleAdapterState> get adapterState => _adapterController.stream;

  @override
  Stream<bool> get isScanning => _scanningController.stream;

  @override
  bool get isScanningNow => _scanning;

  @override
  Stream<List<BleRawScanResult>> get scanResults => _resultsController.stream;

  @override
  Future<BleAdapterState> getCurrentAdapterState() async => BleAdapterState.on;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> startScan({
    required List<String> withServices,
    Duration? timeout,
  }) async {
    _scanning = true;
    _scanningController.add(true);
  }

  @override
  Future<void> stopScan() async {
    _scanning = false;
    _scanningController.add(false);
  }

  void emit(List<BleRawScanResult> results) => _resultsController.add(results);

  Future<void> dispose() async {
    await _adapterController.close();
    await _resultsController.close();
    await _scanningController.close();
  }
}

void main() {
  group('BeaconProximityEngine', () {
    final t0 = DateTime.utc(2026, 11, 21, 14, 0, 0);

    test(
      'smooths noisy RSSI sequence using EMA and prevents single-spike false entry',
      () {
        final engine = BeaconProximityEngine(
          config: const BeaconProximityConfig(
            emaAlpha: 0.35,
            inProximityEnterRssi: -65,
            inProximityExitRssi: -72,
            nearbyEnterRssi: -80,
            nearbyExitRssi: -86,
          ),
        );

        // Baseline far/nearby readings around -78 dBm.
        engine.evaluateObservation(
          beaconId: '5649450000000001',
          poiId: 'SEHENSWUERDIGOGD.643871',
          rssi: -78,
          observedAt: t0,
        );
        // Single noisy spike (-55) should not immediately jump to inProximity.
        final spikeResult = engine.evaluateObservation(
          beaconId: '5649450000000001',
          poiId: 'SEHENSWUERDIGOGD.643871',
          rssi: -55,
          observedAt: t0.add(const Duration(seconds: 1)),
        );

        final record = spikeResult.recordsByBeaconId['5649450000000001']!;
        expect(record.state, BeaconProximityState.nearby);
        expect(record.filteredRssi!, closeTo(-69.95, 0.01));
        expect(spikeResult.triggeredEvents, isEmpty);
      },
    );

    test('applies entry and exit hysteresis across threshold transitions', () {
      final engine = BeaconProximityEngine(
        config: const BeaconProximityConfig(
          emaAlpha:
              1.0, // Direct step check for deterministic hysteresis verification.
          inProximityEnterRssi: -65,
          inProximityExitRssi: -72,
          nearbyEnterRssi: -80,
          nearbyExitRssi: -86,
          discoveryCooldown: Duration(seconds: 30),
        ),
      );

      // Start out of range.
      var res = engine.evaluateObservation(
        beaconId: '5649450000000001',
        poiId: 'SEHENSWUERDIGOGD.643871',
        rssi: -90,
        observedAt: t0,
      );
      expect(
        res.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.outOfRange,
      );

      // Cross nearbyEnter (-80).
      res = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -78,
        observedAt: t0.add(const Duration(seconds: 1)),
      );
      expect(
        res.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.nearby,
      );

      // Cross inProximityEnter (-65) -> triggers discovery event.
      res = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -64,
        observedAt: t0.add(const Duration(seconds: 2)),
      );
      expect(
        res.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.inProximity,
      );
      expect(res.triggeredEvents, hasLength(1));

      // Fluctuate inside hysteresis band (-68, -70) -> remains inProximity, no new event.
      for (final rssi in [-68, -70, -66]) {
        res = engine.evaluateObservation(
          beaconId: '5649450000000001',
          rssi: rssi,
          observedAt: t0.add(const Duration(seconds: 3)),
        );
        expect(
          res.recordsByBeaconId['5649450000000001']!.state,
          BeaconProximityState.inProximity,
        );
        expect(res.triggeredEvents, isEmpty);
      }

      // Drop below inProximityExit (-72) -> transitions to nearby.
      res = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -74,
        observedAt: t0.add(const Duration(seconds: 4)),
      );
      expect(
        res.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.nearby,
      );

      // Drop below nearbyExit (-86) -> transitions to outOfRange.
      res = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -88,
        observedAt: t0.add(const Duration(seconds: 5)),
      );
      expect(
        res.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.outOfRange,
      );
    });

    test('enforces discovery cooldown on rapid re-entry', () {
      final engine = BeaconProximityEngine(
        config: const BeaconProximityConfig(
          emaAlpha: 1.0,
          discoveryCooldown: Duration(seconds: 30),
        ),
      );

      // First entry at t0 -> triggers.
      final first = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -60,
        observedAt: t0,
      );
      expect(first.triggeredEvents, hasLength(1));

      // Exit to outOfRange at t0+5s, then re-enter at t0+10s (< 30s cooldown) -> suppressed.
      engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -90,
        observedAt: t0.add(const Duration(seconds: 5)),
      );
      final suppressed = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -60,
        observedAt: t0.add(const Duration(seconds: 10)),
      );
      expect(
        suppressed.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.inProximity,
      );
      expect(suppressed.triggeredEvents, isEmpty);

      // Exit at t0+35s and re-enter at t0+36s (>= 30s cooldown) -> triggers again.
      engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -90,
        observedAt: t0.add(const Duration(seconds: 35)),
      );
      final allowed = engine.evaluateObservation(
        beaconId: '5649450000000001',
        rssi: -60,
        observedAt: t0.add(const Duration(seconds: 36)),
      );
      expect(allowed.triggeredEvents, hasLength(1));
    });

    test(
      'handles temporary advertisement loss before transitioning to lost',
      () {
        final engine = BeaconProximityEngine(
          config: const BeaconProximityConfig(
            emaAlpha: 1.0,
            temporaryLossGracePeriod: Duration(seconds: 4),
            lostTimeout: Duration(seconds: 10),
          ),
        );

        engine.evaluateObservation(
          beaconId: '5649450000000001',
          rssi: -62,
          observedAt: t0,
        );

        // Within grace period (3s) -> stays inProximity.
        var sweep = engine.sweepTimeouts(t0.add(const Duration(seconds: 3)));
        expect(
          sweep.recordsByBeaconId['5649450000000001']!.state,
          BeaconProximityState.inProximity,
        );

        // After lostTimeout (11s) -> transitions to lost.
        sweep = engine.sweepTimeouts(t0.add(const Duration(seconds: 11)));
        expect(
          sweep.recordsByBeaconId['5649450000000001']!.state,
          BeaconProximityState.lost,
        );

        // Resumed advertisement recovers to nearby.
        final recovered = engine.evaluateObservation(
          beaconId: '5649450000000001',
          rssi: -75,
          observedAt: t0.add(const Duration(seconds: 12)),
        );
        expect(
          recovered.recordsByBeaconId['5649450000000001']!.state,
          BeaconProximityState.nearby,
        );
      },
    );

    test('tracks multiple simultaneously detected beacons independently', () {
      final engine = BeaconProximityEngine(
        config: const BeaconProximityConfig(emaAlpha: 1.0),
      );

      engine.evaluateObservation(
        beaconId: '5649450000000001',
        poiId: 'SEHENSWUERDIGOGD.643871',
        rssi: -60,
        observedAt: t0,
      );
      final second = engine.evaluateObservation(
        beaconId: '5649450000000002',
        poiId: 'SEHENSWUERDIGOGD.643872',
        rssi: -76,
        observedAt: t0.add(const Duration(seconds: 1)),
      );

      expect(second.recordsByBeaconId, hasLength(2));
      expect(
        second.recordsByBeaconId['5649450000000001']!.state,
        BeaconProximityState.inProximity,
      );
      expect(
        second.recordsByBeaconId['5649450000000002']!.state,
        BeaconProximityState.nearby,
      );
    });
  });

  group('Riverpod beaconProximityProvider', () {
    test(
      'exposes proximity states and discovery events from BLE scans',
      () async {
        final scanDataSource = _FakeBleScanDataSource();
        final container = ProviderContainer(
          overrides: [
            beaconRegistryDataSourceProvider.overrideWithValue(
              _InMemoryRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(
              _FakeBlePermissionService(),
            ),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
            beaconProximityConfigProvider.overrideWithValue(
              const BeaconProximityConfig(emaAlpha: 1.0),
            ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await scanDataSource.dispose();
        });

        await container.read(beaconRegistryProvider.future);
        final sub = container.listen(beaconProximityProvider, (_, _) {});
        addTearDown(sub.close);
        await container
            .read(bleScanControllerProvider.notifier)
            .startScanning();

        final t0 = DateTime.utc(2026, 11, 21, 15, 0, 0);
        scanDataSource.emit([
          BleRawScanResult(
            deviceId: 'AA:BB:CC:DD:EE:01',
            rssi: -61,
            serviceData: const {
              PoiBeaconProtocolConstants.serviceUuid: [
                0x01,
                0x01,
                0x56,
                0x49,
                0x45,
                0x00,
                0x00,
                0x00,
                0x00,
                0x01,
              ],
            },
            serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
            localName: '',
            timestamp: t0,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        final inProximity = container.read(inProximityBeaconsProvider);
        expect(inProximity, hasLength(1));
        expect(inProximity.first.beaconId, '5649450000000001');
        expect(inProximity.first.poiId, 'SEHENSWUERDIGOGD.643871');
        expect(
          container.read(beaconProximityProvider).discoveryEvents,
          hasLength(1),
        );

        // Sweep after lostTimeout -> moves to lost.
        container
            .read(beaconProximityProvider.notifier)
            .sweepTimeouts(t0.add(const Duration(seconds: 15)));
        expect(container.read(inProximityBeaconsProvider), isEmpty);
        expect(
          container
              .read(beaconProximityProvider)
              .recordsByBeaconId['5649450000000001']
              ?.state,
          BeaconProximityState.lost,
        );
      },
    );
  });
}
