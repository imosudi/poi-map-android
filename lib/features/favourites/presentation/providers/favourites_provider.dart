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
  final Set<String> _deletingIds = <String>{};

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

  /// Removes [poi] from persistent storage, preventing duplicate deletions and
  /// preserving saved records if storage fails.
  Future<bool> removePoi(Poi poi) async {
    if (_deletingIds.contains(poi.id)) {
      return false;
    }

    final existing = state.asData?.value ?? const <SavedPlace>[];
    if (!existing.any((place) => place.id == poi.id)) {
      return false;
    }

    _deletingIds.add(poi.id);
    try {
      final updated = await ref
          .read(favouritesRepositoryProvider)
          .removePlace(poi.id);
      if (!ref.mounted) {
        return false;
      }
      state = AsyncValue.data(updated);
      ref
          .read(favouritesFeedbackProvider.notifier)
          .show('Removed ${poi.name} from saved places');
      return true;
    } catch (error) {
      if (!ref.mounted) {
        return false;
      }
      final message = error is AppException
          ? error.message
          : 'Unable to remove place from device storage.';
      ref.read(favouritesFeedbackProvider.notifier).show(message);
      return false;
    } finally {
      _deletingIds.remove(poi.id);
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
