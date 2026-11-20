import 'ble_scan_models.dart';

/// Repository contract for managing foreground BLE scanning sessions.
abstract interface class BleScanningRepository {
  /// Emits updates to the device's Bluetooth adapter state.
  Stream<BleAdapterState> get adapterStateStream;

  /// Emits discovered raw BLE scan results matching the configured service filter.
  Stream<List<BleRawScanResult>> get scanResultsStream;

  /// Emits whether a BLE scan is currently active.
  Stream<bool> get isScanningStream;

  /// Checks whether the platform supports BLE scanning.
  Future<bool> isSupported();

  /// Checks whether Bluetooth is currently powered on.
  Future<bool> isBluetoothEnabled();

  /// Checks current BLE runtime permissions without prompting.
  Future<BlePermissionStatus> checkPermission();

  /// Requests BLE runtime permissions when needed.
  Future<BlePermissionStatus> requestPermission();

  /// Opens the application settings screen to grant permanently denied permissions.
  Future<bool> openAppSettings();

  /// Starts a foreground BLE scan filtered to [PoiBeaconProtocolConstants.serviceUuid].
  ///
  /// Duplicate concurrent calls are coalesced so only one scan runs at a time.
  Future<void> startForegroundScan({Duration? timeout});

  /// Stops the active BLE scan if one is running.
  Future<void> stopScan();

  /// Releases subscriptions and underlying resources.
  Future<void> dispose();
}

