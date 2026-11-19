import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../app/theme/app_palette.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/widgets/app_error_view.dart';
import '../../../../core/widgets/app_loading_view.dart';
import '../../../poi/domain/entities/poi.dart';
import '../../domain/map_camera_calculator.dart';
import '../mappers/poi_marker_builder.dart';
import '../mappers/poi_marker_style.dart';
import 'poi_marker_legend.dart';
import 'selected_poi_card.dart';

typedef GoogleMapWidgetBuilder =
    Widget Function(
      BuildContext context,
      CameraPosition initialCameraPosition,
      Set<Marker> markers,
      void Function(GoogleMapController controller) onMapCreated,
    );

/// Reusable interactive map component displaying Vienna POI markers and
/// selection details.
class PoiMapView extends StatefulWidget {
  const PoiMapView({
    super.key,
    required this.pois,
    this.selectedPoi,
    this.markerIcons = const {},
    this.onPoiSelected,
    this.onClearSelection,
    this.mapBuilder,
  });

  final List<Poi> pois;
  final Poi? selectedPoi;
  final Map<PoiMarkerCategory, BitmapDescriptor> markerIcons;
  final ValueChanged<Poi>? onPoiSelected;
  final VoidCallback? onClearSelection;
  final GoogleMapWidgetBuilder? mapBuilder;

  @override
  State<PoiMapView> createState() => _PoiMapViewState();
}

class _PoiMapViewState extends State<PoiMapView> {
  static const double _selectedPoiZoom = 15.0;

  GoogleMapController? _controller;
  bool _isMapReady = false;
  bool _showLegend = false;
  String? _mapError;

  @override
  void didUpdateWidget(covariant PoiMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = widget.selectedPoi;
    if (selected != null && selected.id != oldWidget.selectedPoi?.id) {
      _focusOnPoi(selected);
    }
  }

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

    final selected = widget.selectedPoi;
    if (selected != null) {
      await _focusOnPoi(selected);
    } else {
      await _fitDatasetBounds(controller);
    }
  }

  Future<void> _focusOnPoi(Poi poi) async {
    final controller = _controller;
    if (controller == null ||
        !Poi.isValidCoordinate(poi.latitude, poi.longitude)) {
      return;
    }
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(poi.latitude, poi.longitude),
            zoom: _selectedPoiZoom,
          ),
        ),
      );
    } catch (_) {
      // Camera animation failures are non-fatal when selecting a marker.
    }
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
    final markers = PoiMarkerBuilder.build(
      pois: widget.pois,
      selectedPoiId: widget.selectedPoi?.id,
      iconCache: widget.markerIcons,
      onSelect: widget.onPoiSelected,
    );

    final mapWidget = widget.mapBuilder != null
        ? widget.mapBuilder!(context, initialPosition, markers, _onMapCreated)
        : GoogleMap(
            initialCameraPosition: initialPosition,
            markers: markers,
            onMapCreated: _onMapCreated,
            onTap: (_) => widget.onClearSelection?.call(),
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            myLocationButtonEnabled: false,
          );

    final selectedPoi = widget.selectedPoi;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
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
                const SizedBox(height: AppSpacing.sm),
                FloatingActionButton.small(
                  heroTag: 'map_legend_fab',
                  tooltip: 'Marker legend',
                  backgroundColor: _showLegend
                      ? AppPalette.accentSoft
                      : AppPalette.surface,
                  foregroundColor: _showLegend
                      ? AppPalette.accent
                      : AppPalette.ink,
                  onPressed: () => setState(() => _showLegend = !_showLegend),
                  child: const Icon(Icons.layers_outlined, size: 20),
                ),
              ],
            ),
          ),
        if (_showLegend)
          const Positioned(
            left: AppSpacing.md,
            right: 72,
            top: AppSpacing.md,
            child: PoiMarkerLegend(),
          ),
        if (selectedPoi != null)
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SelectedPoiCard(
              key: ValueKey(selectedPoi.id),
              poi: selectedPoi,
              onDismiss: () => widget.onClearSelection?.call(),
            ),
          ),
      ],
    );
  }
}
