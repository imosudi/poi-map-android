import '../domain/ble_scan_models.dart';
import '../domain/poi_beacon_models.dart';

/// Parser for custom POI-BEACON BLE Service Data advertisements.
///
/// Validates the project-specific 128-bit Service UUID and decodes the
/// 10-byte v1 payload (`version` + `flags` + 8-byte `beaconId`).
final class PoiBeaconParser {
  const PoiBeaconParser();

  static const int expectedPayloadLength = 10;
  static const int supportedVersionV1 = 0x01;
  static const int beaconIdByteLength = 8;

  /// Parses a single [BleRawScanResult] deterministically.
  PoiBeaconParseResult parse(BleRawScanResult rawResult) {
    final targetUuid = PoiBeaconProtocolConstants.serviceUuid.toLowerCase();
    final payload = _findServiceData(rawResult.serviceData, targetUuid);

    if (payload == null) {
      final hasAnyServiceData = rawResult.serviceData.isNotEmpty;
      final hasProjectUuidListed = rawResult.serviceUuids.any(
        (uuid) => uuid.toLowerCase() == targetUuid,
      );
      if (hasAnyServiceData || !hasProjectUuidListed) {
        return const PoiBeaconParseResult.rejected(
          PoiBeaconRejectionReason.unrelatedAdvertisement,
        );
      }
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.missingServiceUuid,
      );
    }

    if (payload.length != expectedPayloadLength) {
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.invalidPayloadLength,
      );
    }

    final version = payload[0] & 0xFF;
    if (version == 0x00) {
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.invalidVersion,
      );
    }
    if (version != supportedVersionV1) {
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.unsupportedVersion,
      );
    }

    final flagsByte = payload[1] & 0xFF;
    if ((flagsByte & ~PoiBeaconFlags.validMask) != 0) {
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.invalidFlags,
      );
    }

    final beaconIdBytes = List<int>.unmodifiable(
      payload.sublist(2, 2 + beaconIdByteLength).map((b) => b & 0xFF),
    );
    if (_isAllSameByte(beaconIdBytes, 0x00) ||
        _isAllSameByte(beaconIdBytes, 0xFF)) {
      return const PoiBeaconParseResult.rejected(
        PoiBeaconRejectionReason.invalidBeaconId,
      );
    }

    final beaconId = _formatHex(beaconIdBytes);
    return PoiBeaconParseResult.valid(
      PoiBeaconAdvertisement(
        protocolVersion: version,
        flags: PoiBeaconFlags(flagsByte),
        beaconId: beaconId,
        beaconIdBytes: beaconIdBytes,
        deviceId: rawResult.deviceId,
        rssi: rawResult.rssi,
        observedAt: rawResult.timestamp,
      ),
    );
  }

  /// Parses a batch of raw scan results, returning only valid advertisements.
  List<PoiBeaconAdvertisement> parseAll(Iterable<BleRawScanResult> rawResults) {
    final valid = <PoiBeaconAdvertisement>[];
    for (final raw in rawResults) {
      final result = parse(raw);
      if (result.advertisement != null) {
        valid.add(result.advertisement!);
      }
    }
    return List<PoiBeaconAdvertisement>.unmodifiable(valid);
  }

  static List<int>? _findServiceData(
    Map<String, List<int>> serviceData,
    String targetUuid,
  ) {
    for (final entry in serviceData.entries) {
      if (entry.key.toLowerCase() == targetUuid) {
        return entry.value;
      }
    }
    return null;
  }

  static bool _isAllSameByte(List<int> bytes, int target) {
    for (final b in bytes) {
      if (b != target) return false;
    }
    return true;
  }

  static String _formatHex(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
