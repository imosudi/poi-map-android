import 'point_of_interest.dart';

/// Visual marker classification derived from available dataset attributes.
enum PoiMarkerStyle {
  informationLink,
  neutral;

  factory PoiMarkerStyle.fromPoi(PointOfInterest poi) {
    return poi.informationUrl != null
        ? PoiMarkerStyle.informationLink
        : PoiMarkerStyle.neutral;
  }

  String get accessibilityDescription {
    switch (this) {
      case PoiMarkerStyle.informationLink:
        return 'Information link available';
      case PoiMarkerStyle.neutral:
        return 'No information link listed';
    }
  }
}
