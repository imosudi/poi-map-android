import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../data/models/vienna_poi_dto.dart';
import '../../domain/entities/poi_marker_style.dart';
import '../../domain/entities/point_of_interest.dart';

/// Signature allowing widget tests to substitute the native [GoogleMap] view.
typedef PoiMapWidgetBuilder =
    Widget Function(
      BuildContext context,
      CameraPosition initialCameraPosition,
      Set<Marker> markers,
      bool myLocationEnabled,
    );

/// Interactive Google Map rendering validated Vienna POIs and styled markers.
class PoiMapView extends StatefulWidget {
  const PoiMapView({
    super.key,
    required this.places,
    required this.initialCenter,
    this.initialZoom = 13.0,
    this.myLocationEnabled = false,
    this.onSelectPlace,
    this.mapBuilder,
  });

  static const LatLng viennaCenter = LatLng(48.2082, 16.3738);

  final List<PointOfInterest> places;
  final LatLng initialCenter;
  final double initialZoom;
  final bool myLocationEnabled;
  final ValueChanged<PointOfInterest>? onSelectPlace;
  final PoiMapWidgetBuilder? mapBuilder;

  @override
  State<PoiMapView> createState() => _PoiMapViewState();
}

class _PoiMapViewState extends State<PoiMapView> {
  BitmapDescriptor? _infoLinkMarker;
  BitmapDescriptor? _neutralMarker;

  @override
  void initState() {
    super.initState();
    _loadMarkerIcons();
  }

  Future<void> _loadMarkerIcons() async {
    try {
      final infoIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(36, 40)),
        AppAssets.mapPin,
      );
      final neutralIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(32, 38)),
        AppAssets.viennaShield,
      );
      if (!mounted) return;
      setState(() {
        _infoLinkMarker = infoIcon;
        _neutralMarker = neutralIcon;
      });
    } catch (_) {
      // Fall back to default Google Maps pins if asset decoding fails.
    }
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};
    for (final place in widget.places) {
      if (!ViennaPoiParser.isValidCoordinate(
        latitude: place.latitude,
        longitude: place.longitude,
      )) {
        continue;
      }

      final style = PoiMarkerStyle.fromPoi(place);
      final icon = switch (style) {
        PoiMarkerStyle.informationLink =>
          _infoLinkMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        PoiMarkerStyle.neutral =>
          _neutralMarker ??
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      };

      markers.add(
        Marker(
          markerId: MarkerId(place.id),
          position: LatLng(place.latitude, place.longitude),
          icon: icon,
          infoWindow: InfoWindow(title: place.name, snippet: place.address),
          onTap: () => widget.onSelectPlace?.call(place),
        ),
      );
    }
    return markers;
  }

  @override
  Widget build(BuildContext context) {
    final initialPosition = CameraPosition(
      target: widget.initialCenter,
      zoom: widget.initialZoom,
    );
    final markers = _buildMarkers();

    if (widget.mapBuilder != null) {
      return widget.mapBuilder!(
        context,
        initialPosition,
        markers,
        widget.myLocationEnabled,
      );
    }

    return GoogleMap(
      initialCameraPosition: initialPosition,
      markers: markers,
      myLocationEnabled: widget.myLocationEnabled,
      myLocationButtonEnabled: widget.myLocationEnabled,
      mapToolbarEnabled: false,
      compassEnabled: true,
    );
  }
}

