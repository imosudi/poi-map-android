/// Decoded protocol flags from byte 1 of a POI-BEACON v1 Service Data payload.
final class PoiBeaconFlags {
  const PoiBeaconFlags(this.rawValue);

  /// Bitmask of valid flag bits in POI-BEACON v1 (bits 0 and 1).
  static const int validMask = 0x03;

  final int rawValue;

  bool get isProximityActive => (rawValue & 0x01) != 0;
  bool get isUsbPowered => (rawValue & 0x02) != 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PoiBeaconFlags && other.rawValue == rawValue;
  }

  @override
  int get hashCode => rawValue.hashCode;
}

/// Domain-level representation of a validated POI-BEACON advertisement.
final class PoiBeaconAdvertisement {
  const PoiBeaconAdvertisement({
    required this.protocolVersion,
    required this.flags,
    required this.beaconId,
    required this.beaconIdBytes,
    required this.deviceId,
    required this.rssi,
    required this.observedAt,
  });

  final int protocolVersion;
  final PoiBeaconFlags flags;

  /// Canonical 16-character lowercase hex identifier decoded from 8 bytes.
  final String beaconId;

  /// Unmodifiable 8-byte hardware beacon identifier in big-endian order.
  final List<int> beaconIdBytes;

  final String deviceId;
  final int rssi;
  final DateTime observedAt;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PoiBeaconAdvertisement &&
        other.protocolVersion == protocolVersion &&
        other.flags == flags &&
        other.beaconId == beaconId &&
        other.deviceId == deviceId &&
        other.rssi == rssi &&
        other.observedAt == observedAt;
  }

  @override
  int get hashCode =>
      Object.hash(protocolVersion, flags, beaconId, deviceId, rssi, observedAt);
}

/// Reason why a raw BLE advertisement was rejected by [PoiBeaconParser].
enum PoiBeaconRejectionReason {
  unrelatedAdvertisement,
  missingServiceUuid,
  invalidPayloadLength,
  invalidVersion,
  unsupportedVersion,
  invalidFlags,
  invalidBeaconId,
}

/// Deterministic outcome of parsing a raw BLE advertisement.
final class PoiBeaconParseResult {
  const PoiBeaconParseResult.valid(PoiBeaconAdvertisement this.advertisement)
    : rejectionReason = null;

  const PoiBeaconParseResult.rejected(
    PoiBeaconRejectionReason this.rejectionReason,
  ) : advertisement = null;

  final PoiBeaconAdvertisement? advertisement;
  final PoiBeaconRejectionReason? rejectionReason;

  bool get isValid => advertisement != null;
}
