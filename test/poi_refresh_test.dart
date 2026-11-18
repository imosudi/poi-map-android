import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';
import 'package:poi_map_android/features/poi/presentation/screens/poi_catalogue_screen.dart';
import 'package:poi_map_android/features/poi/presentation/widgets/poi_list_item.dart';

final class _ScriptedPoiRepository implements PoiRepository {
  _ScriptedPoiRepository(this._handlers);

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

void main() {
  const initialPois = [
    Poi(
      id: 'SEHENSWUERDIGOGD.1',
      name: 'Stephansdom',
      category: 'Landmark',
      latitude: 48.2085,
      longitude: 16.3731,
    ),
    Poi(
      id: 'SEHENSWUERDIGOGD.2',
      name: 'Ankeruhr',
      category: 'Landmark',
      latitude: 48.2108,
      longitude: 16.3737,
    ),
  ];

  const refreshedPois = [
    Poi(
      id: 'SEHENSWUERDIGOGD.1',
      name: 'Stephansdom',
      category: 'Landmark',
      latitude: 48.2085,
      longitude: 16.3731,
    ),
    Poi(
      id: 'SEHENSWUERDIGOGD.3',
      name: 'Schloss Belvedere',
      category: 'Museum',
      latitude: 48.1915,
      longitude: 16.3809,
    ),
  ];

  group('PoiCatalogueController refresh workflow', () {
    test('loads initial data and updates on successful refresh', () async {
      final repo = _ScriptedPoiRepository([
        () async => initialPois,
        () async => refreshedPois,
      ]);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final initial = await container.read(poiCatalogueProvider.future);
      expect(initial.map((p) => p.id), [
        'SEHENSWUERDIGOGD.1',
        'SEHENSWUERDIGOGD.2',
      ]);

      await container.read(poiCatalogueProvider.notifier).refresh();
      final updated = container.read(poiCatalogueProvider).asData?.value;
      expect(updated?.map((p) => p.id), [
        'SEHENSWUERDIGOGD.1',
        'SEHENSWUERDIGOGD.3',
      ]);
      expect(container.read(poiRefreshStatusProvider).errorMessage, isNull);
    });

    test('preserves existing data when refresh fails', () async {
      final repo = _ScriptedPoiRepository([
        () async => initialPois,
        () async => throw const NetworkException('Refresh timed out.'),
      ]);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(poiCatalogueProvider.future);
      await container.read(poiCatalogueProvider.notifier).refresh();

      final preserved = container.read(poiCatalogueProvider).asData?.value;
      expect(preserved, initialPois);
      final refreshStatus = container.read(poiRefreshStatusProvider);
      expect(refreshStatus.isRefreshing, isFalse);
      expect(refreshStatus.errorMessage, 'Refresh timed out.');
    });

    test('deduplicates concurrent refresh requests', () async {
      final refreshCompleter = Completer<List<Poi>>();
      final repo = _ScriptedPoiRepository([
        () async => initialPois,
        () => refreshCompleter.future,
      ]);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(poiCatalogueProvider.future);
      expect(repo.callCount, 1);

      final notifier = container.read(poiCatalogueProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      expect(repo.callCount, 2);

      refreshCompleter.complete(refreshedPois);
      await Future.wait([first, second]);
      expect(repo.callCount, 2);
    });

    test('handles refresh returning an empty dataset', () async {
      final repo = _ScriptedPoiRepository([
        () async => initialPois,
        () async => const <Poi>[],
      ]);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(poiCatalogueProvider.future);
      await container.read(poiCatalogueProvider.notifier).refresh();

      expect(container.read(poiCatalogueProvider).asData?.value, isEmpty);
    });

    test(
      'keeps search and category filtering consistent after refresh',
      () async {
        final repo = _ScriptedPoiRepository([
          () async => initialPois,
          () async => refreshedPois,
        ]);
        final container = ProviderContainer(
          overrides: [poiRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await container.read(poiCatalogueProvider.future);
        final filterNotifier = container.read(
          poiFilterCriteriaProvider.notifier,
        );
        filterNotifier.setQuery('stephans');
        filterNotifier.setCategory('Landmark');

        await container.read(poiCatalogueProvider.notifier).refresh();
        final filtered = container.read(filteredPoisProvider).asData?.value;
        expect(filtered?.map((p) => p.id), ['SEHENSWUERDIGOGD.1']);
      },
    );
  });

  group('PoiCatalogueScreen refresh UI', () {
    testWidgets(
      'preserves existing list during refresh and shows SnackBar on failure',
      (WidgetTester tester) async {
        final refreshCompleter = Completer<List<Poi>>();
        final repo = _ScriptedPoiRepository([
          () async => initialPois,
          () => refreshCompleter.future,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [poiRepositoryProvider.overrideWithValue(repo)],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: PoiCatalogueScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(PoiListItem), findsNWidgets(2));

        await tester.tap(find.byTooltip('Refresh'));
        await tester.pump();

        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        expect(find.byType(PoiListItem), findsNWidgets(2));

        refreshCompleter.completeError(
          const NetworkException('Unable to reach server.'),
        );
        await tester.pumpAndSettle();

        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byType(PoiListItem), findsNWidgets(2));
        expect(find.text('Unable to reach server.'), findsOneWidget);
      },
    );
  });
}
