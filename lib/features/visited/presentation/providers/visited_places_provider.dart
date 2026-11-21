import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../beacon/presentation/providers/beacon_proximity_provider.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../data/local_visited_places_repository.dart';
import '../../data/visited_places_local_storage.dart';
import '../../domain/entities/visited_place.dart';
import '../../domain/repositories/visited_places_repository.dart';
import '../../domain/services/visit_dwell_evaluator.dart';

/// Configurable dwell duration and cooldown for recording POI visits.
final visitedPlaceConfigProvider = Provider<VisitedPlaceConfig>((ref) {
  return const VisitedPlaceConfig();
});

final visitedPlacesStorageProvider = Provider<VisitedPlacesLocalStorage>((ref) {
  return VisitedPlacesLocalStorage(logger: ref.watch(appLoggerProvider));
});

final visitedPlacesRepositoryProvider = Provider<VisitedPlacesRepository>((
  ref,
) {
  return LocalVisitedPlacesRepository(ref.watch(visitedPlacesStorageProvider));
});

/// Manages persistent visited-place history derived from validated beacon
/// proximity dwell times.
final visitedPlacesProvider =
    AsyncNotifierProvider<VisitedPlacesController, List<VisitedPlace>>(
      VisitedPlacesController.new,
    );

/// Map of `poiId -> VisitedPlace` for O(1) detail badge lookups.
final visitedPlacesByPoiIdProvider = Provider<Map<String, VisitedPlace>>((ref) {
  final visited = ref.watch(visitedPlacesProvider).asData?.value;
  if (visited == null || visited.isEmpty) {
    return const <String, VisitedPlace>{};
  }
  return Map<String, VisitedPlace>.unmodifiable({
    for (final place in visited) place.poiId: place,
  });
});

final class VisitedPlacesController extends AsyncNotifier<List<VisitedPlace>> {
  late VisitDwellEvaluator _evaluator;
  bool _isDisposed = false;

  @override
  Future<List<VisitedPlace>> build() async {
    _isDisposed = false;
    ref.onDispose(() => _isDisposed = true);

    final config = ref.watch(visitedPlaceConfigProvider);
    _evaluator = VisitDwellEvaluator(config: config);

    final repository = ref.watch(visitedPlacesRepositoryProvider);
    final initial = await repository.loadVisitedPlaces();
    _evaluator.seedLastVisits(initial);

    ref.listen<BeaconProximityViewState>(beaconProximityProvider, (
      previous,
      next,
    ) {
      unawaited(_evaluateProximity(next));
    });

    return initial;
  }

  Future<void> _evaluateProximity(BeaconProximityViewState proximity) async {
    final candidates = _evaluator.evaluate(proximity.recordsByBeaconId);
    if (candidates.isEmpty) return;

    final pois = ref.read(poiCatalogueProvider).asData?.value;
    if (pois == null || pois.isEmpty) return;
    final poisById = <String, Poi>{for (final poi in pois) poi.id: poi};

    final repository = ref.read(visitedPlacesRepositoryProvider);
    List<VisitedPlace>? latest;
    for (final candidate in candidates) {
      final poi = poisById[candidate.poiId];
      if (poi == null) continue;
      latest = await repository.recordVisit(
        poi,
        visitedAt: candidate.visitedAt,
        beaconId: candidate.beaconId,
      );
    }

    if (!_isDisposed && latest != null) {
      state = AsyncData(latest);
    }
  }

  /// Clears all persisted visited-place history and resets dwell/cooldown state.
  Future<void> clearHistory() async {
    final repository = ref.read(visitedPlacesRepositoryProvider);
    final cleared = await repository.clearHistory();
    _evaluator.clearTracking();
    if (!_isDisposed) {
      state = AsyncData(cleared);
    }
  }
}
