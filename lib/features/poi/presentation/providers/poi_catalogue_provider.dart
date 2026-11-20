import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/network/cancellation_token.dart';
import '../../data/poi_providers.dart';
import '../../domain/entities/poi.dart';
import '../../domain/services/poi_filter.dart';

/// Tracks background refresh status without discarding loaded catalogue data.
final class PoiRefreshStatus {
  const PoiRefreshStatus({this.isRefreshing = false, this.errorMessage});

  final bool isRefreshing;
  final String? errorMessage;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is PoiRefreshStatus &&
        other.isRefreshing == isRefreshing &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(isRefreshing, errorMessage);
}

final poiRefreshStatusProvider =
    NotifierProvider<PoiRefreshStatusController, PoiRefreshStatus>(
      PoiRefreshStatusController.new,
    );

final class PoiRefreshStatusController extends Notifier<PoiRefreshStatus> {
  @override
  PoiRefreshStatus build() => const PoiRefreshStatus();

  void start() {
    state = const PoiRefreshStatus(isRefreshing: true);
  }

  void succeed() {
    state = const PoiRefreshStatus();
  }

  void fail(String message) {
    state = PoiRefreshStatus(isRefreshing: false, errorMessage: message);
  }
}

/// Manages asynchronous loading and refreshing of the original POI dataset.
final poiCatalogueProvider =
    AsyncNotifierProvider<PoiCatalogueController, List<Poi>>(
      PoiCatalogueController.new,
      retry: (retryCount, error) => null,
    );

final class PoiCatalogueController extends AsyncNotifier<List<Poi>> {
  CancellationToken? _activeCancelToken;
  Future<void>? _inFlightRefresh;

  @override
  Future<List<Poi>> build() {
    ref.onDispose(() => _activeCancelToken?.cancel());
    return _fetchWithToken();
  }

  /// Refreshes the POI dataset while preventing duplicate concurrent requests
  /// and preserving previously loaded data if the refresh fails.
  Future<void> refresh() {
    if (_inFlightRefresh != null) {
      return _inFlightRefresh!;
    }

    final future = _performRefresh();
    _inFlightRefresh = future;
    return future.whenComplete(() {
      if (identical(_inFlightRefresh, future)) {
        _inFlightRefresh = null;
      }
    });
  }

  Future<void> _performRefresh() async {
    final existing = state.asData?.value;
    if (existing == null) {
      state = const AsyncValue.loading();
      final result = await AsyncValue.guard(_fetchWithToken);
      if (!ref.mounted) {
        return;
      }
      state = result;
      return;
    }

    final refreshStatus = ref.read(poiRefreshStatusProvider.notifier);
    refreshStatus.start();

    try {
      final fresh = await _fetchWithToken();
      if (!ref.mounted) {
        return;
      }
      state = AsyncValue.data(fresh);
      ref.read(cataloguePageProvider.notifier).reset();
      refreshStatus.succeed();
    } catch (error) {
      if (!ref.mounted) {
        return;
      }
      final message = error is AppException
          ? error.message
          : 'Unable to refresh sights. Please try again.';
      refreshStatus.fail(message);
    }
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

/// Number of POIs revealed per catalogue page.
final cataloguePageSizeProvider = Provider<int>((ref) => 15);

/// Current 1-based page index for the catalogue list, resetting whenever
/// search or category criteria change.
final cataloguePageProvider = NotifierProvider<CataloguePageController, int>(
  CataloguePageController.new,
);

final class CataloguePageController extends Notifier<int> {
  @override
  int build() {
    ref.watch(poiFilterCriteriaProvider);
    return 1;
  }

  void loadNextPage() {
    state = state + 1;
  }

  void reset() {
    if (state != 1) {
      state = 1;
    }
  }
}

/// Paginated slice of [filteredPoisProvider] for incremental list rendering.
final paginatedPoisProvider =
    Provider<AsyncValue<({List<Poi> items, int totalCount, bool hasMore})>>((
      ref,
    ) {
      final filteredState = ref.watch(filteredPoisProvider);
      final page = ref.watch(cataloguePageProvider);
      final pageSize = ref.watch(cataloguePageSizeProvider);

      return filteredState.whenData((filtered) {
        final visibleCount = math.min(page * pageSize, filtered.length);
        return (
          items: List<Poi>.unmodifiable(filtered.take(visibleCount)),
          totalCount: filtered.length,
          hasMore: visibleCount < filtered.length,
        );
      });
    });
