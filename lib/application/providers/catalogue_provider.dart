import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vienna_poi_repository.dart';
import '../../data/services/vienna_poi_service.dart';
import '../../domain/repositories/poi_repository.dart';
import '../state/catalogue_state.dart';

/// Provides the POI repository implementation.
final poiRepositoryProvider = Provider<PoiRepository>((ref) {
  return ViennaPoiRepository(service: ViennaPoiService());
});

/// Manages loading, searching, filtering, and refreshing the POI catalogue.
class CatalogueNotifier extends Notifier<CatalogueState> {
  @override
  CatalogueState build() => const CatalogueState();

  Future<void> loadIfNeeded() async {
    if (state.status != CatalogueStatus.idle) return;
    state = state.copyWith(
      status: CatalogueStatus.loading,
      clearErrorMessage: true,
    );

    try {
      final places = await ref
          .read(poiRepositoryProvider)
          .fetchPointsOfInterest();
      state = state.copyWith(
        status: CatalogueStatus.loaded,
        places: places,
        clearErrorMessage: true,
      );
    } catch (error) {
      state = state.copyWith(
        status: CatalogueStatus.failed,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retry() async {
    if (state.status != CatalogueStatus.failed) return;
    state = state.copyWith(
      status: CatalogueStatus.idle,
      clearErrorMessage: true,
    );
    await loadIfNeeded();
  }

  Future<void> refresh() async {
    if (state.status != CatalogueStatus.loaded || state.isRefreshing) return;

    state = state.copyWith(isRefreshing: true, clearRefreshError: true);

    try {
      final places = await ref
          .read(poiRepositoryProvider)
          .fetchPointsOfInterest();
      state = state.copyWith(
        status: CatalogueStatus.loaded,
        places: places,
        isRefreshing: false,
        clearRefreshError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isRefreshing: false,
        refreshError: 'Could not refresh places: $error',
      );
    }
  }

  void setSearchQuery(String query) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
  }

  void setQuickFilter(QuickFilter filter) {
    if (state.quickFilter == filter) return;
    state = state.copyWith(quickFilter: filter);
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    state = state.copyWith(clearRefreshError: true);
  }
}

/// Global Riverpod provider for [CatalogueNotifier].
final catalogueProvider = NotifierProvider<CatalogueNotifier, CatalogueState>(
  CatalogueNotifier.new,
);

