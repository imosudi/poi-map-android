import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';
import 'package:poi_map_android/features/poi/presentation/screens/poi_catalogue_screen.dart';

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this._items);

  final List<Poi> _items;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async => _items;
}

List<Poi> _buildPois(int count) {
  return List<Poi>.generate(
    count,
    (index) => Poi(
      id: 'SEHENSWUERDIGOGD.$index',
      name: 'Vienna Sight $index',
      latitude: 48.20 + index * 0.0001,
      longitude: 16.37,
    ),
  );
}

void main() {
  testWidgets('paginates catalogue list and resets on search change', (
    WidgetTester tester,
  ) async {
    final pois = _buildPois(35);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(_FakePoiRepository(pois)),
          cataloguePageSizeProvider.overrideWithValue(15),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: PoiCatalogueScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Load more (15 of 35)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Load more (15 of 35)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more (15 of 35)'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Load more (30 of 35)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Load more (30 of 35)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more (30 of 35)'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Load more'), findsNothing);

    // Search resets pagination to page 1.
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Vienna Sight 1');
    await tester.pumpAndSettle();

    // Matches: 1, 10..19, 100.. -> 11 items (< 15), so no Load more button.
    expect(find.text('11 of 35 sights'), findsOneWidget);
    expect(find.textContaining('Load more'), findsNothing);
  });
}
