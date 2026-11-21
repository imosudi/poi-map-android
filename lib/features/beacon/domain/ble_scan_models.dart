/// Protocol constants for the project-defined POI-BEACON advertisement.
abstract final class PoiBeaconProtocolConstants {
  /// Project-generated 128-bit BLE Service UUID for POI-BEACON v1.
  static const String serviceUuid = '4a28ca13-0038-4846-9e65-eb29bda8dc87';
}

/// Runtime permission state for Android BLE scanning.
enum BlePermissionStatus { granted, denied, permanentlyDenied, unsupported }

/// Bluetooth adapter state observed from the host device.
enum BleAdapterState { unknown, on, off, unavailable, unauthorized }

/// Lifecycle status of the BLE scanning session.
enum BleScanSessionStatus {
  idle,
  scanning,
  permissionDenied,
  permissionPermanentlyDenied,
  bluetoothOff,
  unsupported,
  error,
}

/// Raw BLE advertisement sighting captured during a foreground scan.
final class BleRawScanResult {
  const BleRawScanResult({
    required this.deviceId,
    required this.rssi,
    required this.serviceData,
    required this.serviceUuids,
    required this.localName,
    required this.timestamp,
  });

  /// Platform device identifier (e.g., Android MAC / remoteId).
  final String deviceId;

  /// Received signal strength indicator in dBm.
  final int rssi;

  /// Raw BLE Service Data keyed by lowercase canonical UUID string.
  final Map<String, List<int>> serviceData;

  /// Advertised Service UUID strings normalised to lowercase.
  final List<String> serviceUuids;

  /// Optional advertised local name, empty if absent.
  final String localName;

  /// Timestamp when the advertisement frame was observed.
  final DateTime timestamp;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BleRawScanResult &&
        other.deviceId == deviceId &&
        other.rssi == rssi &&
        other.localName == localName &&
        other.timestamp == timestamp &&
        _listEquals(other.serviceUuids, serviceUuids) &&
        _mapEquals(other.serviceData, serviceData);
  }

  @override
  int get hashCode => Object.hash(
    deviceId,
    rssi,
    localName,
    timestamp,
    Object.hashAll(serviceUuids),
    Object.hashAll(
      serviceData.entries.map(
        (e) => Object.hash(e.key, Object.hashAll(e.value)),
      ),
    ),
  );
}

/// Immutable state exposed by the BLE scanning controller.
final class BleScanState {
  const BleScanState({
    this.status = BleScanSessionStatus.idle,
    this.adapterState = BleAdapterState.unknown,
    this.isTogglingBluetooth = false,
    this.resultsByDeviceId = const <String, BleRawScanResult>{},
    this.errorMessage,
  });

  final BleScanSessionStatus status;
  final BleAdapterState adapterState;
  final bool isTogglingBluetooth;
  final Map<String, BleRawScanResult> resultsByDeviceId;
  final String? errorMessage;

  bool get isScanning => status == BleScanSessionStatus.scanning;

  BleScanState copyWith({
    BleScanSessionStatus? status,
    BleAdapterState? adapterState,
    bool? isTogglingBluetooth,
    Map<String, BleRawScanResult>? resultsByDeviceId,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return BleScanState(
      status: status ?? this.status,
      adapterState: adapterState ?? this.adapterState,
      isTogglingBluetooth: isTogglingBluetooth ?? this.isTogglingBluetooth,
      resultsByDeviceId: resultsByDeviceId ?? this.resultsByDeviceId,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals(Map<String, List<int>> a, Map<String, List<int>> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final otherList = b[entry.key];
    if (otherList == null || !_listEquals(entry.value, otherList)) {
      return false;
    }
  }
  return true;
}
