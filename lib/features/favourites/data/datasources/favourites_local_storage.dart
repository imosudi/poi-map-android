import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/saved_place.dart';
import '../models/saved_place_dto.dart';

/// Minimal key-value storage abstraction for testable local persistence.
abstract interface class KeyValueStorage {
  Future<String?> getString(String key);
  Future<bool> setString(String key, String value);
}

final class SharedPreferencesKeyValueStorage implements KeyValueStorage {
  SharedPreferencesKeyValueStorage({Future<SharedPreferences>? preferences})
    : _preferencesFuture = preferences ?? SharedPreferences.getInstance();

  final Future<SharedPreferences> _preferencesFuture;

  @override
  Future<String?> getString(String key) async {
    final prefs = await _preferencesFuture;
    return prefs.getString(key);
  }

  @override
  Future<bool> setString(String key, String value) async {
    final prefs = await _preferencesFuture;
    return prefs.setString(key, value);
  }
}

/// Persistent JSON-backed local storage for [SavedPlace] records.
final class FavouritesLocalStorage {
  FavouritesLocalStorage({KeyValueStorage? storage, AppLogger? logger})
    : _storage = storage ?? SharedPreferencesKeyValueStorage(),
      _logger = logger;

  static const String storageKey = 'saved_places_v1';

  final KeyValueStorage _storage;
  final AppLogger? _logger;

  Future<List<SavedPlace>> readAll() async {
    try {
      final raw = await _storage.getString(storageKey);
      if (raw == null || raw.trim().isEmpty) {
        return const [];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const SavedPlacesException('Saved places storage is corrupted.');
      }

      final seenIds = <String>{};
      final places = <SavedPlace>[];
      for (final item in decoded) {
        final place = SavedPlaceDto.tryFromJson(item);
        if (place != null && seenIds.add(place.id)) {
          places.add(place);
        }
      }
      return List.unmodifiable(places);
    } on SavedPlacesException {
      rethrow;
    } on FormatException catch (error, stackTrace) {
      _logger?.error(
        'FavouritesLocalStorage',
        'Failed to decode saved places JSON',
        error: error,
        stackTrace: stackTrace,
      );
      throw SavedPlacesException(
        'Unable to read saved places from device storage.',
        cause: error,
      );
    } catch (error, stackTrace) {
      _logger?.error(
        'FavouritesLocalStorage',
        'Failed to read saved places',
        error: error,
        stackTrace: stackTrace,
      );
      throw SavedPlacesException(
        'Unable to read saved places from device storage.',
        cause: error,
      );
    }
  }

  Future<void> writeAll(List<SavedPlace> places) async {
    try {
      final encoded = jsonEncode(
        places.map(SavedPlaceDto.toJson).toList(growable: false),
      );
      final ok = await _storage.setString(storageKey, encoded);
      if (!ok) {
        throw const SavedPlacesException(
          'Unable to save place to device storage.',
        );
      }
    } on SavedPlacesException {
      rethrow;
    } catch (error, stackTrace) {
      _logger?.error(
        'FavouritesLocalStorage',
        'Failed to write saved places',
        error: error,
        stackTrace: stackTrace,
      );
      throw SavedPlacesException(
        'Unable to save place to device storage.',
        cause: error,
      );
    }
  }
}
