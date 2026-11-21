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
    Set<String> savedPoiIds = const {},
    Set<String> nearbyBeaconPoiIds = const {},
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
      final isSaved = savedPoiIds.contains(poi.id);
      final isNearbyBeacon = nearbyBeaconPoiIds.contains(poi.id);
      final category = isSaved
          ? PoiMarkerCategory.favourite
          : PoiMarkerStyleResolver.resolve(poi.category);
      final icon =
          iconCache[category] ??
          BitmapDescriptor.defaultMarkerWithHue(
            isSelected
                ? BitmapDescriptor.hueAzure
                : isNearbyBeacon
                ? BitmapDescriptor.hueViolet
                : BitmapDescriptor.hueRed,
          );
      final snippet = isNearbyBeacon
          ? (poi.address != null && poi.address!.isNotEmpty
                ? '${poi.address!} • Nearby via beacon'
                : 'Nearby via beacon')
          : poi.address;

      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: LatLng(poi.latitude, poi.longitude),
          icon: icon,
          anchor: pinAnchor,
          zIndexInt: isSelected
              ? (nearbyBeaconPoiIds.isEmpty ? 1 : 2)
              : (isNearbyBeacon ? 1 : 0),
          infoWindow: InfoWindow(title: poi.name, snippet: snippet),
          onTap: onSelect == null ? null : () => onSelect(poi),
        ),
      );
    }

    return markers;
  }
}
