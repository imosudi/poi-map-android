import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../domain/ble_scan_models.dart';

/// Data source abstraction over platform BLE scanning APIs.
abstract interface class BleScanDataSource {
  Stream<BleAdapterState> get adapterState;
  Stream<List<BleRawScanResult>> get scanResults;
  Stream<bool> get isScanning;
  bool get isScanningNow;

  Future<bool> isSupported();
  Future<BleAdapterState> getCurrentAdapterState();
  Future<void> startScan({
    required List<String> withServices,
    Duration? timeout,
  });
  Future<void> stopScan();
}

/// [FlutterBluePlus]-backed implementation of [BleScanDataSource].
final class FlutterBluePlusBleDataSource implements BleScanDataSource {
  const FlutterBluePlusBleDataSource();

  @override
  Stream<BleAdapterState> get adapterState =>
      FlutterBluePlus.adapterState.map(_mapAdapterState);

  @override
  Stream<List<BleRawScanResult>> get scanResults => FlutterBluePlus
      .onScanResults
      .map((results) => results.map(_mapScanResult).toList(growable: false));

  @override
  Stream<bool> get isScanning => FlutterBluePlus.isScanning;

  @override
  bool get isScanningNow => FlutterBluePlus.isScanningNow;

  @override
  Future<bool> isSupported() => FlutterBluePlus.isSupported;

  @override
  Future<BleAdapterState> getCurrentAdapterState() async {
    return _mapAdapterState(FlutterBluePlus.adapterStateNow);
  }

  @override
  Future<void> startScan({
    required List<String> withServices,
    Duration? timeout,
  }) {
    final serviceGuids = withServices
        .map((uuid) => Guid(uuid))
        .toList(growable: false);
    return FlutterBluePlus.startScan(
      withServices: serviceGuids,
      timeout: timeout,
      androidScanMode: AndroidScanMode.lowLatency,
    );
  }

  @override
  Future<void> stopScan() => FlutterBluePlus.stopScan();

  static BleAdapterState _mapAdapterState(BluetoothAdapterState state) {
    return switch (state) {
      BluetoothAdapterState.on => BleAdapterState.on,
      BluetoothAdapterState.off => BleAdapterState.off,
      BluetoothAdapterState.turningOn => BleAdapterState.unknown,
      BluetoothAdapterState.turningOff => BleAdapterState.off,
      BluetoothAdapterState.unavailable => BleAdapterState.unavailable,
      BluetoothAdapterState.unauthorized => BleAdapterState.unauthorized,
      BluetoothAdapterState.unknown => BleAdapterState.unknown,
    };
  }

  static BleRawScanResult _mapScanResult(ScanResult result) {
    final normalizedServiceData = <String, List<int>>{
      for (final entry in result.advertisementData.serviceData.entries)
        entry.key.str.toLowerCase(): List<int>.unmodifiable(entry.value),
    };
    final normalizedServiceUuids = result.advertisementData.serviceUuids
        .map((guid) => guid.str.toLowerCase())
        .toList(growable: false);

    return BleRawScanResult(
      deviceId: result.device.remoteId.str,
      rssi: result.rssi,
      serviceData: Map<String, List<int>>.unmodifiable(normalizedServiceData),
      serviceUuids: List<String>.unmodifiable(normalizedServiceUuids),
      localName: result.advertisementData.advName,
      timestamp: result.timeStamp,
    );
  }
}
