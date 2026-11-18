import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/app.dart';
import 'package:poi_map_android/app/router.dart';
import 'package:poi_map_android/app/theme/app_palette.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/constants/app_assets.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';

final class _FakePoiRepository implements PoiRepository {
  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    return const [
      Poi(
        id: 'SEHENSWUERDIGOGD.1',
        name: 'Ankeruhr',
        latitude: 48.21076,
        longitude: 16.37368,
        address: 'Hoher Markt 10/',
      ),
    ];
  }
}

void main() {
  testWidgets('AppShell renders branding assets, attribution, and navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(_FakePoiRepository()),
          mapApiKeyConfiguredProvider.overrideWith((_) => false),
        ],
        child: const ViennaPoiExplorerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vienna POI Explorer'), findsOneWidget);
    expect(find.text('Mosudi Isiaka O., FHTW © 2026'), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == AppAssets.headerBanner,
      ),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                AppAssets.cityWienOpenDataBadge,
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('Vienna Map'), findsOneWidget);

    await tester.tap(find.text('Saved'));
    await tester.pumpAndSettle();
    expect(find.text('Saved Places'), findsOneWidget);
  });

  testWidgets('AppRouter handles named routes and unknown route fallback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(_FakePoiRepository()),
          mapApiKeyConfiguredProvider.overrideWith((_) => false),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          initialRoute: AppRoutes.map,
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Vienna Map'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('unknown-route-scope'),
        child: MaterialApp(
          key: const ValueKey('unknown-route'),
          theme: AppTheme.light(),
          initialRoute: '/non-existent',
          onGenerateRoute: AppRouter.onGenerateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Route not found'), findsOneWidget);
  });

  test('AppTheme.light configures Material 3 palette tokens', () {
    final theme = AppTheme.light();
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, AppPalette.canvas);
    expect(theme.colorScheme.primary, AppPalette.accent);
    expect(theme.colorScheme.onSurface, AppPalette.ink);
  });
}
