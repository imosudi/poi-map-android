import '../../../poi/domain/entities/poi.dart';
import '../entities/visited_place.dart';

/// Persistence contract for visited Vienna POIs, independent of the beacon
/// registry and saved favourites.
abstract interface class VisitedPlacesRepository {
  /// Loads all recorded visited places ordered most recent first.
  Future<List<VisitedPlace>> loadVisitedPlaces();

  /// Records a validated visit for [poi] at [visitedAt] and persists
  /// immediately.
  Future<List<VisitedPlace>> recordVisit(
    Poi poi, {
    required DateTime visitedAt,
    String? beaconId,
  });

  /// Clears all persisted visited-place history.
  Future<List<VisitedPlace>> clearHistory();
}
