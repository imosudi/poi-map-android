import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/logging/app_logger.dart';
import '../mappers/poi_marker_style.dart';

typedef MarkerAssetLoader =
    Future<BitmapDescriptor> Function(String assetPath, Size logicalSize);

/// Loads and caches Google Maps [BitmapDescriptor] icons per [PoiMarkerCategory].
final class MarkerIconCache {
  MarkerIconCache({
    AppLogger? logger,
    MarkerAssetLoader? loader,
    this.markerSize = const Size(36, 44),
  }) : _logger = logger,
       _loader = loader ?? _defaultAssetLoader;

  final AppLogger? _logger;
  final MarkerAssetLoader _loader;
  final Size markerSize;

  final Map<PoiMarkerCategory, BitmapDescriptor> _resolved = {};
  final Map<PoiMarkerCategory, Future<BitmapDescriptor>> _inFlight = {};

  static Future<BitmapDescriptor> _defaultAssetLoader(
    String assetPath,
    Size logicalSize,
  ) {
    return BitmapDescriptor.asset(
      ImageConfiguration(size: logicalSize),
      assetPath,
    );
  }

  /// Returns a cached descriptor synchronously if already loaded.
  BitmapDescriptor? getCached(PoiMarkerCategory category) =>
      _resolved[category];

  /// Returns an unmodifiable snapshot of all currently cached descriptors.
  Map<PoiMarkerCategory, BitmapDescriptor> get snapshot =>
      Map.unmodifiable(_resolved);

  /// Loads and caches the descriptor for [category], deduplicating concurrent
  /// requests and falling back to [BitmapDescriptor.defaultMarker] on error.
  Future<BitmapDescriptor> getOrLoad(PoiMarkerCategory category) {
    final existing = _resolved[category];
    if (existing != null) {
      return Future.value(existing);
    }

    final pending = _inFlight[category];
    if (pending != null) {
      return pending;
    }

    final future = _loadSafely(category);
    _inFlight[category] = future;
    return future.whenComplete(() => _inFlight.remove(category));
  }

  /// Preloads descriptors for all marker categories.
  Future<Map<PoiMarkerCategory, BitmapDescriptor>> preloadAll() async {
    await Future.wait(PoiMarkerCategory.values.map(getOrLoad));
    return snapshot;
  }

  Future<BitmapDescriptor> _loadSafely(PoiMarkerCategory category) async {
    try {
      final descriptor = await _loader(category.assetPath, markerSize);
      _resolved[category] = descriptor;
      return descriptor;
    } catch (error, stackTrace) {
      _logger?.warning(
        'MarkerIconCache',
        'Failed to decode marker asset; using default marker',
        context: {'category': category.name},
        error: error,
        stackTrace: stackTrace,
      );
      const fallback = BitmapDescriptor.defaultMarker;
      _resolved[category] = fallback;
      return fallback;
    }
  }
}
