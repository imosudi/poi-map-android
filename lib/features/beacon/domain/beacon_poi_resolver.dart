import '../../poi/domain/entities/poi.dart';
import 'beacon_registry_models.dart';
import 'poi_beacon_models.dart';

/// Outcome status of resolving a parsed beacon advertisement to a [Poi].
enum BeaconResolutionStatus { resolved, unknownBeacon, poiNotFound }

/// A parsed beacon advertisement paired with its registry entry and [Poi].
final class ResolvedBeaconPoi {
  const ResolvedBeaconPoi({
    required this.advertisement,
    required this.registryEntry,
    required this.poi,
  });

  final PoiBeaconAdvertisement advertisement;
  final BeaconRegistryEntry registryEntry;
  final Poi poi;
}

/// Deterministic resolution result for a single [PoiBeaconAdvertisement].
final class BeaconResolutionResult {
  const BeaconResolutionResult.resolved(ResolvedBeaconPoi this.resolved)
    : status = BeaconResolutionStatus.resolved,
      registryEntry = null;

  const BeaconResolutionResult.unknownBeacon()
    : status = BeaconResolutionStatus.unknownBeacon,
      resolved = null,
      registryEntry = null;

  const BeaconResolutionResult.poiNotFound(
    BeaconRegistryEntry this.registryEntry,
  ) : status = BeaconResolutionStatus.poiNotFound,
      resolved = null;

  final BeaconResolutionStatus status;
  final ResolvedBeaconPoi? resolved;
  final BeaconRegistryEntry? registryEntry;

  bool get isResolved => status == BeaconResolutionStatus.resolved;
}

/// Maps validated [PoiBeaconAdvertisement] instances through [BeaconRegistry]
/// to existing [Poi] entities from the POI catalogue/repository.
final class BeaconPoiResolver {
  const BeaconPoiResolver();

  BeaconResolutionResult resolve({
    required PoiBeaconAdvertisement advertisement,
    required BeaconRegistry registry,
    required Map<String, Poi> poisById,
  }) {
    final entry = registry.findByBeaconId(advertisement.beaconId);
    if (entry == null) {
      return const BeaconResolutionResult.unknownBeacon();
    }

    final poi = poisById[entry.poiId];
    if (poi == null) {
      return BeaconResolutionResult.poiNotFound(entry);
    }

    return BeaconResolutionResult.resolved(
      ResolvedBeaconPoi(
        advertisement: advertisement,
        registryEntry: entry,
        poi: poi,
      ),
    );
  }

  /// Resolves a batch of advertisements against [registry] and [pois].
  List<ResolvedBeaconPoi> resolveAll({
    required Iterable<PoiBeaconAdvertisement> advertisements,
    required BeaconRegistry registry,
    required Iterable<Poi> pois,
  }) {
    final poisById = <String, Poi>{for (final poi in pois) poi.id: poi};
    final resolved = <ResolvedBeaconPoi>[];
    for (final adv in advertisements) {
      final result = resolve(
        advertisement: adv,
        registry: registry,
        poisById: poisById,
      );
      if (result.resolved != null) {
        resolved.add(result.resolved!);
      }
    }
    return List<ResolvedBeaconPoi>.unmodifiable(resolved);
  }
}

