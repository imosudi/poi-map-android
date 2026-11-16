import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../application/providers/location_provider.dart';
import '../../domain/entities/point_of_interest.dart';
import '../widgets/poi_callout_card.dart';
import '../widgets/poi_map_view.dart';

/// Focused map view centred on a selected Vienna Point of Interest.
class PoiDetailMapScreen extends ConsumerStatefulWidget {
  const PoiDetailMapScreen({
    super.key,
    required this.selectedPlace,
    this.allPlaces = const [],
    this.mapBuilder,
    this.appBarActions,
  });

  final PointOfInterest selectedPlace;
  final List<PointOfInterest> allPlaces;
  final PoiMapWidgetBuilder? mapBuilder;
  final List<Widget>? appBarActions;

  @override
  ConsumerState<PoiDetailMapScreen> createState() => _PoiDetailMapScreenState();
}

class _PoiDetailMapScreenState extends ConsumerState<PoiDetailMapScreen> {
  late PointOfInterest _focusedPlace;

  @override
  void initState() {
    super.initState();
    _focusedPlace = widget.selectedPlace;
    Future.microtask(() {
      ref
          .read(locationProvider.notifier)
          .refreshLocation(requestPermission: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final locationState = ref.watch(locationProvider);
    final places = widget.allPlaces.isEmpty
        ? [widget.selectedPlace]
        : widget.allPlaces;

    return Scaffold(
      appBar: AppBar(
        title: Text(_focusedPlace.name),
        actions: widget.appBarActions,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: PoiMapView(
              places: places,
              initialCenter: LatLng(
                widget.selectedPlace.latitude,
                widget.selectedPlace.longitude,
              ),
              initialZoom: 15.0,
              myLocationEnabled: locationState.isAuthorised,
              mapBuilder: widget.mapBuilder,
              onSelectPlace: (place) {
                setState(() {
                  _focusedPlace = place;
                });
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: PoiCalloutCard(
              place: _focusedPlace,
              userLocation: locationState.coordinate,
            ),
          ),
        ],
      ),
    );
  }
}
