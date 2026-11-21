import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/beacon/data/beacon_registry_local_data_source.dart';
import 'package:poi_map_android/features/beacon/data/beacon_registry_repository_impl.dart';
import 'package:poi_map_android/features/beacon/data/ble_scan_data_source.dart';
import 'package:poi_map_android/features/beacon/data/poi_beacon_parser.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_poi_resolver.dart';
import 'package:poi_map_android/features/beacon/domain/beacon_registry_models.dart';
import 'package:poi_map_android/features/beacon/domain/ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/domain/poi_beacon_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/beacon_registry_provider.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';

final class _InMemoryBeaconRegistryDataSource
    implements BeaconRegistryLocalDataSource {
  _InMemoryBeaconRegistryDataSource({String? seedJson})
    : _seedJson = seedJson ?? _defaultSeedJson;

  static const String _defaultSeedJson = '''
{
  "version": 1,
  "beacons": [
    {
      "beaconId": "5649450000000001",
      "poiId": "SEHENSWUERDIGOGD.643871",
      "label": "Ankeruhr - Main Square",
      "enabled": true
    },
    {
      "beaconId": "5649450000000002",
      "poiId": "SEHENSWUERDIGOGD.643871",
      "label": "Ankeruhr - Arcade Entrance",
      "enabled": true
    }
  ]
}
''';

  final String _seedJson;
  String? persistedJson;

  @override
  Future<String?> readPersistedJson() async => persistedJson;

  @override
  Future<String> readSeedAssetJson() async => _seedJson;

  @override
  Future<void> writePersistedJson(String rawJson) async {
    persistedJson = rawJson;
  }
}

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this.pois);

  final List<Poi> pois;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    return pois;
  }
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

  void emitResults(List<BleRawScanResult> results) {
    _resultsController.add(results);
  }

  Future<void> dispose() async {
    await _adapterController.close();
    await _resultsController.close();
    await _scanningController.close();
  }
}

Poi _sampleAnkeruhrPoi() {
  return const Poi(
    id: 'SEHENSWUERDIGOGD.643871',
    name: 'Ankeruhr',
    category: 'Landmark',
    address: 'Hoher Markt 10/',
    latitude: 48.21076056,
    longitude: 16.37367575,
  );
}

