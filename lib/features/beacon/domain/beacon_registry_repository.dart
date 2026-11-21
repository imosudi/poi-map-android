import 'beacon_registry_models.dart';

/// Repository contract for managing the local beacon-to-POI mapping registry.
///
/// Stored independently from visited/saved places persistence so registry
/// mappings can be updated without changing beacon firmware.
abstract interface class BeaconRegistryRepository {
  /// Loads and validates the local beacon registry.
  Future<BeaconRegistry> loadRegistry();

  /// Persists the supplied [registry] to local storage.
  Future<BeaconRegistry> saveRegistry(BeaconRegistry registry);

  /// Inserts or updates a single [BeaconRegistryEntry] and persists the change.
  Future<BeaconRegistry> upsertEntry(BeaconRegistryEntry entry);

  /// Removes the mapping for [beaconId] if present and persists the change.
  Future<BeaconRegistry> removeEntry(String beaconId);

  /// Resolves a single [beaconId] to its registry entry, or `null` if unknown.
  Future<BeaconRegistryEntry?> resolveBeacon(String beaconId);

  /// Returns all registry entries associated with [poiId].
  Future<List<BeaconRegistryEntry>> getBeaconsForPoi(String poiId);
}

