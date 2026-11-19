import 'dart:ui';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../poi/domain/entities/poi.dart';
import 'poi_marker_style.dart';

/// Builds deduplicated, category-styled Google Maps [Marker]s from valid [Poi]s.
abstract final class PoiMarkerBuilder {
  static const Offset pinAnchor = Offset(0.5, 1.0);

  static Set<Marker> build({
    required Iterable<Poi> pois,
    String? selectedPoiId,
    Map<PoiMarkerCategory, BitmapDescriptor> iconCache = const {},
    void Function(Poi poi)? onSelect,
  }) {
    final markers = <Marker>{};
    final seenIds = <String>{};

    for (final poi in pois) {
      if (!Poi.isValidCoordinate(poi.latitude, poi.longitude)) {
        continue;
      }
      if (!seenIds.add(poi.id)) {
        continue;
      }

      final isSelected = poi.id == selectedPoiId;
      final category = PoiMarkerStyleResolver.resolve(poi.category);
      final icon =
          iconCache[category] ??
          BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
          );

      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: LatLng(poi.latitude, poi.longitude),
          icon: icon,
          anchor: pinAnchor,
          zIndexInt: isSelected ? 1 : 0,
          infoWindow: InfoWindow(title: poi.name, snippet: poi.address),
          onTap: onSelect == null ? null : () => onSelect(poi),
        ),
      );
    }

    return markers;
  }
}
