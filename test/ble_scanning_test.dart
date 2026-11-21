import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/features/beacon/data/android_ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/data/ble_scan_data_source.dart';
import 'package:poi_map_android/features/beacon/data/ble_scanning_repository_impl.dart';
import 'package:poi_map_android/features/beacon/domain/ble_permission_service.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/presentation/providers/ble_scan_provider.dart';

final class _FakeBlePermissionService implements BlePermissionService {
  BlePermissionStatus checkStatus = BlePermissionStatus.granted;
  BlePermissionStatus requestStatus = BlePermissionStatus.granted;
  int requestCalls = 0;
  int openSettingsCalls = 0;
  int openBluetoothSettingsCalls = 0;

  @override
  Future<BlePermissionStatus> checkPermission() async => checkStatus;

  @override
  Future<BlePermissionStatus> requestPermission() async {
    requestCalls++;
    return requestStatus;
  }

  @override
  Future<bool> openAppSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<bool> openBluetoothSettings() async {
    openBluetoothSettingsCalls++;
    return true;
  }
}

final class _FakeBleScanDataSource implements BleScanDataSource {
  final StreamController<BleAdapterState> adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<List<BleRawScanResult>> resultsController =
      StreamController<List<BleRawScanResult>>.broadcast();
  final StreamController<bool> scanningController =
      StreamController<bool>.broadcast();

  bool supported = true;
  BleAdapterState currentAdapterState = BleAdapterState.on;
  bool scanning = false;
  int startScanCalls = 0;
  int stopScanCalls = 0;
  int turnOnCalls = 0;
  List<String> lastServiceFilter = const <String>[];
  Object? startScanError;
  Duration? startScanDelay;

  @override
  Stream<BleAdapterState> get adapterState => adapterController.stream;

  @override
  Stream<List<BleRawScanResult>> get scanResults => resultsController.stream;

  @override
  Stream<bool> get isScanning => scanningController.stream;

  @override
  bool get isScanningNow => scanning;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<BleAdapterState> getCurrentAdapterState() async => currentAdapterState;

  @override
  Future<void> turnOnBluetooth() async {
    turnOnCalls++;
    currentAdapterState = BleAdapterState.on;
    adapterController.add(BleAdapterState.on);
  }

  @override
  Future<void> startScan({
    required List<String> withServices,
    Duration? timeout,
  }) async {
    startScanCalls++;
    lastServiceFilter = withServices;
    if (startScanDelay != null) {
      await Future<void>.delayed(startScanDelay!);
    }
    if (startScanError != null) {
      throw startScanError!;
    }
    scanning = true;
    scanningController.add(true);
  }

  @override
  Future<void> stopScan() async {
    stopScanCalls++;
    scanning = false;
    scanningController.add(false);
  }

  Future<void> dispose() async {
    await adapterController.close();
    await resultsController.close();
    await scanningController.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MethodChannelBlePermissionService', () {
    const channel = MethodChannel('at.fhtw.poi_map_android/ble_permissions');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('maps granted, denied, and permanentlyDenied statuses', () async {
      var nextResult = 'granted';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'checkBlePermissions') return nextResult;
            if (call.method == 'requestBlePermissions') return nextResult;
            if (call.method == 'openAppSettings') return true;
            return null;
          });

      final service = MethodChannelBlePermissionService();
      expect(await service.checkPermission(), BlePermissionStatus.granted);

      nextResult = 'denied';
      expect(await service.checkPermission(), BlePermissionStatus.denied);

