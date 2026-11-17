import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/core/widgets/app_empty_view.dart';
import 'package:poi_map_android/core/widgets/app_error_view.dart';
import 'package:poi_map_android/core/widgets/app_loading_view.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/screens/poi_catalogue_screen.dart';
import 'package:poi_map_android/features/poi/presentation/widgets/poi_list_item.dart';

final class _QueuedPoiRepository implements PoiRepository {
  _QueuedPoiRepository(this._handlers);

  final List<Future<List<Poi>> Function()> _handlers;
  int callCount = 0;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) {
    final index = callCount < _handlers.length
        ? callCount
        : _handlers.length - 1;
    callCount++;
    return _handlers[index]();
  }
}

Widget _wrapScreen(PoiRepository repository) {
  return ProviderScope(
    overrides: [poiRepositoryProvider.overrideWithValue(repository)],
    child: MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: PoiCatalogueScreen()),
    ),
  );
}

List<Poi> _samplePois(int count) {
  return List<Poi>.generate(
    count,
    (index) => Poi(
      id: 'SEHENSWUERDIGOGD.$index',
      name: 'Vienna Sight $index',
      latitude: 48.2 + index * 0.0001,
      longitude: 16.37,
      address: 'Ringstrasse $index',
    ),
  );
}

void main() {
  testWidgets('shows loading state initially then renders POIs', (
    WidgetTester tester,
  ) async {
    final completer = Completer<List<Poi>>();
    final repo = _QueuedPoiRepository([() => completer.future]);

    await tester.pumpWidget(_wrapScreen(repo));
    await tester.pump();

    expect(find.byType(AppLoadingView), findsOneWidget);
    expect(find.text('Loading Vienna sights...'), findsOneWidget);

    completer.complete(_samplePois(2));
    await tester.pumpAndSettle();

    expect(find.byType(PoiListItem), findsNWidgets(2));
    expect(find.text('Vienna Sight 0'), findsOneWidget);
    expect(find.text('Ringstrasse 0'), findsOneWidget);
    expect(find.text('2 sights in Vienna'), findsOneWidget);
  });

  testWidgets('renders empty state when repository returns no POIs', (
    WidgetTester tester,
  ) async {
    final repo = _QueuedPoiRepository([() async => const <Poi>[]]);

    await tester.pumpWidget(_wrapScreen(repo));
    await tester.pumpAndSettle();

    expect(find.byType(AppEmptyView), findsOneWidget);
    expect(find.text('No places available'), findsOneWidget);
  });

  testWidgets('renders error state and retries on button tap', (
    WidgetTester tester,
  ) async {
    final repo = _QueuedPoiRepository([
      () async => throw const NetworkException('No internet connection.'),
      () async => _samplePois(1),
    ]);

    await tester.pumpWidget(_wrapScreen(repo));
    await tester.pumpAndSettle();

    expect(find.byType(AppErrorView), findsOneWidget);
    expect(find.text('No internet connection.'), findsOneWidget);
    expect(repo.callCount, 1);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(repo.callCount, 2);
    expect(find.byType(PoiListItem), findsOneWidget);
    expect(find.text('Vienna Sight 0'), findsOneWidget);
  });

  testWidgets(
    'lazily renders long POI lists without building off-screen items',
    (WidgetTester tester) async {
      final repo = _QueuedPoiRepository([() async => _samplePois(500)]);

      await tester.pumpWidget(_wrapScreen(repo));
      await tester.pumpAndSettle();

      expect(find.text('500 sights in Vienna'), findsOneWidget);
      expect(find.text('Vienna Sight 0'), findsOneWidget);
      expect(find.text('Vienna Sight 499'), findsNothing);
    },
  );

  testWidgets('renders cleanly on small Android screens without overflow', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _QueuedPoiRepository([
      () async => const [
        Poi(
          id: 'long-name',
          name:
              'Kunsthistorisches Museum Wien mit sehr langem Titel fuer kleine Bildschirme',
          latitude: 48.2038,
          longitude: 16.3614,
          address: 'Maria-Theresien-Platz, 1010 Wien, Oesterreich',
        ),
      ],
    ]);

    await tester.pumpWidget(_wrapScreen(repo));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(PoiListItem), findsOneWidget);
  });

  testWidgets('searches, filters by category, clears, and shows no-results', (
    WidgetTester tester,
  ) async {
    final repo = _QueuedPoiRepository([
      () async => const [
        Poi(
          id: '1',
          name: 'Stephansdom',
          category: 'Landmark',
          latitude: 48.2085,
          longitude: 16.3731,
        ),
        Poi(
          id: '2',
          name: 'Kunsthistorisches Museum',
          category: 'Museum',
          latitude: 48.2038,
          longitude: 16.3614,
        ),
      ],
    ]);

    await tester.pumpWidget(_wrapScreen(repo));
    await tester.pumpAndSettle();

    expect(find.byType(PoiListItem), findsNWidgets(2));
    expect(find.text('Landmark'), findsNWidgets(2));
    expect(find.text('Museum'), findsNWidgets(2));

    await tester.enterText(find.byType(TextField), '  stephans ');
    await tester.pumpAndSettle();
    expect(find.byType(PoiListItem), findsOneWidget);
    expect(find.text('Stephansdom'), findsOneWidget);
    expect(find.text('1 of 2 sights'), findsOneWidget);
    expect(repo.callCount, 1);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiListItem), findsNWidgets(2));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Museum'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiListItem), findsOneWidget);
    expect(find.text('Kunsthistorisches Museum'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'stephans');
    await tester.pumpAndSettle();
    expect(find.text('No matching sights'), findsOneWidget);

    await tester.tap(find.text('Clear filters'));
    await tester.pumpAndSettle();
    expect(find.byType(PoiListItem), findsNWidgets(2));
    expect(repo.callCount, 1);
  });
}
