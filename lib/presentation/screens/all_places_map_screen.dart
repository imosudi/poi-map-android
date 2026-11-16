import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/providers/catalogue_provider.dart';
import '../../application/providers/location_provider.dart';
import '../../application/state/catalogue_state.dart';
import '../../application/state/location_state.dart';
import '../../core/theme/app_palette.dart';
import '../../domain/entities/point_of_interest.dart';
import '../widgets/poi_callout_card.dart';
import '../widgets/poi_map_view.dart';

/// Interactive map displaying all loaded Vienna POIs and user position.
class AllPlacesMapScreen extends ConsumerStatefulWidget {
  const AllPlacesMapScreen({
    super.key,
    this.mapBuilder,
    this.calloutTrailingBuilder,
  });

  final PoiMapWidgetBuilder? mapBuilder;
  final Widget Function(PointOfInterest place)? calloutTrailingBuilder;

  @override
  ConsumerState<AllPlacesMapScreen> createState() => _AllPlacesMapScreenState();
}

class _AllPlacesMapScreenState extends ConsumerState<AllPlacesMapScreen> {
  PointOfInterest? _selectedPlace;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(catalogueProvider.notifier).loadIfNeeded();
      ref.read(locationProvider.notifier).refreshLocation();
    });
  }

  @override
  Widget build(BuildContext context) {
    final catalogueState = ref.watch(catalogueProvider);
    final locationState = ref.watch(locationProvider);
    final places = catalogueState.places;

    final initialCenter = places.isNotEmpty
        ? LatLng(places.first.latitude, places.first.longitude)
        : PoiMapView.viennaCenter;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vienna Map'),
        actions: [
          IconButton(
            tooltip: 'Refresh location',
            onPressed: () =>
                ref.read(locationProvider.notifier).refreshLocation(),
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (catalogueState.status == CatalogueStatus.loading &&
              places.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            Positioned.fill(
              child: PoiMapView(
                places: places,
                initialCenter: initialCenter,
                initialZoom: 12.5,
                myLocationEnabled: locationState.isAuthorised,
                mapBuilder: widget.mapBuilder,
                onSelectPlace: (place) {
                  setState(() {
                    _selectedPlace = place;
                  });
                },
              ),
            ),
          if (locationState.statusMessage != null)
            Positioned(
              top: 12,
              left: 16,
              right: 16,
              child: _LocationStatusBanner(
                message: locationState.statusMessage!,
                status: locationState.status,
                onAction: () {
                  if (locationState.status ==
                          LocationStatus.permissionDeniedForever ||
                      locationState.status == LocationStatus.serviceDisabled) {
                    ref.read(locationProvider.notifier).openSettings();
                  } else {
                    ref.read(locationProvider.notifier).refreshLocation();
                  }
                },
              ),
            ),
          if (_selectedPlace != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: PoiCalloutCard(
                place: _selectedPlace!,
                userLocation: locationState.coordinate,
                trailingAction: widget.calloutTrailingBuilder?.call(
                  _selectedPlace!,
                ),
                onClose: () {
                  setState(() {
                    _selectedPlace = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LocationStatusBanner extends StatelessWidget {
  const _LocationStatusBanner({
    required this.message,
    required this.status,
    required this.onAction,
  });

  final String message;
  final LocationStatus status;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final showSettingsButton =
        status == LocationStatus.permissionDenied ||
        status == LocationStatus.permissionDeniedForever ||
        status == LocationStatus.serviceDisabled;

    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(14),
      color: AppPalette.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined, color: AppPalette.ink),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppPalette.ink),
              ),
            ),
            if (showSettingsButton)
              TextButton(
                onPressed: onAction,
                child: Text(
                  status == LocationStatus.permissionDenied
                      ? 'Allow'
                      : 'Settings',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
