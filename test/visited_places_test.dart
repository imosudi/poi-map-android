import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/beacon/data/beacon_registry_local_data_source.dart';
import 'package:poi_map_android/features/beacon/data/ble_scan_data_source.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_proximity_models.dart';
import 'package:poi_map_android/features/beacon/domain/ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_proximity_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_registry_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';
import 'package:poi_map_android/features/map/presentation/widgets/selected_poi_card.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';
import 'package:poi_map_android/features/poi/presentation/widgets/poi_list_item.dart';
import 'package:poi_map_android/features/visited/domain/entities/visited_place.dart';
import 'package:poi_map_android/features/visited/domain/repositories/visited_places_repository.dart';
import 'package:poi_map_android/features/visited/domain/services/visit_dwell_evaluator.dart';
import 'package:poi_map_android/features/visited/presentation/providers/visited_places_provider.dart';
import 'package:poi_map_android/features/visited/presentation/screens/visited_history_screen.dart';

final class _InMemoryVisitedRepository implements VisitedPlacesRepository {
  final List<VisitedPlace> _store = <VisitedPlace>[];

  @override
  Future<List<VisitedPlace>> loadVisitedPlaces() async => List.of(_store);

  @override
  Future<List<VisitedPlace>> recordVisit(
    Poi poi, {
    required DateTime visitedAt,
    String? beaconId,
  }) async {
    final index = _store.indexWhere((e) => e.poiId == poi.id);
    if (index >= 0) {
      final existing = _store[index];
      _store[index] = existing.copyWith(
        lastVisitedAt: visitedAt.toUtc(),
        visitCount: existing.visitCount + 1,
        lastBeaconId: beaconId,
      );
    } else {
      _store.add(
        VisitedPlace(
          poiId: poi.id,
          name: poi.name,
          category: poi.category,
          address: poi.address,
          latitude: poi.latitude,
          longitude: poi.longitude,
          firstVisitedAt: visitedAt.toUtc(),
          lastVisitedAt: visitedAt.toUtc(),
          visitCount: 1,
          lastBeaconId: beaconId,
        ),
      );
    }
    _store.sort((a, b) => b.lastVisitedAt.compareTo(a.lastVisitedAt));
    return List.of(_store);
  }

  @override
  Future<List<VisitedPlace>> clearHistory() async {
    _store.clear();
    return const <VisitedPlace>[];
  }
}