      nextResult = 'permanentlyDenied';
      expect(
        await service.requestPermission(),
        BlePermissionStatus.permanentlyDenied,
      );
      expect(await service.openAppSettings(), isTrue);
    });
  });

  group('BleScanningRepositoryImpl & BleScanController', () {
    late _FakeBlePermissionService permissionService;
    late _FakeBleScanDataSource dataSource;
    late ProviderContainer container;

    setUp(() {
      permissionService = _FakeBlePermissionService();
      dataSource = _FakeBleScanDataSource();
      container = ProviderContainer(
        overrides: [
          blePermissionServiceProvider.overrideWithValue(permissionService),
          bleScanDataSourceProvider.overrideWithValue(dataSource),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await dataSource.dispose();
    });

    test(
      'starts foreground scan with POI-BEACON UUID and exposes sightings',
      () async {
        final controller = container.read(bleScanControllerProvider.notifier);
        await controller.startScanning();

        final state = container.read(bleScanControllerProvider);
        expect(state.status, BleScanSessionStatus.scanning);
        expect(state.isScanning, isTrue);
        expect(dataSource.lastServiceFilter, const [
          PoiBeaconProtocolConstants.serviceUuid,
        ]);

        final sighting = BleRawScanResult(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          rssi: -62,
          serviceData: {
            PoiBeaconProtocolConstants.serviceUuid: [
              0x01,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x00,
              0x01,
              0xC5,
            ],
          },
          serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
          localName: '',
          timestamp: DateTime.utc(2026, 11, 20),
        );
        dataSource.resultsController.add([sighting]);
        await Future<void>.delayed(Duration.zero);

        final results = container.read(bleScanResultsProvider);
        expect(results, hasLength(1));
        expect(results.first.deviceId, 'AA:BB:CC:DD:EE:FF');
        expect(results.first.rssi, -62);
        expect(
          results.first.serviceData[PoiBeaconProtocolConstants.serviceUuid],
          hasLength(10),
        );

        await controller.stopScanning();
        expect(dataSource.stopScanCalls, 1);
        expect(
          container.read(bleScanControllerProvider).status,
          BleScanSessionStatus.idle,
        );
      },
    );

    test('prevents duplicate concurrent scanning sessions', () async {
      dataSource.startScanDelay = const Duration(milliseconds: 20);
      final controller = container.read(bleScanControllerProvider.notifier);

      await Future.wait([
        controller.startScanning(),
        controller.startScanning(),
      ]);
      // Calling again while already scanning should also be a no-op.
      await controller.startScanning();

      expect(dataSource.startScanCalls, 1);
    });

    test('handles permission denied and permanently denied states', () async {
      permissionService.checkStatus = BlePermissionStatus.denied;
      permissionService.requestStatus = BlePermissionStatus.denied;

      final controller = container.read(bleScanControllerProvider.notifier);
      await controller.startScanning();

      expect(permissionService.requestCalls, 1);
      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.permissionDenied,
      );
      expect(dataSource.startScanCalls, 0);

      permissionService.requestStatus = BlePermissionStatus.permanentlyDenied;
      await controller.startScanning();

      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.permissionPermanentlyDenied,
      );
      expect(await controller.openAppSettings(), isTrue);
      expect(permissionService.openSettingsCalls, 1);
    });

    test('handles Bluetooth disabled and mid-scan adapter off', () async {
      dataSource.currentAdapterState = BleAdapterState.off;
      final controller = container.read(bleScanControllerProvider.notifier);

      await controller.startScanning();
      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.bluetoothOff,
      );
      expect(dataSource.startScanCalls, 0);

      dataSource.currentAdapterState = BleAdapterState.on;
      await controller.startScanning();
      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.scanning,
      );

      dataSource.adapterController.add(BleAdapterState.off);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(bleScanControllerProvider).status,
        BleScanSessionStatus.bluetoothOff,
      );
    });

    test('maps data source failures to error state cleanly', () async {
      dataSource.startScanError = PlatformException(
        code: 'BLE_FAIL',
        message: 'Adapter busy',
      );
      final controller = container.read(bleScanControllerProvider.notifier);

      await controller.startScanning();
      final state = container.read(bleScanControllerProvider);
      expect(state.status, BleScanSessionStatus.error);
      expect(state.errorMessage, 'Adapter busy');
    });

    test('repository throws BleException when disposed', () async {
      final repo = BleScanningRepositoryImpl(
        dataSource: dataSource,
        permissionService: permissionService,
      );
      await repo.dispose();

      expect(() => repo.startForegroundScan(), throwsA(isA<BleException>()));
    });
  });
}
