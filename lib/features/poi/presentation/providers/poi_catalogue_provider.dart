import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/cancellation_token.dart';
import '../../data/poi_providers.dart';
import '../../domain/entities/poi.dart';

/// Manages asynchronous loading and refreshing of the Vienna POI catalogue.
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

  /// Reloads the POI list from the repository.
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