void main() {
  group('BeaconRegistry validation & deduplication', () {
    test(
      'normalises valid beacon IDs and supports multiple beacons per POI',
      () {
        final registry = BeaconRegistry.fromEntries(const [
          BeaconRegistryEntry(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
            label: 'Main Square',
          ),
          BeaconRegistryEntry(
            beaconId: ' 5649450000000002 ',
            poiId: 'SEHENSWUERDIGOGD.643871',
            label: 'Arcade',
          ),
        ]);

        expect(registry.length, 2);
        expect(
          registry.findByBeaconId('5649450000000001')?.poiId,
          'SEHENSWUERDIGOGD.643871',
        );
        expect(registry.findByPoiId('SEHENSWUERDIGOGD.643871'), hasLength(2));
        expect(registry.findByBeaconId('9999999999999999'), isNull);
      },
    );

    test('prevents duplicate beacon IDs in registry', () {
      expect(
        () => BeaconRegistry.fromEntries(const [
          BeaconRegistryEntry(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643871',
          ),
          BeaconRegistryEntry(
            beaconId: '5649450000000001',
            poiId: 'SEHENSWUERDIGOGD.643872',
          ),
        ]),
        throwsA(isA<BeaconRegistryException>()),
      );
    });

    test('rejects invalid beacon IDs, sentinels, and empty POI IDs', () {
      for (final invalid in const [
        BeaconRegistryEntry(
          beaconId: 'short',
          poiId: 'SEHENSWUERDIGOGD.643871',
        ),
        BeaconRegistryEntry(
          beaconId: '0000000000000000',
          poiId: 'SEHENSWUERDIGOGD.643871',
        ),
        BeaconRegistryEntry(
          beaconId: 'ffffffffffffffff',
          poiId: 'SEHENSWUERDIGOGD.643871',
        ),
        BeaconRegistryEntry(beaconId: '5649450000000001', poiId: '   '),
      ]) {
        expect(
          () => BeaconRegistryValidator.validate(invalid),
          throwsA(isA<BeaconRegistryException>()),
        );
      }
    });
  });

  group('BeaconRegistryRepositoryImpl', () {
    test('loads seed registry and persists updates separately', () async {
      final dataSource = _InMemoryBeaconRegistryDataSource();
      final repo = BeaconRegistryRepositoryImpl(dataSource: dataSource);

      final initial = await repo.loadRegistry();
      expect(initial.length, 2);
      expect(
        (await repo.resolveBeacon('5649450000000001'))?.poiId,
        'SEHENSWUERDIGOGD.643871',
      );
      expect(await repo.resolveBeacon('0000000000000099'), isNull);

      // Update mapping without changing firmware protocol.
      await repo.upsertEntry(
        const BeaconRegistryEntry(
          beaconId: '5649450000000001',
          poiId: 'SEHENSWUERDIGOGD.999999',
          label: 'Relocated Beacon',
        ),
      );
      expect(dataSource.persistedJson, isNotNull);
      final decoded =
          jsonDecode(dataSource.persistedJson!) as Map<String, dynamic>;
      expect(decoded['version'], 1);

      final reloaded = await repo.loadRegistry();
      expect(
        reloaded.findByBeaconId('5649450000000001')?.poiId,
        'SEHENSWUERDIGOGD.999999',
      );

      await repo.removeEntry('5649450000000002');
      expect((await repo.loadRegistry()).length, 1);
    });

    test('throws BeaconRegistryException on malformed JSON', () async {
      final dataSource = _InMemoryBeaconRegistryDataSource(
        seedJson: '{invalid json',
      );
      final repo = BeaconRegistryRepositoryImpl(dataSource: dataSource);

      expect(
        () => repo.loadRegistry(),
        throwsA(isA<BeaconRegistryException>()),
      );
    });
  });

  group('End-to-end BLE -> Parser -> BeaconRegistry -> POI pipeline', () {
    test(
      'resolves POI-BEACON advertisement to Vienna OGD Poi entity via Riverpod',
      () async {
        final dataSource = _InMemoryBeaconRegistryDataSource();
        final scanDataSource = _FakeBleScanDataSource();
        final ankeruhr = _sampleAnkeruhrPoi();

        final container = ProviderContainer(
          overrides: [
            beaconRegistryDataSourceProvider.overrideWithValue(dataSource),
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository([ankeruhr]),
            ),
            blePermissionServiceProvider.overrideWithValue(
              _FakeBlePermissionService(),
            ),
            bleScanDataSourceProvider.overrideWithValue(scanDataSource),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await scanDataSource.dispose();
        });

        await container.read(beaconRegistryProvider.future);
        await container.read(poiCatalogueProvider.future);
        await container
            .read(bleScanControllerProvider.notifier)
            .startScanning();

        final resolvedSub = container.listen(
          resolvedBeaconPoisProvider,
          (_, _) {},
        );
        addTearDown(resolvedSub.close);

        // Emit valid POI-BEACON v1 frame for beacon 5649450000000001
        // and an unknown beacon frame 9999999999999999.
        scanDataSource.emitResults([
          BleRawScanResult(
            deviceId: 'AA:BB:CC:DD:EE:01',
            rssi: -57,
            serviceData: const {
              PoiBeaconProtocolConstants.serviceUuid: [
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
              ],
            },
            serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
            localName: '',
            timestamp: DateTime.utc(2026, 11, 21, 13, 0),
          ),
          BleRawScanResult(
            deviceId: 'AA:BB:CC:DD:EE:02',
            rssi: -68,
            serviceData: const {
              PoiBeaconProtocolConstants.serviceUuid: [
                0x01,
                0x01,
                0x99,
                0x99,
                0x99,
                0x99,
                0x99,
                0x99,
                0x99,
                0x99,
              ],
            },
            serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
            localName: '',
            timestamp: DateTime.utc(2026, 11, 21, 13, 0),
          ),
        ]);
        await Future<void>.delayed(Duration.zero);

        final resolved = container.read(resolvedBeaconPoisProvider);
        expect(resolved, hasLength(1));
        expect(resolved.first.advertisement.beaconId, '5649450000000001');
        expect(resolved.first.poi.id, 'SEHENSWUERDIGOGD.643871');
        expect(resolved.first.poi.name, 'Ankeruhr');
      },
    );

    test('BeaconPoiResolver reports poiNotFound when POI is absent', () {
      const resolver = BeaconPoiResolver();
      final registry = BeaconRegistry.fromEntries(const [
        BeaconRegistryEntry(
          beaconId: '5649450000000001',
          poiId: 'SEHENSWUERDIGOGD.643871',
        ),
      ]);

      final result = resolver.resolve(
        advertisement: _sampleAnkeruhrAdvertisement('5649450000000001'),
        registry: registry,
        poisById: const <String, Poi>{},
      );

      expect(result.status, BeaconResolutionStatus.poiNotFound);
      expect(result.registryEntry?.poiId, 'SEHENSWUERDIGOGD.643871');
    });
  });
}

PoiBeaconAdvertisement _sampleAnkeruhrAdvertisement(String beaconId) {
  return const PoiBeaconParser()
      .parse(
        BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -57,
          serviceData: {
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
          timestamp: DateTime.utc(2026, 11, 21, 13, 0),
        ),
      )
      .advertisement!;
}
