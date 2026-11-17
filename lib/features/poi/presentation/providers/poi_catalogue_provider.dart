import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/cancellation_token.dart';
import '../../data/poi_providers.dart';
import '../../domain/entities/poi.dart';
import '../../domain/services/poi_filter.dart';

/// Manages asynchronous loading and refreshing of the original POI dataset.
final poiCatalogueProvider =
    AsyncNotifierProvider<PoiCatalogueController, List<Poi>>(
      PoiCatalogueController.new,
      retry: (retryCount, error) => null,
    );

final class PoiCatalogueController extends AsyncNotifier<List<Poi>> {
  CancellationToken? _activeCancelToken;

  @override
  Future<List<Poi>> build() {
    ref.onDispose(() => _activeCancelToken?.cancel());
    return _fetchWithToken();
  }

  /// Reloads the POI list from the repository while preserving filter state.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetchWithToken);
  }

  Future<List<Poi>> _fetchWithToken() {
    _activeCancelToken?.cancel();
    final token = CancellationToken();
    _activeCancelToken = token;
    return ref.read(poiRepositoryProvider).fetchPois(cancelToken: token);
  }
}

/// Holds the active search query and category filter separately from raw data.
final poiFilterCriteriaProvider =
    NotifierProvider<PoiFilterCriteriaController, PoiFilterCriteria>(
      PoiFilterCriteriaController.new,
    );

final class PoiFilterCriteriaController extends Notifier<PoiFilterCriteria> {
  @override
  PoiFilterCriteria build() => const PoiFilterCriteria();

  void setQuery(String query) {
    state = state.copyWith(query: query);
  }

  void setCategory(String? category) {
    final normalized = category?.trim();
    if (normalized == null || normalized.isEmpty) {
      state = state.copyWith(clearCategory: true);
    } else {
      state = state.copyWith(category: normalized);
    }
  }

  void clearQuery() {
    state = state.copyWith(query: '');
  }

  void clearAll() {
    state = const PoiFilterCriteria();
  }
}

/// Distinct category labels present in the loaded POI dataset.
final availablePoiCategoriesProvider = Provider<List<String>>((ref) {
  final pois = ref.watch(poiCatalogueProvider).asData?.value;
  if (pois == null || pois.isEmpty) {
    return const [];
  }
  return PoiFilter.extractCategories(pois);
});

/// Filtered presentation view derived locally without extra network requests.
final filteredPoisProvider = Provider<AsyncValue<List<Poi>>>((ref) {
  final catalogue = ref.watch(poiCatalogueProvider);
  final criteria = ref.watch(poiFilterCriteriaProvider);
  return catalogue.whenData((pois) => PoiFilter.apply(pois, criteria));
});
