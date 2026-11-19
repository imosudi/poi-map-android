import '../../../poi/domain/entities/poi.dart';
import '../../domain/entities/saved_place.dart';
import '../../domain/repositories/favourites_repository.dart';
import '../datasources/favourites_local_storage.dart';

/// Local persistent implementation of [FavouritesRepository].
final class LocalFavouritesRepository implements FavouritesRepository {
  const LocalFavouritesRepository(this._storage);

  final FavouritesLocalStorage _storage;

  @override
  Future<List<SavedPlace>> loadSavedPlaces() {
    return _storage.readAll();
  }

  @override
  Future<bool> isSaved(String poiId) async {
    final places = await _storage.readAll();
    return places.any((place) => place.id == poiId);
  }

  @override
  Future<List<SavedPlace>> savePlace(Poi poi) async {
    final existing = await _storage.readAll();
    if (existing.any((place) => place.id == poi.id)) {
      return existing;
    }

    final updated = List<SavedPlace>.unmodifiable([
      SavedPlace.fromPoi(poi),
      ...existing,
    ]);
    await _storage.writeAll(updated);
    return updated;
  }
}
