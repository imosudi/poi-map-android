import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../data/map_config_service.dart';

final mapConfigServiceProvider = Provider<MapConfigService>((ref) {
  return const MapConfigService();
});

final mapApiKeyConfiguredProvider = FutureProvider<bool>((ref) {
  return ref.watch(mapConfigServiceProvider).isApiKeyConfigured();
});

/// Stores the identifier of the currently selected POI on the map.
final selectedPoiIdProvider =
    NotifierProvider<SelectedPoiIdController, String?>(
      SelectedPoiIdController.new,
    );

final class SelectedPoiIdController extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String poiId) {
    state = poiId;
  }

  void clear() {
    state = null;
  }
}

/// Resolves the selected [Poi] from the shared catalogue dataset so map
/// selection always remains consistent with catalogue refreshes.
final selectedMapPoiProvider = Provider<Poi?>((ref) {
  final selectedId = ref.watch(selectedPoiIdProvider);
  if (selectedId == null) {
    return null;
  }

  final pois = ref.watch(poiCatalogueProvider).asData?.value;
  if (pois == null) {
    return null;
  }

  for (final poi in pois) {
    if (poi.id == selectedId) {
      return poi;
    }
  }
  return null;
});
