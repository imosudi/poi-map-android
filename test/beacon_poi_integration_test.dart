import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
import 'package:poi_map_android/features/map/presentation/mappers/poi_marker_builder.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/screens/poi_catalogue_screen.dart';

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this.pois);
  final List<Poi> pois;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async => pois;
}

final class _FakeFavouritesRepository implements FavouritesRepository {
  final List<SavedPlace> _items = <SavedPlace>[];

  @override
  Future<List<SavedPlace>> loadSavedPlaces() async => List.of(_items);

  @override
  Future<bool> isSaved(String poiId) async => _items.any((e) => e.id == poiId);

  @override
  Future<List<SavedPlace>> savePlace(Poi poi) async {
    if (!_items.any((e) => e.id == poi.id)) {
      _items.add(SavedPlace.fromPoi(poi, savedAt: DateTime.utc(2026, 11, 21)));
    }
    return List.of(_items);
  }

  @override
  Future<List<SavedPlace>> removePlace(String poiId) async {
    _items.removeWhere((e) => e.id == poiId);
    return List.of(_items);
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

final class _FakeBlePermissionService implements BlePermissionService {
  BlePermissionStatus status = BlePermissionStatus.granted;

  @override
  Future<BlePermissionStatus> checkPermission() async => status;

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<BlePermissionStatus> requestPermission() async => status;
}

final class _FakeBleScanDataSource implements BleScanDataSource {
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<List<BleRawScanResult>> _resultsController =
      StreamController<List<BleRawScanResult>>.broadcast();
  final StreamController<bool> _scanningController =
      StreamController<bool>.broadcast();

  bool supported = true;
  BleAdapterState adapter = BleAdapterState.on;
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
  Future<BleAdapterState> getCurrentAdapterState() async => adapter;

  @override
  Future<bool> isSupported() async => supported;

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

  void emit(List<BleRawScanResult> results) => _resultsController.add(results);

  Future<void> dispose() async {
    await _adapterController.close();
    await _resultsController.close();
    await _scanningController.close();
  }
}

final class _FakeLocationAdapter implements LocationPlatformAdapter {
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

  testWidgets(
    'Explore shows user-controlled BLE scan, deduplicates multi-beacon POI, and renders qualitative proximity badge',
    (tester) async {
      final scanDataSource = _FakeBleScanDataSource();
      final permissionService = _FakeBlePermissionService();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository(const [ankeruhr]),
            ),
            favouritesRepositoryProvider.overrideWithValue(
              _FakeFavouritesRepository(),
            ),
            beaconRegistryDataSourceProvider.overrideWithValue(
              _FakeRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(permissionService),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
            beaconProximityConfigProvider.overrideWithValue(
              const BeaconProximityConfig(emaAlpha: 1.0),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PoiCatalogueScreen())),
        ),
      );
      await tester.pumpAndSettle();

      // User starts scanning via status bar.
      expect(find.text('Scan'), findsOneWidget);
      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(find.text('Stop'), findsOneWidget);

      // Emit two beacons mapped to the SAME POI (SEHENSWUERDIGOGD.643871).
      final t0 = DateTime.utc(2026, 11, 21, 20, 0, 0);
      scanDataSource.emit([
        BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -60,
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
        BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:02',
          rssi: -76,
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
              0x02,
            ],
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: t0,
        ),
      ]);
      await tester.pumpAndSettle();

      // Nearby via beacon section shows 1 deduplicated sight (not 2).
      expect(find.text('Nearby via beacon'), findsOneWidget);
      expect(find.text('Scanning • 1 nearby sight detected'), findsOneWidget);
      expect(find.text('In proximity (beacon)'), findsNWidgets(2));

      // User stops scanning.
      await tester.tap(find.text('Stop'));
      await tester.pumpAndSettle();
      expect(find.text('Scan'), findsOneWidget);

      await scanDataSource.dispose();
    },
  );

  testWidgets(
    'Explore displays clear states for permission-denied, Bluetooth-off, and unsupported BLE',
    (tester) async {
      final scanDataSource = _FakeBleScanDataSource();
      final permissionService = _FakeBlePermissionService()
        ..status = BlePermissionStatus.denied;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository(const [ankeruhr]),
            ),
            favouritesRepositoryProvider.overrideWithValue(
              _FakeFavouritesRepository(),
            ),
            beaconRegistryDataSourceProvider.overrideWithValue(
              _FakeRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(permissionService),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
          ],
          child: const MaterialApp(home: Scaffold(body: PoiCatalogueScreen())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scan'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bluetooth permission is needed to detect nearby beacons.'),
        findsOneWidget,
      );
      expect(find.text('Allow'), findsOneWidget);

      // Now grant permission, but Bluetooth is off.
      permissionService.status = BlePermissionStatus.granted;
      scanDataSource.adapter = BleAdapterState.off;
      await tester.tap(find.text('Allow'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Bluetooth is turned off. Enable Bluetooth to scan for beacons.',
        ),
        findsOneWidget,
      );

      // Now BLE unsupported.
      scanDataSource.supported = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(
        find.text('BLE beacon discovery is unavailable on this device.'),
        findsOneWidget,
      );

      await scanDataSource.dispose();
    },
  );

  testWidgets(
    'Map highlights detected beacon POIs and shows qualitative proximity on SelectedPoiCard',
    (tester) async {
      final scanDataSource = _FakeBleScanDataSource();
      final permissionService = _FakeBlePermissionService();
      Set<Marker> capturedMarkers = const <Marker>{};

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapApiKeyConfiguredProvider.overrideWith((ref) async => true),
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository(const [ankeruhr]),
            ),
            favouritesRepositoryProvider.overrideWithValue(
              _FakeFavouritesRepository(),
            ),
            locationServiceProvider.overrideWithValue(
              LocationService(adapter: _FakeLocationAdapter()),
            ),
            beaconRegistryDataSourceProvider.overrideWithValue(
              _FakeRegistryDataSource(),
            ),
            blePermissionServiceProvider.overrideWithValue(permissionService),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
            beaconProximityConfigProvider.overrideWithValue(
              const BeaconProximityConfig(emaAlpha: 1.0),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MapScreen(
                mapBuilder: (context, initialCamera, markers, onMapCreated) {
                  capturedMarkers = markers;
                  return const SizedBox.expand();
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Scan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

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
          timestamp: DateTime.utc(2026, 11, 21, 20, 5, 0),
        ),
      ]);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final marker = capturedMarkers.firstWhere(
        (m) => m.markerId.value == ankeruhr.id,
      );
      expect(marker.zIndexInt, 1);
      expect(marker.infoWindow.snippet, contains('Nearby via beacon'));

      // Tap marker callback to open SelectedPoiCard and verify proximity badge.
      marker.onTap?.call();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Ankeruhr'), findsOneWidget);
      expect(find.text('In proximity (beacon)'), findsOneWidget);

      await scanDataSource.dispose();
    },
  );

  test(
    'PoiMarkerBuilder highlights nearby beacon POIs with elevated zIndex',
    () {
      const poi = ankeruhr;
      final markers = PoiMarkerBuilder.build(
        pois: const [poi],
        nearbyBeaconPoiIds: const {'SEHENSWUERDIGOGD.643871'},
      );
      expect(markers.single.zIndexInt, 1);
      expect(
        markers.single.infoWindow.snippet,
        'Hoher Markt 10/ • Nearby via beacon',
      );
    },
  );
}
