import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/application/providers/catalogue_provider.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/theme/app_theme.dart';
import 'package:poi_map_android/domain/entities/point_of_interest.dart';
import 'package:poi_map_android/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/presentation/screens/poi_catalogue_screen.dart';

class _StubPoiRepository implements PoiRepository {
  _StubPoiRepository(this._handler);

  final Future<List<PointOfInterest>> Function() _handler;

  @override
  Future<List<PointOfInterest>> fetchPointsOfInterest() => _handler();
}

void main() {
  final places = [
    PointOfInterest(
      id: '1',
      name: 'Palais Epstein',
      address: 'Dr.-Karl-Renner-Ring',
      informationUrl: Uri.parse('https://www.parlament.gv.at'),
      latitude: 48.2066,
      longitude: 16.3586,
    ),
    const PointOfInterest(
      id: '2',
      name: 'Universität Wien',
      address: 'Universitätsring',
      latitude: 48.2131,
      longitude: 16.3600,
    ),
  ];

  testWidgets('PoiCatalogueScreen displays places and filters by query', (
    WidgetTester tester,
  ) async {
    final repo = _StubPoiRepository(() async => places);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PoiCatalogueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Palais Epstein'), findsOneWidget);
    expect(find.text('Universität Wien'), findsOneWidget);

    await tester.enterText(find.byType(SearchBar), 'Epstein');
    await tester.pumpAndSettle();

    expect(find.text('Palais Epstein'), findsOneWidget);
    expect(find.text('Universität Wien'), findsNothing);
  });

  testWidgets('PoiCatalogueScreen displays retry action when load fails', (
    WidgetTester tester,
  ) async {
    var shouldFail = true;
    final repo = _StubPoiRepository(() async {
      if (shouldFail) {
        throw const PoiDataException('Offline');
      }
      return places;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const PoiCatalogueScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load places'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    shouldFail = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.text('Palais Epstein'), findsOneWidget);
  });
}
