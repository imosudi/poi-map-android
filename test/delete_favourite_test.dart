import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/app/router.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/favourites/data/datasources/favourites_local_storage.dart';
import 'package:poi_map_android/features/favourites/data/favourites_providers.dart';
import 'package:poi_map_android/features/favourites/data/repositories/local_favourites_repository.dart';
import 'package:poi_map_android/features/favourites/domain/entities/saved_place.dart';
import 'package:poi_map_android/features/favourites/domain/repositories/favourites_repository.dart';
import 'package:poi_map_android/features/favourites/presentation/providers/favourites_provider.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';

final class _InMemoryKeyValueStorage implements KeyValueStorage {
  final Map<String, String> _store = {};
  bool failWrite = false;
  int writeCount = 0;

  @override
  Future<String?> getString(String key) async => _store[key];

  @override
  Future<bool> setString(String key, String value) async {
    writeCount++;
    if (failWrite) {
      throw StateError('Disk write failed');
    }
    _store[key] = value;
    return true;
  }
}

final class _SlowRemoveRepository implements FavouritesRepository {
  _SlowRemoveRepository(this._initial, this._completer);

  final List<SavedPlace> _initial;
  final Completer<List<SavedPlace>> _completer;
  int removeCalls = 0;

  @override
  Future<List<SavedPlace>> loadSavedPlaces() async => _initial;

  @override
  Future<bool> isSaved(String poiId) async =>
      _initial.any((p) => p.id == poiId);

  @override
  Future<List<SavedPlace>> savePlace(Poi poi) async => _initial;

  @override
  Future<List<SavedPlace>> removePlace(String poiId) {
    removeCalls++;
    return _completer.future;
  }
}

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this._items);

  final List<Poi> _items;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async => _items;
}

