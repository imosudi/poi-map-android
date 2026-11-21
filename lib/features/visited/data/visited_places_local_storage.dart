import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../domain/entities/visited_place.dart';

/// Persistent local storage for visited places using `SharedPreferences`
/// under [storageKey] (`visited_places_v1`), independent of the beacon registry.
final class VisitedPlacesLocalStorage {
  VisitedPlacesLocalStorage({
    SharedPreferencesAsync? preferences,
    AppLogger? logger,
  }) : _preferences = preferences ?? SharedPreferencesAsync(),
       _logger = logger;

  static const String storageKey = 'visited_places_v1';

  final SharedPreferencesAsync _preferences;
  final AppLogger? _logger;

  Future<List<VisitedPlace>> readAll() async {
    try {
      final rawJson = await _preferences.getString(storageKey);
      if (rawJson == null || rawJson.trim().isEmpty) {
        return const <VisitedPlace>[];
      }
      final decoded = jsonDecode(rawJson);
      if (decoded is! List<dynamic>) {
        throw const VisitedPlacesException('Visited places data is corrupted.');
      }
      final results = <VisitedPlace>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final parsed = _fromJson(item);
          if (parsed != null) {
            results.add(parsed);
          }
        }
      }
      results.sort((a, b) => b.lastVisitedAt.compareTo(a.lastVisitedAt));
      return List<VisitedPlace>.unmodifiable(results);
    } on VisitedPlacesException {
      rethrow;
    } catch (error, stackTrace) {
      _logger?.error(
        'VisitedPlaces',
        'Failed to read visited places',
        error: error,
        stackTrace: stackTrace,
      );
      throw VisitedPlacesException(
        'Unable to load visited places history.',
        cause: error,
      );
    }
  }

  Future<void> writeAll(List<VisitedPlace> places) async {
    try {
      final payload = jsonEncode([for (final p in places) _toJson(p)]);
      await _preferences.setString(storageKey, payload);
    } catch (error, stackTrace) {
      _logger?.error(
        'VisitedPlaces',
        'Failed to write visited places',
        error: error,
        stackTrace: stackTrace,
      );
      throw VisitedPlacesException(
        'Unable to save visited place.',
        cause: error,
      );
    }
  }

  Future<void> clearAll() async {
    try {
      await _preferences.remove(storageKey);
    } catch (error, stackTrace) {
      _logger?.error(
        'VisitedPlaces',
        'Failed to clear visited places',
        error: error,
        stackTrace: stackTrace,
      );
      throw VisitedPlacesException(
        'Unable to clear visited places history.',
        cause: error,
      );
    }
  }

  static VisitedPlace? _fromJson(Map<String, dynamic> json) {
    final poiId = json['poiId'];
    final name = json['name'];
    final lat = json['latitude'];
    final lon = json['longitude'];
    final firstAtRaw = json['firstVisitedAt'];
    final lastAtRaw = json['lastVisitedAt'];

    if (poiId is! String ||
        name is! String ||
        lat is! num ||
        lon is! num ||
        firstAtRaw is! String ||
        lastAtRaw is! String) {
      return null;
    }

    final firstAt = DateTime.tryParse(firstAtRaw);
    final lastAt = DateTime.tryParse(lastAtRaw);
    if (firstAt == null || lastAt == null) return null;

    final visitCount = json['visitCount'];
    return VisitedPlace(
      poiId: poiId,
      name: name,
      category: json['category'] is String ? json['category'] as String : null,
      address: json['address'] is String ? json['address'] as String : null,
      latitude: lat.toDouble(),
      longitude: lon.toDouble(),
      firstVisitedAt: firstAt.toUtc(),
      lastVisitedAt: lastAt.toUtc(),
      visitCount: visitCount is int && visitCount > 0 ? visitCount : 1,
      lastBeaconId: json['lastBeaconId'] is String
          ? json['lastBeaconId'] as String
          : null,
    );
  }

  static Map<String, Object?> _toJson(VisitedPlace place) {
    return {
      'poiId': place.poiId,
      'name': place.name,
      'category': place.category,
      'address': place.address,
      'latitude': place.latitude,
      'longitude': place.longitude,
      'firstVisitedAt': place.firstVisitedAt.toUtc().toIso8601String(),
      'lastVisitedAt': place.lastVisitedAt.toUtc().toIso8601String(),
      'visitCount': place.visitCount,
      'lastBeaconId': place.lastBeaconId,
    };
  }
}
