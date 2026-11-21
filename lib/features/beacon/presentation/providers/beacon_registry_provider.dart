import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../data/beacon_registry_local_data_source.dart';
import '../../data/beacon_registry_repository_impl.dart';
import '../../data/poi_beacon_parser.dart';
import '../../domain/beacon_poi_resolver.dart';
import '../../domain/beacon_registry_models.dart';
import '../../domain/beacon_registry_repository.dart';
import 'ble_scan_provider.dart';

/// Local data source provider for the beacon registry (`beacon_registry_v1`).
final beaconRegistryDataSourceProvider =
    Provider<BeaconRegistryLocalDataSource>((ref) {
      return SharedPreferencesBeaconRegistryDataSource();
    });

/// Repository provider for loading and updating the local beacon registry.
final beaconRegistryRepositoryProvider = Provider<BeaconRegistryRepository>((
  ref,
) {
  return BeaconRegistryRepositoryImpl(
    dataSource: ref.watch(beaconRegistryDataSourceProvider),
    logger: ref.watch(appLoggerProvider),
  );
});

/// Parser provider for POI-BEACON BLE Service Data payloads.
final poiBeaconParserProvider = Provider<PoiBeaconParser>((ref) {
  return const PoiBeaconParser();
});

/// Resolver provider mapping parsed beacon advertisements to POI entities.
final beaconPoiResolverProvider = Provider<BeaconPoiResolver>((ref) {
  return const BeaconPoiResolver();
});

/// Async controller managing the local [BeaconRegistry].
final beaconRegistryProvider =
    AsyncNotifierProvider<BeaconRegistryController, BeaconRegistry>(
      BeaconRegistryController.new,
    );

final class BeaconRegistryController extends AsyncNotifier<BeaconRegistry> {
  @override
  Future<BeaconRegistry> build() {
    return ref.watch(beaconRegistryRepositoryProvider).loadRegistry();
  }

  /// Inserts or updates a beacon-to-POI mapping without changing firmware.
  Future<void> upsertEntry(BeaconRegistryEntry entry) async {
    final repository = ref.read(beaconRegistryRepositoryProvider);
    final updated = await repository.upsertEntry(entry);
    state = AsyncData(updated);
  }

  /// Removes a beacon mapping by [beaconId].
  Future<void> removeEntry(String beaconId) async {
    final repository = ref.read(beaconRegistryRepositoryProvider);
    final updated = await repository.removeEntry(beaconId);
    state = AsyncData(updated);
  }
}

/// Pipeline provider connecting:
/// `BLE advertisement -> PoiBeaconParser -> BeaconRegistry -> POI Repository -> POI`.
final resolvedBeaconPoisProvider = Provider<List<ResolvedBeaconPoi>>((ref) {
  final rawResults = ref.watch(bleScanResultsProvider);
  final registryAsync = ref.watch(beaconRegistryProvider);
  final poisAsync = ref.watch(poiCatalogueProvider);

  final registry = registryAsync.asData?.value;
  final pois = poisAsync.asData?.value;
  if (registry == null || pois == null || rawResults.isEmpty) {
    return const <ResolvedBeaconPoi>[];
  }

  final parser = ref.watch(poiBeaconParserProvider);
  final resolver = ref.watch(beaconPoiResolverProvider);
  final advertisements = parser.parseAll(rawResults);
  if (advertisements.isEmpty) {
    return const <ResolvedBeaconPoi>[];
  }

  return resolver.resolveAll(
    advertisements: advertisements,
    registry: registry,
    pois: pois,
  );
});