void main() {
  const poiA = Poi(
    id: 'SEHENSWUERDIGOGD.1',
    name: 'Stephansdom',
    category: 'Sacred',
    latitude: 48.2085,
    longitude: 16.3731,
  );
  const poiB = Poi(
    id: 'SEHENSWUERDIGOGD.2',
    name: 'Kunsthistorisches Museum',
    category: 'Museum',
    latitude: 48.2038,
    longitude: 16.3614,
  );

  group('LocalFavouritesRepository.removePlace', () {
    test(
      'removes target, preserves others, ignores unknown id, and persists',
      () async {
        final kv = _InMemoryKeyValueStorage();
        final repo1 = LocalFavouritesRepository(
          FavouritesLocalStorage(storage: kv),
        );

        await repo1.savePlace(poiA);
        await repo1.savePlace(poiB);
        final writesBefore = kv.writeCount;

        final afterUnknown = await repo1.removePlace('unknown-id');
        expect(afterUnknown, hasLength(2));
        expect(kv.writeCount, writesBefore);

        final afterRemove = await repo1.removePlace(poiA.id);
        expect(afterRemove.map((p) => p.id), [poiB.id]);
        expect(await repo1.isSaved(poiA.id), isFalse);
        expect(await repo1.isSaved(poiB.id), isTrue);

        // Simulate restart with fresh storage/repository instances.
        final repo2 = LocalFavouritesRepository(
          FavouritesLocalStorage(storage: kv),
        );
        final reloaded = await repo2.loadSavedPlaces();
        expect(reloaded.map((p) => p.id), [poiB.id]);
      },
    );

    test('throws SavedPlacesException when storage write fails', () async {
      final kv = _InMemoryKeyValueStorage();
      final repo = LocalFavouritesRepository(
        FavouritesLocalStorage(storage: kv),
      );

      await repo.savePlace(poiA);
      kv.failWrite = true;

      await expectLater(
        repo.removePlace(poiA.id),
        throwsA(isA<SavedPlacesException>()),
      );
      expect((await repo.loadSavedPlaces()).map((p) => p.id), [poiA.id]);
    });
  });

  group('FavouritesController.removePoi', () {
    test('deduplicates concurrent removal requests for the same POI', () async {
      final completer = Completer<List<SavedPlace>>();
      final slowRepo = _SlowRemoveRepository([
        SavedPlace.fromPoi(poiA),
      ], completer);
      final container = ProviderContainer(
        overrides: [favouritesRepositoryProvider.overrideWithValue(slowRepo)],
      );
      addTearDown(container.dispose);

      await container.read(favouritesProvider.future);
      final notifier = container.read(favouritesProvider.notifier);

      final first = notifier.removePoi(poiA);
      final second = notifier.removePoi(poiA);

      completer.complete(const <SavedPlace>[]);
      expect(await first, isTrue);
      expect(await second, isFalse);
      expect(slowRepo.removeCalls, 1);
    });

    test(
      'preserves saved places and emits feedback on storage failure',
      () async {
        final kv = _InMemoryKeyValueStorage();
        final storage = FavouritesLocalStorage(storage: kv);
        await LocalFavouritesRepository(storage).savePlace(poiA);

        final container = ProviderContainer(
          overrides: [favouritesStorageProvider.overrideWithValue(storage)],
        );
        addTearDown(container.dispose);

        await container.read(favouritesProvider.future);
        kv.failWrite = true;

        final ok = await container
            .read(favouritesProvider.notifier)
            .removePoi(poiA);
        expect(ok, isFalse);
        expect(container.read(savedPoiIdsProvider), {poiA.id});
        expect(
          container.read(favouritesFeedbackProvider),
          'Unable to save place to device storage.',
        );
      },
    );

    test('does not affect remote catalogue POIs', () async {
      final kv = _InMemoryKeyValueStorage();
      final storage = FavouritesLocalStorage(storage: kv);
      await LocalFavouritesRepository(storage).savePlace(poiA);

      final container = ProviderContainer(
        overrides: [
          favouritesStorageProvider.overrideWithValue(storage),
          poiRepositoryProvider.overrideWithValue(
            _FakePoiRepository(const [poiA, poiB]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(favouritesProvider.future);
      await container.read(poiCatalogueProvider.future);

      await container.read(favouritesProvider.notifier).removePoi(poiA);
      expect(container.read(savedPoiIdsProvider), isEmpty);
      expect(container.read(poiCatalogueProvider).asData?.value, const [
        poiA,
        poiB,
      ]);
    });
  });

  group('Saved Places deletion confirmation UI', () {
    testWidgets(
      'confirms, cancels, and removes individual favourite while preserving catalogue',
      (WidgetTester tester) async {
        final kv = _InMemoryKeyValueStorage();
        final storage = FavouritesLocalStorage(storage: kv);
        final repo = LocalFavouritesRepository(storage);
        await repo.savePlace(poiA);
        await repo.savePlace(poiB);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              favouritesStorageProvider.overrideWithValue(storage),
              poiRepositoryProvider.overrideWithValue(
                _FakePoiRepository(const [poiA, poiB]),
              ),
              mapApiKeyConfiguredProvider.overrideWith((_) => false),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: const AppShell(initialIndex: 2),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Saved Places (2)'), findsOneWidget);
        expect(find.byTooltip('Remove saved place'), findsNWidgets(2));

        // Tap remove on first item and cancel.
        await tester.tap(find.byTooltip('Remove saved place').first);
        await tester.pumpAndSettle();

        expect(find.text('Remove saved place?'), findsOneWidget);
        expect(find.textContaining('Cancel'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        expect(find.text('Saved Places (2)'), findsOneWidget);

        // Tap remove again and confirm.
        await tester.tap(find.byTooltip('Remove saved place').first);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Saved Places (1)'), findsOneWidget);

        // Catalogue still has both POIs, with one reverted to Save place.
        ScaffoldMessenger.of(
          tester.element(find.byType(AppShell)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('Explore'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Stephansdom'), findsOneWidget);
        expect(find.text('Kunsthistorisches Museum'), findsOneWidget);
        expect(find.byTooltip('Save place'), findsOneWidget);
      },
    );
  });
}
