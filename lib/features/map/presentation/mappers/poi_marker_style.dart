import '../../../../core/constants/app_assets.dart';

/// Supported visual marker categories aligned with Vienna OGD sights.
enum PoiMarkerCategory {
  landmark(label: 'Landmark', assetPath: AppAssets.landmarkMarker),
  museum(label: 'Museum', assetPath: AppAssets.museumMarker),
  sacred(label: 'Sacred', assetPath: AppAssets.sacredMarker),
  nature(label: 'Nature', assetPath: AppAssets.natureMarker),
  observatory(label: 'Observatory', assetPath: AppAssets.observatoryMarker),
  favourite(label: 'Saved', assetPath: AppAssets.favouriteMarker);

  const PoiMarkerCategory({required this.label, required this.assetPath});

  final String label;
  final String assetPath;
}

/// Maps dataset category strings to [PoiMarkerCategory] with a consistent
/// fallback for missing or unrecognised values.
abstract final class PoiMarkerStyleResolver {
  static PoiMarkerCategory resolve(String? rawCategory) {
    final normalized = rawCategory?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return PoiMarkerCategory.landmark;
    }

    return switch (normalized) {
      'museum' || 'gallery' || 'galerie' => PoiMarkerCategory.museum,
      'sacred' ||
      'church' ||
      'kirche' ||
      'religious' ||
      'cemetery' ||
      'friedhof' => PoiMarkerCategory.sacred,
      'nature' ||
      'park' ||
      'garden' ||
      'garten' ||
      'zoo' => PoiMarkerCategory.nature,
      'observatory' ||
      'planetarium' ||
      'sternwarte' => PoiMarkerCategory.observatory,
      'favourite' || 'favorite' || 'saved' => PoiMarkerCategory.favourite,
      _ => PoiMarkerCategory.landmark,
    };
  }
}
