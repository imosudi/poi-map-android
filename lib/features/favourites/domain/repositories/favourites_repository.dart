import '../../../poi/domain/entities/poi.dart';
import '../entities/saved_place.dart';

/// Contract for persisting and retrieving saved Points of Interest.
abstract interface class FavouritesRepository {
  /// Loads all saved places from persistent storage.
  Future<List<SavedPlace>> loadSavedPlaces();

  /// Returns `true` if [poiId] is currently saved.
  Future<bool> isSaved(String poiId);

  /// Saves [poi] if not already present, persisting immediately and returning
  /// the updated list of saved places.
  Future<List<SavedPlace>> savePlace(Poi poi);
}
