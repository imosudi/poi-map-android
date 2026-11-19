import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/providers.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../data/location_service.dart';
import '../../data/map_config_service.dart';
import '../../domain/user_location.dart';
import '../mappers/poi_marker_style.dart';
import '../services/marker_icon_cache.dart';

final mapConfigServiceProvider = Provider<MapConfigService>((ref) {
  return const MapConfigService();
});

final mapApiKeyConfiguredProvider = FutureProvider<bool>((ref) {
  return ref.watch(mapConfigServiceProvider).isApiKeyConfigured();
});

final markerIconCacheProvider = Provider<MarkerIconCache>((ref) {
  return MarkerIconCache(logger: ref.watch(appLoggerProvider));
});

final markerIconsProvider =
    FutureProvider<Map<PoiMarkerCategory, BitmapDescriptor>>((ref) {
      return ref.watch(markerIconCacheProvider).preloadAll();
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

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService(logger: ref.watch(appLoggerProvider));
});

final userLocationIconProvider = FutureProvider<BitmapDescriptor>((ref) async {
  try {
    return await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(28, 28)),
      AppAssets.locationDot,
    );
  } catch (_) {
    return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }
});

/// Session-only foreground location state.
final class UserLocationState {
  const UserLocationState({
    this.isLocating = false,
    this.location,
    this.status,
    this.feedbackMessage,
    this.requestSequence = 0,
  });

  final bool isLocating;
  final UserLocation? location;
  final LocationAccessStatus? status;
  final String? feedbackMessage;
  final int requestSequence;

  UserLocationState copyWith({
    bool? isLocating,
    UserLocation? location,
    LocationAccessStatus? status,
    String? feedbackMessage,
    bool clearFeedback = false,
    int? requestSequence,
  }) {
    return UserLocationState(
      isLocating: isLocating ?? this.isLocating,
      location: location ?? this.location,
      status: status ?? this.status,
      feedbackMessage: clearFeedback
          ? null
          : (feedbackMessage ?? this.feedbackMessage),
      requestSequence: requestSequence ?? this.requestSequence,
    );
  }
}

final userLocationProvider =
    NotifierProvider<UserLocationController, UserLocationState>(
      UserLocationController.new,
    );

final class UserLocationController extends Notifier<UserLocationState> {
  @override
  UserLocationState build() => const UserLocationState();

  /// Requests foreground location permission and retrieves the current position.
  Future<void> locateUser() async {
    if (state.isLocating) {
      return;
    }

    state = state.copyWith(isLocating: true, clearFeedback: true);

    final result = await ref
        .read(locationServiceProvider)
        .requestAndGetCurrentLocation();
    if (!ref.mounted) {
      return;
    }

    if (result.isGranted) {
      state = state.copyWith(
        isLocating: false,
        location: result.location,
        status: result.status,
        clearFeedback: true,
        requestSequence: state.requestSequence + 1,
      );
      return;
    }

    state = state.copyWith(
      isLocating: false,
      status: result.status,
      feedbackMessage: result.message,
      requestSequence: state.requestSequence + 1,
    );
  }

  void clearFeedback() {
    if (state.feedbackMessage != null) {
      state = state.copyWith(clearFeedback: true);
    }
  }
}
