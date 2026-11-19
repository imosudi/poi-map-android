import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/constants/app_assets.dart';
import 'package:poi_map_android/features/map/presentation/mappers/poi_marker_builder.dart';
import 'package:poi_map_android/features/map/presentation/mappers/poi_marker_style.dart';
import 'package:poi_map_android/features/map/presentation/services/marker_icon_cache.dart';
import 'package:poi_map_android/features/map/presentation/widgets/poi_marker_legend.dart';

void main() {
  group('PoiMarkerStyleResolver', () {
    test('maps known category strings case-insensitively', () {
      expect(
        PoiMarkerStyleResolver.resolve('Museum'),
        PoiMarkerCategory.museum,
      );
      expect(
        PoiMarkerStyleResolver.resolve('  gallery '),
        PoiMarkerCategory.museum,
      );
      expect(
        PoiMarkerStyleResolver.resolve('Church'),
        PoiMarkerCategory.sacred,
      );
      expect(PoiMarkerStyleResolver.resolve('Park'), PoiMarkerCategory.nature);
      expect(
        PoiMarkerStyleResolver.resolve('Sternwarte'),
        PoiMarkerCategory.observatory,
      );
      expect(
        PoiMarkerStyleResolver.resolve('Saved'),
        PoiMarkerCategory.favourite,
      );
      expect(
        PoiMarkerStyleResolver.resolve('Landmark'),
        PoiMarkerCategory.landmark,
      );
    });

    test('falls back to landmark for null, empty, or unknown categories', () {
      expect(PoiMarkerStyleResolver.resolve(null), PoiMarkerCategory.landmark);
      expect(PoiMarkerStyleResolver.resolve('   '), PoiMarkerCategory.landmark);
      expect(
        PoiMarkerStyleResolver.resolve('Unmapped Category'),
        PoiMarkerCategory.landmark,
      );
    });

    test('resolves expected asset paths for every marker category', () {
      expect(PoiMarkerCategory.landmark.assetPath, AppAssets.landmarkMarker);
      expect(PoiMarkerCategory.museum.assetPath, AppAssets.museumMarker);
      expect(PoiMarkerCategory.sacred.assetPath, AppAssets.sacredMarker);
      expect(PoiMarkerCategory.nature.assetPath, AppAssets.natureMarker);
      expect(
        PoiMarkerCategory.observatory.assetPath,
        AppAssets.observatoryMarker,
      );
      expect(PoiMarkerCategory.favourite.assetPath, AppAssets.favouriteMarker);
    });
  });

  group('MarkerIconCache', () {
    test(
      'caches loaded descriptors and deduplicates concurrent loads',
      () async {
        var loadCount = 0;
        final cache = MarkerIconCache(
          loader: (assetPath, size) async {
            loadCount++;
            return BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            );
          },
        );

        final results = await Future.wait([
          cache.getOrLoad(PoiMarkerCategory.museum),
          cache.getOrLoad(PoiMarkerCategory.museum),
        ]);

        expect(loadCount, 1);
        expect(results[0], results[1]);
        expect(cache.getCached(PoiMarkerCategory.museum), isNotNull);

        await cache.getOrLoad(PoiMarkerCategory.museum);
        expect(loadCount, 1);
      },
    );

    test('falls back to defaultMarker when asset loading fails', () async {
      final cache = MarkerIconCache(
        loader: (_, __) async => throw PlatformException(code: 'asset_error'),
      );

      final descriptor = await cache.getOrLoad(PoiMarkerCategory.sacred);
      expect(descriptor, BitmapDescriptor.defaultMarker);
      expect(
        cache.getCached(PoiMarkerCategory.sacred),
        BitmapDescriptor.defaultMarker,
      );
    });
  });

  group('PoiMarkerBuilder & PoiMarkerLegend', () {
    test('uses bottom-centre pin anchor', () {
      expect(PoiMarkerBuilder.pinAnchor, const Offset(0.5, 1.0));
    });

    testWidgets('PoiMarkerLegend renders all category labels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PoiMarkerLegend()),
        ),
      );

      for (final category in PoiMarkerCategory.values) {
        expect(find.text(category.label), findsOneWidget);
      }
    });
  });
}
