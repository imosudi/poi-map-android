import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../domain/map_camera_calculator.dart';

typedef GoogleMapWidgetBuilder =
    Widget Function(
      BuildContext context,
      CameraPosition initialCameraPosition,
      Set<Marker> markers,
      void Function(GoogleMapController controller) onMapCreated,
    );

/// Reusable interactive map component ready to display Vienna POI markers.
class PoiMapView extends StatefulWidget {
  const PoiMapView({
    super.key,
    required this.pois,
    this.markers = const {},
    this.mapBuilder,
  });

  final List<Poi> pois;
  final Set<Marker> markers;
  final GoogleMapWidgetBuilder? mapBuilder;

  @override
  State<PoiMapView> createState() => _PoiMapViewState();
}

class _PoiMapViewState extends State<PoiMapView> {
  GoogleMapController? _controller;
  bool _isMapReady = false;
  String? _mapError;

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    if (!mounted) {
      return;
    }
    setState(() {
      _isMapReady = true;
      _mapError = null;
    });

    await _fitDatasetBounds(controller);
  }

  Future<void> _fitDatasetBounds(GoogleMapController controller) async {
    final spec = MapCameraCalculator.computeInitialCamera(widget.pois);
    if (!spec.hasBounds) {
      return;
    }
    try {
      final bounds = LatLngBounds(
        southwest: LatLng(spec.southwestLatitude!, spec.southwestLongitude!),
        northeast: LatLng(spec.northeastLatitude!, spec.northeastLongitude!),
      );
      await controller.moveCamera(CameraUpdate.newLatLngBounds(bounds, 48));
    } catch (_) {
      // Initial CameraPosition already centres on the dataset.
    }
  }

  Future<void> _recentre() async {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    final spec = MapCameraCalculator.computeInitialCamera(widget.pois);
    try {
      if (spec.hasBounds) {
        final bounds = LatLngBounds(
          southwest: LatLng(spec.southwestLatitude!, spec.southwestLongitude!),
          northeast: LatLng(spec.northeastLatitude!, spec.northeastLongitude!),
        );
        await controller.animateCamera(
          CameraUpdate.newLatLngBounds(bounds, 48),
        );
      } else {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(spec.latitude, spec.longitude),
              zoom: spec.zoom,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapError = 'Unable to update the map camera.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_mapError != null) {
      return AppErrorView(
        title: 'Map unavailable',
        message: _mapError!,
        onRetry: () {
          setState(() {
            _mapError = null;
            _isMapReady = false;
          });
        },
      );
    }

    final spec = MapCameraCalculator.computeInitialCamera(widget.pois);
    final initialPosition = CameraPosition(
      target: LatLng(spec.latitude, spec.longitude),
      zoom: spec.zoom,
    );

    final mapWidget = widget.mapBuilder != null
        ? widget.mapBuilder!(
            context,
            initialPosition,
            widget.markers,
            _onMapCreated,
          )
        : GoogleMap(
            initialCameraPosition: initialPosition,
            markers: widget.markers,
            onMapCreated: _onMapCreated,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          );

    return Stack(
      children: [
        Positioned.fill(child: mapWidget),
        if (!_isMapReady)
          const Positioned.fill(
            child: ColoredBox(
              color: AppPalette.canvas,
              child: AppLoadingView(message: 'Initialising map...'),
            ),
          ),
        if (_isMapReady)
          Positioned(
            right: AppSpacing.md,
            top: AppSpacing.md,
            child: FloatingActionButton.small(
              heroTag: 'recentre_map_fab',
              tooltip: 'Recentre map',
              backgroundColor: AppPalette.surface,
              foregroundColor: AppPalette.ink,
              onPressed: _recentre,
              child: Image.asset(
                AppAssets.mapPin,
                width: 20,
                height: 20,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
      ],
    );
  }
}
