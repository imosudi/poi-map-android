import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../data/favourites_providers.dart';
import '../../domain/entities/saved_place.dart';

/// Feedback message emitted after a save operation.
final favouritesFeedbackProvider =
    NotifierProvider<FavouritesFeedbackController, String?>(
      FavouritesFeedbackController.new,
    );

final class FavouritesFeedbackController extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) {
    state = message;
  }

  void clear() {
    if (state != null) {
      state = null;
    }
  }
}

/// Manages persistent saved places loaded at application startup.
final favouritesProvider =
    AsyncNotifierProvider<FavouritesController, List<SavedPlace>>(
      FavouritesController.new,
      retry: (retryCount, error) => null,
    );

final class FavouritesController extends AsyncNotifier<List<SavedPlace>> {
  @override
  Future<List<SavedPlace>> build() {
    return ref.watch(favouritesRepositoryProvider).loadSavedPlaces();
  }

  /// Reloads saved places from persistent storage.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final result = await AsyncValue.guard(
      () => ref.read(favouritesRepositoryProvider).loadSavedPlaces(),
    );
    if (!ref.mounted) {
      return;
    }
    state = result;
  }

  /// Saves [poi] to persistent storage, preventing duplicates and preserving
  /// existing saved records if storage fails.
  Future<void> savePoi(Poi poi) async {
    final existing = state.asData?.value ?? const <SavedPlace>[];
    if (existing.any((place) => place.id == poi.id)) {
      return;
    }

    try {
      final updated = await ref
          .read(favouritesRepositoryProvider)
          .savePlace(poi);
      if (!ref.mounted) {
        return;
      }
      state = AsyncValue.data(updated);
      ref.read(favouritesFeedbackProvider.notifier).show('Saved ${poi.name}');
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      final message = error is AppException
          ? error.message
          : 'Unable to save place to device storage.';
      ref.read(favouritesFeedbackProvider.notifier).show(message);
    }
  }
}

/// Set of saved POI identifiers for fast lookup across catalogue and map.
final savedPoiIdsProvider = Provider<Set<String>>((ref) {
  final places = ref.watch(favouritesProvider).asData?.value;
  if (places == null || places.isEmpty) {
    return const <String>{};
  }
  return Set.unmodifiable(places.map((p) => p.id));
});

/// Saved places resolved against the live POI catalogue when available,
/// falling back to the persisted [SavedPlace] snapshot if a POI is missing
/// from the latest remote dataset.
final resolvedSavedPlacesProvider = Provider<AsyncValue<List<Poi>>>((ref) {
  final savedState = ref.watch(favouritesProvider);
  final catalogue = ref.watch(poiCatalogueProvider).asData?.value;

  return savedState.whenData((savedPlaces) {
    if (savedPlaces.isEmpty) {
      return const <Poi>[];
    }

    final liveById = <String, Poi>{
      if (catalogue != null)
        for (final poi in catalogue) poi.id: poi,
    };

    return List<Poi>.unmodifiable([
      for (final saved in savedPlaces) liveById[saved.id] ?? saved.toPoi(),
    ]);
  });
});
