import '../../poi/domain/entities/poi.dart';
import '../domain/entities/visited_place.dart';
import '../domain/repositories/visited_places_repository.dart';
import 'visited_places_local_storage.dart';

/// Local-storage-backed [VisitedPlacesRepository].
final class LocalVisitedPlacesRepository implements VisitedPlacesRepository {
  const LocalVisitedPlacesRepository(this._storage);

  final VisitedPlacesLocalStorage _storage;

  @override
  Future<List<VisitedPlace>> loadVisitedPlaces() => _storage.readAll();

  @override
  Future<List<VisitedPlace>> recordVisit(
    Poi poi, {
    required DateTime visitedAt,
    String? beaconId,
  }) async {
    final current = await _storage.readAll();
    final utcVisitedAt = visitedAt.toUtc();
    final updated = List<VisitedPlace>.from(current);
    final existingIndex = updated.indexWhere((e) => e.poiId == poi.id);

    if (existingIndex >= 0) {
      final existing = updated[existingIndex];
      updated[existingIndex] = existing.copyWith(
        lastVisitedAt: utcVisitedAt,
        visitCount: existing.visitCount + 1,
        lastBeaconId: beaconId,
      );
    } else {
      updated.add(
        VisitedPlace(
          poiId: poi.id,
          name: poi.name,
          category: poi.category,
          address: poi.address,
          latitude: poi.latitude,
          longitude: poi.longitude,
          firstVisitedAt: utcVisitedAt,
          lastVisitedAt: utcVisitedAt,
          visitCount: 1,
          lastBeaconId: beaconId,
        ),
      );
    }

    updated.sort((a, b) => b.lastVisitedAt.compareTo(a.lastVisitedAt));
    await _storage.writeAll(updated);
    return List<VisitedPlace>.unmodifiable(updated);
  }

  @override
  Future<List<VisitedPlace>> clearHistory() async {
    await _storage.clearAll();
    return const <VisitedPlace>[];
  }
}
