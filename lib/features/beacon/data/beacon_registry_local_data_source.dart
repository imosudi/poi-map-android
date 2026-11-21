import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local storage abstraction for the beacon-to-POI registry.
abstract interface class BeaconRegistryLocalDataSource {
  /// Reads persisted registry JSON if present, or `null` if not yet stored.
  Future<String?> readPersistedJson();

  /// Persists [rawJson] independently from visited/saved places persistence.
  Future<void> writePersistedJson(String rawJson);

  /// Reads the bundled seed registry JSON asset.
  Future<String> readSeedAssetJson();
}

/// [SharedPreferences] + [AssetBundle] implementation of
/// [BeaconRegistryLocalDataSource].
///
/// Uses key [storageKey] (`beacon_registry_v1`), separate from `saved_places_v1`.
final class SharedPreferencesBeaconRegistryDataSource
    implements BeaconRegistryLocalDataSource {
  SharedPreferencesBeaconRegistryDataSource({
    SharedPreferencesAsync? preferences,
    AssetBundle? assetBundle,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _assetBundle = assetBundle ?? rootBundle;

  static const String storageKey = 'beacon_registry_v1';
  static const String defaultAssetPath = 'assets/config/beacon_registry.json';

  final SharedPreferencesAsync _preferences;
  final AssetBundle _assetBundle;

  @override
  Future<String?> readPersistedJson() {
    return _preferences.getString(storageKey);
  }

  @override
  Future<void> writePersistedJson(String rawJson) {
    return _preferences.setString(storageKey, rawJson);
  }

  @override
  Future<String> readSeedAssetJson() {
    return _assetBundle.loadString(defaultAssetPath);
  }
}

