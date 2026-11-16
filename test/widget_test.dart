import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app.dart';
import 'package:poi_map_android/core/constants/app_assets.dart';

void main() {
  testWidgets('HomeShell renders branding assets and attribution footer', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: ViennaPoiExplorerApp()));

    expect(find.text('Vienna POI Explorer'), findsOneWidget);
    expect(find.text('Mosudi Isiaka O., FHTW © 2026'), findsOneWidget);
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
  });
}
