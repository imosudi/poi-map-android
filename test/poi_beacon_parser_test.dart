import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/features/beacon/data/poi_beacon_parser.dart';
import 'package:poi_map_android/features/beacon/domain/ble_scan_models.dart';
import 'package:poi_map_android/features/beacon/domain/poi_beacon_models.dart';

List<int> _hexToBytes(String hex) {
  final result = <int>[];
  for (var i = 0; i < hex.length; i += 2) {
    result.add(int.parse(hex.substring(i, i + 2), radix: 16));
  }
  return result;
}

BleRawScanResult _rawResult({
  required String deviceId,
  required int rssi,
  Map<String, List<int>> serviceData = const <String, List<int>>{},
  List<String> serviceUuids = const <String>[],
  String localName = '',
}) {
  return BleRawScanResult(
    deviceId: deviceId,
    rssi: rssi,
    serviceData: serviceData,
    serviceUuids: serviceUuids,
    localName: localName,
    timestamp: DateTime.utc(2026, 11, 21, 12, 0),
  );
}

void main() {
  const parser = PoiBeaconParser();

  late Map<String, dynamic> fixtureDoc;
  late List<Map<String, dynamic>> vectors;

  setUpAll(() {
    final file = File('test/fixtures/poi_beacon_v1_fixtures.json');
    fixtureDoc = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    vectors = (fixtureDoc['vectors'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
  });

  group('PoiBeaconParser shared protocol fixtures', () {
    test('validates all shared ESP32-S3 / Flutter protocol vectors', () {
      for (final vector in vectors) {
        final name = vector['name'] as String;
        final uuid = vector['serviceUuid'] as String;
        final payload = _hexToBytes(vector['payloadHex'] as String);
        final raw = _rawResult(
          deviceId: 'AA:BB:CC:DD:EE:01',
          rssi: -58,
          serviceData: {uuid: payload},
          serviceUuids: [uuid],
        );

        final parsed = parser.parse(raw);
        final expectedValid = vector['expectedValid'] as bool;
        expect(parsed.isValid, expectedValid, reason: 'Vector: $name');

        if (expectedValid) {
          final adv = parsed.advertisement!;
          expect(adv.protocolVersion, vector['expectedVersion'], reason: name);
          expect(adv.flags.rawValue, vector['expectedFlags'], reason: name);
          expect(adv.beaconId, vector['expectedBeaconId'], reason: name);
        } else {
          expect(
            parsed.rejectionReason?.name,
            vector['expectedRejection'],
            reason: 'Vector: $name',
          );
        }
      }
    });
  });

  group('PoiBeaconParser explicit cases', () {
    test('parses valid version 1 advertisement deterministically', () {
      final raw = _rawResult(
        deviceId: '11:22:33:44:55:66',
        rssi: -61,
        serviceData: {
          PoiBeaconProtocolConstants.serviceUuid.toUpperCase(): _hexToBytes(
            '0103a1b2c3d4e5f60708',
          ),
        },
        serviceUuids: const [PoiBeaconProtocolConstants.serviceUuid],
      );

      final first = parser.parse(raw);
      final second = parser.parse(raw);

      expect(first.isValid, isTrue);
      expect(first.advertisement, equals(second.advertisement));
      expect(first.advertisement!.protocolVersion, 1);
      expect(first.advertisement!.flags.isProximityActive, isTrue);
      expect(first.advertisement!.flags.isUsbPowered, isTrue);
      expect(first.advertisement!.beaconId, 'a1b2c3d4e5f60708');
      expect(first.advertisement!.rssi, -61);
    });

    test('rejects incorrect service UUID', () {
      final raw = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:02',
        rssi: -70,
        serviceData: {
          '0000feaa-0000-1000-8000-00805f9b34fb': _hexToBytes(
            '01010000000000000001',
          ),
        },
      );

      final result = parser.parse(raw);
      expect(result.isValid, isFalse);
      expect(
        result.rejectionReason,
        PoiBeaconRejectionReason.unrelatedAdvertisement,
      );
    });

    test('rejects invalid payload length and truncated data', () {
      final truncated = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:03',
        rssi: -70,
        serviceData: {
          PoiBeaconProtocolConstants.serviceUuid: _hexToBytes('01010000'),
        },
      );
      final oversized = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:04',
        rssi: -70,
        serviceData: {
          PoiBeaconProtocolConstants.serviceUuid: _hexToBytes(
            '0101000000000000000199',
          ),
        },
      );

      expect(
        parser.parse(truncated).rejectionReason,
        PoiBeaconRejectionReason.invalidPayloadLength,
      );
      expect(
        parser.parse(oversized).rejectionReason,
        PoiBeaconRejectionReason.invalidPayloadLength,
      );
    });

    test('rejects unsupported protocol versions safely', () {
      final v2 = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:05',
        rssi: -64,
        serviceData: {
          PoiBeaconProtocolConstants.serviceUuid: _hexToBytes(
            '02010000000000000001',
          ),
        },
      );

      final result = parser.parse(v2);
      expect(result.isValid, isFalse);
      expect(
        result.rejectionReason,
        PoiBeaconRejectionReason.unsupportedVersion,
      );
    });

    test('rejects invalid flags with reserved bits set', () {
      final invalidFlags = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:06',
        rssi: -64,
        serviceData: {
          PoiBeaconProtocolConstants.serviceUuid: _hexToBytes(
            '01040000000000000001',
          ),
        },
      );

      final result = parser.parse(invalidFlags);
      expect(result.isValid, isFalse);
      expect(result.rejectionReason, PoiBeaconRejectionReason.invalidFlags);
    });

    test('rejects unrelated BLE advertisements with no service data', () {
      final unrelated = _rawResult(
        deviceId: 'AA:BB:CC:DD:EE:07',
        rssi: -80,
        localName: 'Headphones',
      );

      final result = parser.parse(unrelated);
      expect(result.isValid, isFalse);
      expect(
        result.rejectionReason,
        PoiBeaconRejectionReason.unrelatedAdvertisement,
      );
    });

    test(
      'parses multiple valid beacon advertisements while filtering noise',
      () {
        final batch = <BleRawScanResult>[
          _rawResult(
            deviceId: 'DE:AD:BE:EF:00:01',
            rssi: -55,
            serviceData: {
              PoiBeaconProtocolConstants.serviceUuid: _hexToBytes(
                '01010000000000000001',
              ),
            },
          ),
          _rawResult(
            deviceId: 'DE:AD:BE:EF:00:02',
            rssi: -72,
            localName: 'RandomWatch',
          ),
          _rawResult(
            deviceId: 'DE:AD:BE:EF:00:03',
            rssi: -63,
            serviceData: {
              PoiBeaconProtocolConstants.serviceUuid: _hexToBytes(
                '01020000000000000002',
              ),
            },
          ),
        ];

        final parsed = parser.parseAll(batch);
        expect(parsed, hasLength(2));
        expect(parsed[0].beaconId, '0000000000000001');
        expect(parsed[1].beaconId, '0000000000000002');
      },
    );
  });
}
