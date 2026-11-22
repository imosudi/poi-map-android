import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/beacon/data/beacon_registry_local_data_source.dart';
import 'package:poi_map_android/features/beacon/data/ble_scan_data_source.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_proximity_models.dart';
import 'package:poi_map_android/features/beacon/domain/ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_proximity_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_registry_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';
import 'package:poi_map_android/features/favourites/data/favourites_providers.dart';
import 'package:poi_map_android/features/favourites/domain/entities/saved_place.dart';
import 'package:poi_map_android/features/favourites/domain/repositories/favourites_repository.dart';
import 'package:poi_map_android/features/map/data/location_service.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';
import 'package:poi_map_android/features/poi/presentation/screens/poi_catalogue_screen.dart';
import 'package:poi_map_android/features/visited/domain/entities/visited_place.dart';
import 'package:poi_map_android/features/visited/domain/repositories/visited_places_repository.dart';
import 'package:poi_map_android/features/visited/presentation/providers/visited_places_provider.dart';

final class _E2eVisitedPlacesRepository implements VisitedPlacesRepository {
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

final class _E2ePoiRepository implements PoiRepository {
  _E2ePoiRepository(this.pois);
  final List<Poi> pois;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async => pois;
}

final class _E2eFavouritesRepository implements FavouritesRepository {
  @override
  Future<bool> isSaved(String poiId) async => false;

  @override
  Future<List<SavedPlace>> loadSavedPlaces() async => const <SavedPlace>[];

  @override
  Future<List<SavedPlace>> removePlace(String poiId) async =>
      const <SavedPlace>[];

