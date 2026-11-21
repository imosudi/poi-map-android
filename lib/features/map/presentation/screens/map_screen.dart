import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/copyright_footer.dart';
import '../../../beacon/presentation/providers/beacon_proximity_provider.dart';
import '../../../beacon/presentation/providers/ble_scan_provider.dart';
import '../../../beacon/presentation/widgets/beacon_scan_status_bar.dart';
import '../../../favourites/presentation/providers/favourites_provider.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../../poi/presentation/providers/poi_catalogue_provider.dart';
import '../../domain/user_location.dart';
import '../providers/map_providers.dart';
import '../widgets/poi_map_view.dart';

/// Interactive Vienna POI map screen.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, this.isActive = true, this.mapBuilder});

  final bool isActive;
  final GoogleMapWidgetBuilder? mapBuilder;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  bool _hasRequestedInitialLocation = false;

  @override
  void initState() {
    super.initState();
    _maybeRequestLocation();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _maybeRequestLocation();
    }
  }

  void _maybeRequestLocation() {
    if (!widget.isActive || _hasRequestedInitialLocation) {
      return;
    }
    _hasRequestedInitialLocation = true;
    Future.microtask(() {
      if (mounted) {
        ref.read(userLocationProvider.notifier).locateUser();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final apiKeyState = ref.watch(mapApiKeyConfiguredProvider);
    final catalogueState = ref.watch(poiCatalogueProvider);
    final selectedPoi = ref.watch(selectedMapPoiProvider);
    final selectedDistanceLabel = ref.watch(selectedPoiDistanceLabelProvider);
    final savedPoiIds = ref.watch(savedPoiIdsProvider);
    final markerIcons =
        ref.watch(markerIconsProvider).asData?.value ?? const {};
    final locationState = ref.watch(userLocationProvider);
    final userLocationIcon = ref.watch(userLocationIconProvider).asData?.value;
    final selectionController = ref.read(selectedPoiIdProvider.notifier);
    final locationController = ref.read(userLocationProvider.notifier);
    final favouritesController = ref.read(favouritesProvider.notifier);
    final bleScanState = ref.watch(bleScanControllerProvider);
    final bleScanController = ref.read(bleScanControllerProvider.notifier);
    final nearbyPoiStates = ref.watch(nearbyBeaconPoiStatesProvider);

    ref.listen<UserLocationState>(userLocationProvider, (previous, next) {
      final message = next.feedbackMessage;
      if (message == null || message == previous?.feedbackMessage) {
        return;
      }
      final status = next.status;
      final canOpenSettings =
          status == LocationAccessStatus.permanentlyDenied ||
          status == LocationAccessStatus.serviceDisabled;
      final locationService = ref.read(locationServiceProvider);

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(message),
            action: canOpenSettings
                ? SnackBarAction(
                    label: 'Settings',
                    onPressed: () {
                      if (status == LocationAccessStatus.serviceDisabled) {
                        locationService.openLocationSettings();
                      } else {
                        locationService.openAppSettings();
                      }
                    },
                  )
                : null,
          ),
        );
      locationController.clearFeedback();
    });

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Image.asset(
                  AppAssets.viennaShield,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Vienna Map',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: BeaconScanStatusBar(
              scanState: bleScanState,
              nearbyPoiCount: nearbyPoiStates.length,
              onStartScan: bleScanController.startScanning,
              onStopScan: bleScanController.stopScanning,
              onOpenSettings: bleScanController.openAppSettings,
            ),
          ),
          Expanded(
            child: apiKeyState.when(
              loading: () => const AppLoadingView(
                message: 'Checking map configuration...',
              ),
              error: (_, __) => AppErrorView(
                title: 'Map unavailable',
                message: 'Unable to verify Google Maps configuration.',
                onRetry: () => ref.invalidate(mapApiKeyConfiguredProvider),
              ),
              data: (isConfigured) {
                if (!isConfigured) {
                  return AppErrorView(
                    title: 'Google Maps key missing',
                    message:
                        'Add MAPS_API_KEY to android/local.properties to enable the interactive map.',
                    onRetry: () => ref.invalidate(mapApiKeyConfiguredProvider),
                  );
                }
                return AsyncValueView<List<Poi>>(
                  value: catalogueState,
                  loadingMessage: 'Loading Vienna map...',
                  onRetry: () =>
                      ref.read(poiCatalogueProvider.notifier).refresh(),
                  builder: (pois) => PoiMapView(
                    pois: pois,
                    selectedPoi: selectedPoi,
                    selectedPoiDistanceLabel: selectedDistanceLabel,
                    selectedPoiProximityState: selectedPoi == null
                        ? null
                        : nearbyPoiStates[selectedPoi.id],
                    savedPoiIds: savedPoiIds,
                    nearbyBeaconPoiIds: nearbyPoiStates.keys.toSet(),
                    markerIcons: markerIcons,
                    userLocation: locationState.location,
                    userLocationIcon: userLocationIcon,
                    userLocationSequence: locationState.requestSequence,
                    isLocatingUser: locationState.isLocating,
                    onLocateUser: locationController.locateUser,
                    onSavePoi: favouritesController.savePoi,
                    onPoiSelected: (poi) => selectionController.select(poi.id),
                    onClearSelection: selectionController.clear,
                    mapBuilder: widget.mapBuilder,
                  ),
                );
              },
            ),
          ),
          const CopyrightFooter(),
        ],
      ),
    );
  }
}
