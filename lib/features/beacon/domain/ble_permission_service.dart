import 'ble_scan_models.dart';

/// Platform abstraction for checking and requesting Android BLE permissions.
abstract interface class BlePermissionService {
  /// Returns the current BLE permission status without prompting the user.
  Future<BlePermissionStatus> checkPermission();

  /// Prompts the user for required Android BLE permissions when needed.
  Future<BlePermissionStatus> requestPermission();

  /// Opens the system application settings screen for manual permission recovery.
  Future<bool> openAppSettings();
}

