import 'package:flutter/services.dart';

/// Checks whether the Android Google Maps API key is configured in manifest metadata.
final class MapConfigService {
  const MapConfigService();

  static const MethodChannel _channel = MethodChannel(
    'at.fhtw.poi_map_android/maps_config',
  );

  /// Returns `true` if a non-blank Google Maps API key is configured.
  ///
  /// Defaults to `true` when the platform channel is unavailable (e.g. in
  /// widget tests).
  Future<bool> isApiKeyConfigured() async {
    try {
      final configured = await _channel.invokeMethod<bool>(
        'isApiKeyConfigured',
      );
      return configured ?? false;
    } on MissingPluginException {
      return true;
    }
  }
}
