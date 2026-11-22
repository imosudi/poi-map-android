import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:poi_map_android/features/beacon/data/poi_beacon_parser.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_proximity_models.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_proximity_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_registry_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Physical ESP32-S3 POI-BEACON is discovered, parsed, and resolved on Android',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final registry = await container.read(beaconRegistryProvider.future);
      expect(registry.entries.isNotEmpty, isTrue);

      await container
          .read(bleScanningRepositoryProvider)
          .adapterStateStream
          .firstWhere((s) => s == BleAdapterState.on)
          .timeout(const Duration(seconds: 5));

      final completer = Completer<BeaconProximityRecord>();
      container.listen<List<BleRawScanResult>>(bleScanResultsProvider, (
        _,
        results,
      ) {
        for (final r in results) {
          final parsed = const PoiBeaconParser().parse(r);
          debugPrint(
            '[HIL] deviceId=${r.deviceId} rssi=${r.rssi} '
            'beaconId=${parsed.advertisement?.beaconId} '
            'rejection=${parsed.rejectionReason}',
          );
        }
      });
      container.listen<BeaconProximityViewState>(beaconProximityProvider, (
        _,
        next,
      ) {
        final rec = next.recordsByBeaconId['5649450000000001'];
        if (rec != null && !completer.isCompleted) {
          completer.complete(rec);
        }
      });

      final controller = container.read(bleScanControllerProvider.notifier);
      await controller.startScanning();

      final scanState = container.read(bleScanControllerProvider);
      debugPrint('[HIL] Scan state: ${scanState.status}');
      expect(scanState.status, BleScanSessionStatus.scanning);

      final record = await completer.future.timeout(
        const Duration(seconds: 10),
      );
      debugPrint(
        '[HIL] Resolved ESP32-S3: beaconId=${record.beaconId} '
        'poiId=${record.poiId} rawRssi=${record.rawRssi} '
        'filteredRssi=${record.filteredRssi} state=${record.state}',
      );

      expect(record.beaconId, '5649450000000001');
      expect(record.poiId, 'SEHENSWUERDIGOGD.644140');
      expect(record.rawRssi, isNotNull);

      await controller.stopScanning();
    },
  );
}
