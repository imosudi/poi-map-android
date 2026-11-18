import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../poi/domain/entities/poi.dart';

/// Builds deduplicated Google Maps [Marker]s from valid [Poi] coordinates.
abstract final class PoiMarkerBuilder {
  static Set<Marker> build({
    required Iterable<Poi> pois,
    String? selectedPoiId,
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
      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: LatLng(poi.latitude, poi.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueAzure : BitmapDescriptor.hueRed,
          ),
          zIndexInt: isSelected ? 1 : 0,
          infoWindow: InfoWindow(title: poi.name, snippet: poi.address),
          onTap: onSelect == null ? null : () => onSelect(poi),
        ),
      );
    }

    return markers;
  }
}