final class _FakeRegistryDataSource implements BeaconRegistryLocalDataSource {
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
      "label": "Ankeruhr Main",
      "enabled": true
    },
    {
      "beaconId": "5649450000000002",
      "poiId": "SEHENSWUERDIGOGD.643871",
      "label": "Ankeruhr Arcade",
      "enabled": true
    }
  ]
}
''';

  @override
  Future<void> writePersistedJson(String rawJson) async {}
}

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this.pois);
  final List<Poi> pois;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async => pois;
}

final class _FakeBlePermissionService implements BlePermissionService {
  @override
  Future<BlePermissionStatus> checkPermission() async =>
      BlePermissionStatus.granted;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openBluetoothSettings() async => true;

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

  @override
  Future<void> turnOnBluetooth() async {}

  void emit(List<BleRawScanResult> results) => _resultsController.add(results);

  Future<void> dispose() async {
    await _adapterController.close();
    await _resultsController.close();
    await _scanningController.close();
  }
}

void main() {
  const ankeruhr = Poi(
    id: 'SEHENSWUERDIGOGD.643871',
    name: 'Ankeruhr',
    category: 'Landmark',
    address: 'Hoher Markt 10/',
    latitude: 48.21076056,
    longitude: 16.37367575,
  );

  group('VisitDwellEvaluator', () {
    final t0 = DateTime.utc(2026, 11, 21, 10, 0, 0);

    test(
      'requires dwell duration before recording visit and ignores unknown beacons',
      () {
        final evaluator = VisitDwellEvaluator(
          config: const VisitedPlaceConfig(
            dwellDuration: Duration(seconds: 8),
            visitCooldown: Duration(minutes: 10),
          ),
        );

        // Single observation (0s dwell) + unregistered beacon (poiId == null) -> no visit.
        var visits = evaluator.evaluate({
          '5649450000000001': BeaconProximityRecord(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0,
          ),
          '9999999999999999': BeaconProximityRecord(
            beaconId: '9999999999999999',
            poiId: null,
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0,
          ),
        });
        expect(visits, isEmpty);

        // Still below dwellDuration (5s) + unregistered beacon stays ignored.
        visits = evaluator.evaluate({
          '5649450000000001': BeaconProximityRecord(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 5)),
          ),
          '9999999999999999': BeaconProximityRecord(
            beaconId: '9999999999999999',
            poiId: null,
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 12)),
          ),
        });
        expect(visits, isEmpty);

        // Reaches dwellDuration (8s) -> records 1 visit for registered POI only.
        visits = evaluator.evaluate({
          '5649450000000001': BeaconProximityRecord(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 8)),
          ),
        });
        expect(visits, hasLength(1));
        expect(visits.single.poiId, 'SEHENSWUERDIGOGD.643871');
        expect(visits.single.visitedAt, t0.add(const Duration(seconds: 8)));
      },
    );

    test(
      'prevents repeated visits during continuous ads and multi-beacon associations',
      () {
        final evaluator = VisitDwellEvaluator(
          config: const VisitedPlaceConfig(
            dwellDuration: Duration(seconds: 8),
            visitCooldown: Duration(minutes: 10),
          ),
        );

        // Start dwell via beacon 1.
        evaluator.evaluate({
          '5649450000000001': BeaconProximityRecord(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0,
          ),
        });

        // Both beacons 1 and 2 in proximity at t0+9s -> exactly 1 visit emitted.
        final first = evaluator.evaluate({
          '5649450000000001': BeaconProximityRecord(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 9)),
          ),
          '5649450000000002': BeaconProximityRecord(
            beaconId: '5649450000000002',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 9)),
          ),
        });
        expect(first, hasLength(1));

        // Continuous advertisements at t0+30s -> suppressed by cooldown.
        final suppressed = evaluator.evaluate({
          '5649450000000002': BeaconProximityRecord(
            beaconId: '5649450000000002',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(seconds: 30)),
          ),
        });
        expect(suppressed, isEmpty);

        // After 10-minute cooldown (t0+10m20s) -> records second visit.
        final second = evaluator.evaluate({
          '5649450000000002': BeaconProximityRecord(
            beaconId: '5649450000000002',
            poiId: 'SEHENSWUERDIGOGD.643871',
            state: BeaconProximityState.inProximity,
            lastObservedAt: t0.add(const Duration(minutes: 10, seconds: 20)),
          ),
        });
        expect(second, hasLength(1));
      },
    );
  });

  group('Riverpod VisitedPlacesController & restart persistence', () {
    test(
      'records visit after dwell and preserves across container restarts',
      () async {
        final sharedRepo = _InMemoryVisitedRepository();
        final scanDataSource1 = _FakeBleScanDataSource();

        final container1 = ProviderContainer(
          overrides: [
            visitedPlacesRepositoryProvider.overrideWithValue(sharedRepo),
            visitedPlaceConfigProvider.overrideWithValue(
              const VisitedPlaceConfig(
                dwellDuration: Duration(seconds: 8),
                visitCooldown: Duration(minutes: 10),
              ),
            ),
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository(const [ankeruhr]),
            ),
            beaconRegistryDataSourceProvider.overrideWithValue(
              _FakeRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(
              _FakeBlePermissionService(),
            ),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource1),
            beaconProximityConfigProvider.overrideWithValue(
              const BeaconProximityConfig(emaAlpha: 1.0),
            ),
          ],
        );

        await container1.read(beaconRegistryProvider.future);
        await container1.read(poiCatalogueProvider.future);
        final visitedSub = container1.listen(visitedPlacesProvider, (_, _) {});
        await container1.read(visitedPlacesProvider.future);
        await container1
            .read(bleScanControllerProvider.notifier)
            .startScanning();

        final t0 = DateTime.utc(2026, 11, 21, 18, 0, 0);
        List<int> beaconPayload(int lastByte) => [
          0x01,
          0x01,
          0x56,
          0x49,
          0x45,
          0x00,
          0x00,
          0x00,
          0x00,
          lastByte,
        ];

        // Initial sighting -> does NOT mark visited yet.
        scanDataSource1.emit([
          BleRawScanResult(
            deviceId: 'AA:BB:CC:DD:EE:01',
            rssi: -60,
            serviceData: {
              PoiBeaconProtocolConstants.serviceUuid: beaconPayload(0x01),
            },
            serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
            localName: '',
            timestamp: t0,
          ),
        ]);
        await Future<void>.delayed(Duration.zero);
        expect(container1.read(visitedPlacesProvider).asData?.value, isEmpty);

        // Sustained proximity after 9s -> records visit.
        scanDataSource1.emit([
          BleRawScanResult(
            deviceId: 'AA:BB:CC:DD:EE:01',
            rssi: -59,
            serviceData: {
              PoiBeaconProtocolConstants.serviceUuid: beaconPayload(0x01),
            },
            serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
            localName: '',
            timestamp: t0.add(const Duration(seconds: 9)),
          ),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final recorded = container1.read(visitedPlacesProvider).asData!.value;
        expect(recorded, hasLength(1));
        expect(recorded.first.poiId, 'SEHENSWUERDIGOGD.643871');
        expect(recorded.first.visitCount, 1);

        visitedSub.close();
        container1.dispose();
        await scanDataSource1.dispose();

        // Simulate application restart with a fresh ProviderContainer reading same repo.
        final container2 = ProviderContainer(
          overrides: [
            visitedPlacesRepositoryProvider.overrideWithValue(sharedRepo),
          ],
        );
        addTearDown(container2.dispose);

        final reloaded = await container2.read(visitedPlacesProvider.future);
        expect(reloaded, hasLength(1));
        expect(reloaded.first.name, 'Ankeruhr');
        expect(reloaded.first.visitCount, 1);
      },
    );
  });

  group('Visited UI integration', () {
    testWidgets(
      'VisitedHistoryScreen displays visits and clears after confirmation',
      (tester) async {
        final repo = _InMemoryVisitedRepository();
        await repo.recordVisit(
          ankeruhr,
          visitedAt: DateTime.utc(2026, 11, 21, 14, 30),
          beaconId: '5649450000000001',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              visitedPlacesRepositoryProvider.overrideWithValue(repo),
            ],
            child: const MaterialApp(home: VisitedHistoryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ankeruhr'), findsOneWidget);
        expect(find.textContaining('Visited:'), findsOneWidget);

        await tester.tap(find.byTooltip('Clear history'));
        await tester.pumpAndSettle();
        expect(find.text('Clear visited history?'), findsOneWidget);

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();
        expect(find.text('No visited places yet'), findsOneWidget);
      },
    );

    testWidgets(
      'PoiListItem and SelectedPoiCard show Visited badge when visited',
      (tester) async {
        final visited = VisitedPlace(
          poiId: ankeruhr.id,
          name: ankeruhr.name,
          category: ankeruhr.category,
          address: ankeruhr.address,
          latitude: ankeruhr.latitude,
          longitude: ankeruhr.longitude,
          firstVisitedAt: DateTime.utc(2026, 11, 21, 12, 0),
          lastVisitedAt: DateTime.utc(2026, 11, 21, 12, 0),
          visitCount: 2,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  const PoiListItem(poi: ankeruhr, isVisited: true),
                  SelectedPoiCard(
                    poi: ankeruhr,
                    visitedPlace: visited,
                    onDismiss: () {},
                  ),
                ],
              ),
            ),
          ),
        );

        expect(find.text('Visited'), findsOneWidget);
        expect(find.text('Visited (2x)'), findsOneWidget);
      },
    );
  });
}
