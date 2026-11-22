import 'dart:convert';

import '../../../core/errors/app_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../domain/beacon_registry_models.dart';
import '../domain/beacon_registry_repository.dart';
import 'beacon_registry_local_data_source.dart';

/// Local-storage-backed [BeaconRegistryRepository].
final class BeaconRegistryRepositoryImpl implements BeaconRegistryRepository {
  BeaconRegistryRepositoryImpl({
    required BeaconRegistryLocalDataSource dataSource,
    AppLogger? logger,
  }) : _dataSource = dataSource,
       _logger = logger;

  static const int currentSchemaVersion = 1;

  final BeaconRegistryLocalDataSource _dataSource;
  final AppLogger? _logger;

  @override
  Future<BeaconRegistry> loadRegistry() async {
    try {
      final persisted = await _dataSource.readPersistedJson();
      final rawJson = (persisted != null && persisted.trim().isNotEmpty)
          ? persisted
          : await _dataSource.readSeedAssetJson();
      return _decodeRegistry(rawJson);
    } on BeaconRegistryException {
      rethrow;
    } catch (error, stackTrace) {
      _logger?.error(
        'BeaconRegistry',
        'Failed to load beacon registry',
        error: error,
        stackTrace: stackTrace,
      );
      throw BeaconRegistryException(
        'Unable to load the local beacon registry.',
        cause: error,
      );
    }
  }

  @override
  Future<BeaconRegistry> saveRegistry(BeaconRegistry registry) async {
    try {
      final validated = BeaconRegistry.fromEntries(registry.entries);
      final encoded = _encodeRegistry(validated);
      await _dataSource.writePersistedJson(encoded);
      return validated;
    } on BeaconRegistryException {
      rethrow;
    } catch (error, stackTrace) {
      _logger?.error(
        'BeaconRegistry',
        'Failed to save beacon registry',
        error: error,
        stackTrace: stackTrace,
      );
      throw BeaconRegistryException(
        'Unable to save the local beacon registry.',
        cause: error,
      );
    }
  }

  @override
  Future<BeaconRegistry> upsertEntry(BeaconRegistryEntry entry) async {
    final current = await loadRegistry();
    final updated = current.withUpsertedEntry(entry);
    return saveRegistry(updated);
  }

  @override
  Future<BeaconRegistry> removeEntry(String beaconId) async {
    final current = await loadRegistry();
    final updated = current.withoutBeaconId(beaconId);
    return saveRegistry(updated);
  }

  @override
  Future<BeaconRegistryEntry?> resolveBeacon(String beaconId) async {
    final registry = await loadRegistry();
    return registry.findByBeaconId(beaconId);
  }

  @override
  Future<List<BeaconRegistryEntry>> getBeaconsForPoi(String poiId) async {
    final registry = await loadRegistry();
    return registry.findByPoiId(poiId);
  }

  BeaconRegistry _decodeRegistry(String rawJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawJson);
    } on FormatException catch (error) {
      throw BeaconRegistryException(
        'Beacon registry JSON is malformed.',
        cause: error,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const BeaconRegistryException(
        'Beacon registry root must be a JSON object.',
      );
    }

    final version = decoded['version'];
    if (version is! int || version != currentSchemaVersion) {
      throw BeaconRegistryException(
        'Unsupported beacon registry schema version: $version.',
      );
    }

    final rawBeacons = decoded['beacons'];
    if (rawBeacons is! List<dynamic>) {
      throw const BeaconRegistryException(
        'Beacon registry "beacons" field must be a JSON array.',
      );
    }

    final entries = <BeaconRegistryEntry>[];
    for (final item in rawBeacons) {
      if (item is! Map<String, dynamic>) {
        throw const BeaconRegistryException(
          'Each beacon registry entry must be a JSON object.',
        );
      }
      final beaconId = item['beaconId'];
      final poiId = item['poiId'];
      final poiName = item['poiName'];
      final label = item['label'];
      final enabled = item['enabled'];

      if (beaconId is! String || poiId is! String) {
        throw const BeaconRegistryException(
          'Beacon registry entries require string "beaconId" and "poiId" fields.',
        );
      }

      entries.add(
        BeaconRegistryEntry(
          beaconId: beaconId,
          poiId: poiId,
          poiName: poiName is String ? poiName : '',
          label: label is String ? label : '',
          enabled: enabled is bool ? enabled : true,
        ),
      );
    }

    return BeaconRegistry.fromEntries(entries);
  }

  String _encodeRegistry(BeaconRegistry registry) {
    return jsonEncode({
      'version': currentSchemaVersion,
      'beacons': [
        for (final entry in registry.entries)
          {
            'beaconId': entry.beaconId,
            'poiId': entry.poiId,
            if (entry.poiName.isNotEmpty) 'poiName': entry.poiName,
            'label': entry.label,
            'enabled': entry.enabled,
          },
      ],
    });
  }
}