  @override
  Future<List<SavedPlace>> savePlace(Poi poi) async => const <SavedPlace>[];
}

final class _E2eRegistryDataSource implements BeaconRegistryLocalDataSource {
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
      "label": "Ankeruhr - Main Square Beacon",
      "enabled": true
    },
    {
      "beaconId": "5649450000000003",
      "poiId": "SEHENSWUERDIGOGD.643872",
      "label": "Secondary Sight Beacon",
      "enabled": true
    }
  ]
}
''';

  @override
  Future<void> writePersistedJson(String rawJson) async {}
}

final class _E2eBlePermissionService implements BlePermissionService {
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

final class _E2eBleScanDataSource implements BleScanDataSource {
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<List<BleRawScanResult>> _resultsController =
      StreamController<List<BleRawScanResult>>.broadcast();
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();

  bool scanning = false;

  @override
  Stream<BleAdapterState> get adapterState => _adapterController.stream;

  @override
  Stream<bool> get isScanning => _scanningController.stream;

  @override
  bool get isScanningNow => scanning;

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
    scanning = true;
    _scanningController.add(true);
  }

  @override
  Future<void> stopScan() async {
    scanning = false;
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

final class _E2eLocationAdapter implements LocationPlatformAdapter {
  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.denied;

  @override
  Future<Position> getCurrentPosition() => throw UnimplementedError();

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;

  @override
  Future<LocationPermission> requestPermission() async =>
      LocationPermission.denied;
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
  const secondarySight = Poi(
    id: 'SEHENSWUERDIGOGD.643872',
    name: 'Peterskirche',
    category: 'Church',
    address: 'Petersplatz 1',
    latitude: 48.2092,
    longitude: 16.3702,
  );

  // Exact 10-byte Service Data payload broadcast by ESP32-S3-DevKitC-1
  // (proto=v1, flags=0x03 [proximityActive | usbPowered], beaconId=5649450000000001).
  const esp32AnkeruhrPayload = <int>[
    0x01,
    0x03,
    0x56,
    0x49,
    0x45,
    0x00,
    0x00,
    0x00,
    0x00,
    0x01,
  ];
  const secondaryBeaconPayload = <int>[
    0x01,
    0x03,
    0x56,
    0x49,
    0x45,
    0x00,
    0x00,
    0x00,
    0x00,
    0x03,
  ];
  const unknownRegisteredPayload = <int>[
    0x01,
    0x03,
    0x56,
    0x49,
    0x45,
    0x00,
    0x00,
    0x00,
    0x00,
    0x99,
  ];

  test(
    'End-to-end ESP32-S3 PDU -> Parser -> Registry -> Proximity hysteresis -> Visited persistence across restart',
    () async {
      final scanDataSource = _E2eBleScanDataSource();
      final visitedRepository = _E2eVisitedPlacesRepository();
      addTearDown(scanDataSource.dispose);

      buildOverrides() => [
        poiRepositoryProvider.overrideWithValue(
          _E2ePoiRepository(const [ankeruhr, secondarySight]),
        ),
        favouritesRepositoryProvider.overrideWithValue(
          _E2eFavouritesRepository(),
        ),
        beaconRegistryDataSourceProvider.overrideWithValue(
          _E2eRegistryDataSource(),
        ),
        blePermissionServiceProvider.overrideWithValue(
          _E2eBlePermissionService(),
        ),
        bleScanDataSourceProvider.overrideWithValue(scanDataSource),
        beaconProximityConfigProvider.overrideWithValue(
          const BeaconProximityConfig(emaAlpha: 0.5),
        ),
        visitedPlaceConfigProvider.overrideWithValue(
          const VisitedPlaceConfig(dwellDuration: Duration(seconds: 5)),
        ),
        visitedPlacesRepositoryProvider.overrideWithValue(visitedRepository),
      ];

      final container = ProviderContainer(overrides: buildOverrides());
      addTearDown(container.dispose);

      // Warm up POI catalogue, registry, proximity, and visited controllers.
      await container.read(poiCatalogueProvider.future);
      await container.read(beaconRegistryProvider.future);
      container.listen(beaconProximityProvider, (_, _) {});
      container.listen(visitedPlacesProvider, (_, _) {});
      await container.read(visitedPlacesProvider.future);

      await container.read(bleScanControllerProvider.notifier).startScanning();

      final t0 = DateTime.utc(2026, 11, 22, 0, 55, 0);
      scanDataSource.emit([
        // 1. Valid ESP32-S3 Ankeruhr beacon (strong RSSI -> inProximity).
        BleRawScanResult(
          deviceId: '94:A9:90:1C:78:14',
          rssi: -58,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: esp32AnkeruhrPayload,
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t0,
        ),
        // 2. Simultaneous secondary beacon (moderate RSSI -> nearby).
        BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:03',
          rssi: -76,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: secondaryBeaconPayload,
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t0,
        ),
        // 3. Unknown (unregistered) valid v1 beacon -> ignored for POI & visits.
        BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:99',
          rssi: -55,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: unknownRegisteredPayload,
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t0,
        ),
        // 4. Malformed / unrelated packets -> safely discarded.
        BleRawScanResult(
          deviceId: '11:22:33:44:55:66',
          rssi: -50,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: [0x01, 0x03, 0x56],
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t0,
        ),
        BleRawScanResult(
          deviceId: '11:22:33:44:55:77',
          rssi: -50,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: [
              0x01,
              0x80,
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
        BleRawScanResult(
          deviceId: '11:22:33:44:55:88',
          rssi: -50,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: [
              0x02,
              0x03,
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
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final proximity0 = container.read(beaconProximityProvider);
      expect(
        proximity0.recordsByBeaconId['5649450000000001']?.state,
        BeaconProximityState.inProximity,
      );
      expect(
        proximity0.recordsByBeaconId['5649450000000003']?.state,
        BeaconProximityState.nearby,
      );
      expect(proximity0.recordsByBeaconId['5649450000000099']?.poiId, isNull);

      // Dwell not yet reached -> no visit recorded.
      expect(container.read(visitedPlacesProvider).value, isEmpty);

      // Emit RSSI -70 after 6 seconds: EMA = 0.5*(-70) + 0.5*(-58) = -64 dBm.
      // Remains inProximity (hysteresis exit threshold is -72 dBm) and satisfies 5s dwell.
      final t1 = t0.add(const Duration(seconds: 6));
      scanDataSource.emit([
        BleRawScanResult(
          deviceId: '94:A9:90:1C:78:14',
          rssi: -70,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: esp32AnkeruhrPayload,
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t1,
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final visited = container.read(visitedPlacesProvider).value ?? const [];
      expect(visited.length, 1);
      expect(visited.single.poiId, ankeruhr.id);
      expect(visited.single.lastBeaconId, '5649450000000001');
      expect(visited.single.visitCount, 1);

      // Verify persistence across a full ProviderContainer restart.
      container.dispose();
      final restartedContainer = ProviderContainer(overrides: buildOverrides());
      addTearDown(restartedContainer.dispose);

      final persisted = await restartedContainer.read(
        visitedPlacesProvider.future,
      );
      expect(persisted.length, 1);
      expect(persisted.single.poiId, ankeruhr.id);
      expect(persisted.single.lastBeaconId, '5649450000000001');
    },
  );

  testWidgets(
    'End-to-end Explore and Map UI reflect ESP32-S3 flags=0x03 advertisement',
    (tester) async {
      final scanDataSource = _E2eBleScanDataSource();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapApiKeyConfiguredProvider.overrideWith((ref) async => true),
            poiRepositoryProvider.overrideWithValue(
              _E2ePoiRepository(const [ankeruhr, secondarySight]),
            ),
            favouritesRepositoryProvider.overrideWithValue(
              _E2eFavouritesRepository(),
            ),
            locationServiceProvider.overrideWithValue(
              LocationService(adapter: _E2eLocationAdapter()),
            ),
            beaconRegistryDataSourceProvider.overrideWithValue(
              _E2eRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(
              _E2eBlePermissionService(),
            ),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
            beaconProximityConfigProvider.overrideWithValue(
              const BeaconProximityConfig(emaAlpha: 1.0),
            ),
          ],
          child: MaterialApp(
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                body: TabBarView(
                  children: [
                    const PoiCatalogueScreen(),
                    MapScreen(
                      mapBuilder: (context, initialCamera, markers, onCreated) {
                        return const SizedBox.expand();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();

      scanDataSource.emit([
        BleRawScanResult(
          deviceId: '94:A9:90:1C:78:14',
          rssi: -59,
          serviceData: const {
            PoiBeaconProtocolConstants.serviceUuid: esp32AnkeruhrPayload,
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: DateTime.utc(2026, 11, 22, 0, 56, 0),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Nearby via beacon'), findsOneWidget);
      expect(find.text('Scanning • 1 nearby sight detected'), findsOneWidget);
      expect(find.text('In proximity (beacon)'), findsNWidgets(2));

      await scanDataSource.dispose();
    },
  );
}
