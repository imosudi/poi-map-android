import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:poi_map_android/app/router.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/favourites/data/datasources/favourites_local_storage.dart';
import 'package:poi_map_android/features/favourites/data/favourites_providers.dart';
import 'package:poi_map_android/features/favourites/data/repositories/local_favourites_repository.dart';
import 'package:poi_map_android/features/favourites/presentation/providers/favourites_provider.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/map/presentation/widgets/selected_poi_card.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';

final class _InMemoryKeyValueStorage implements KeyValueStorage {
  _InMemoryKeyValueStorage({this.failRead = false});

  final Map<String, String> _store = {};
  bool failRead;
  bool failWrite = false;

  @override
  Future<String?> getString(String key) async {
    if (failRead) {
      throw StateError('Disk read failed');
    }
    return _store[key];
  }

  @override
  Future<bool> setString(String key, String value) async {
    if (failWrite) {
      throw StateError('Disk write failed');
    }
    _store[key] = value;
    return true;
  }
}

final class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this._handler);

  final Future<List<Poi>> Function() _handler;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) => _handler();
}

void main() {
  const poiA = Poi(
    id: 'SEHENSWUERDIGOGD.1',
    name: 'Stephansdom',
    category: 'Sacred',
    latitude: 48.2085,
    longitude: 16.3731,
    address: 'Stephansplatz 3',
  );

  group('LocalFavouritesRepository persistence', () {
    test(
      'saves places, prevents duplicates, and persists across restarts',
      () async {
        final kv = _InMemoryKeyValueStorage();
        final repo1 = LocalFavouritesRepository(
          FavouritesLocalStorage(storage: kv),
        );

        expect(await repo1.loadSavedPlaces(), isEmpty);
        expect(await repo1.isSaved(poiA.id), isFalse);

        final afterSave = await repo1.savePlace(poiA);
        expect(afterSave, hasLength(1));
        expect(await repo1.isSaved(poiA.id), isTrue);

        final afterDuplicate = await repo1.savePlace(poiA);
        expect(afterDuplicate, hasLength(1));

        // Simulate app restart with a fresh storage and repository instance.
        final repo2 = LocalFavouritesRepository(
          FavouritesLocalStorage(storage: kv),
        );
        final reloaded = await repo2.loadSavedPlaces();
        expect(reloaded, hasLength(1));
        expect(reloaded.first.id, poiA.id);
        expect(reloaded.first.name, poiA.name);
        expect(reloaded.first.toPoi(), poiA);
      },
    );

    test('throws SavedPlacesException on read or write failures', () async {
      final kv = _InMemoryKeyValueStorage(failRead: true);
      final repo = LocalFavouritesRepository(
        FavouritesLocalStorage(storage: kv),
      );

      await expectLater(
        repo.loadSavedPlaces(),
        throwsA(isA<SavedPlacesException>()),
      );

      kv.failRead = false;
      kv.failWrite = true;
      await expectLater(
        repo.savePlace(poiA),
        throwsA(isA<SavedPlacesException>()),
      );
    });
  });

  group('Favourites Riverpod integration', () {
    test(
      'retains saved places when remote POI dataset is missing or fails',
      () async {
        final kv = _InMemoryKeyValueStorage();
        final storage = FavouritesLocalStorage(storage: kv);
        await LocalFavouritesRepository(storage).savePlace(poiA);

        final container = ProviderContainer(
          overrides: [
            favouritesStorageProvider.overrideWithValue(storage),
            poiRepositoryProvider.overrideWithValue(
              _FakePoiRepository(() async => const <Poi>[]),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(favouritesProvider.future);
        final resolved = container
            .read(resolvedSavedPlacesProvider)
            .asData
            ?.value;
        expect(resolved, [poiA]);
      },
    );

    test('preserves existing saved places when a new save fails', () async {
      final kv = _InMemoryKeyValueStorage();
      final storage = FavouritesLocalStorage(storage: kv);
      await LocalFavouritesRepository(storage).savePlace(poiA);

      final container = ProviderContainer(
        overrides: [favouritesStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container.read(favouritesProvider.future);
      kv.failWrite = true;

      const poiB = Poi(
        id: 'SEHENSWUERDIGOGD.2',
        name: 'Ankeruhr',
        latitude: 48.2108,
        longitude: 16.3737,
      );
      await container.read(favouritesProvider.notifier).savePoi(poiB);

      expect(container.read(savedPoiIdsProvider), {poiA.id});
      expect(
        container.read(favouritesFeedbackProvider),
        'Unable to save place to device storage.',
      );
    });
  });

  group('Synchronised favourites UI', () {
    testWidgets(
      'saving from catalogue updates catalogue badge, map selection card, and Saved Places',
      (WidgetTester tester) async {
        final kv = _InMemoryKeyValueStorage();
        final storage = FavouritesLocalStorage(storage: kv);
        Set<Marker> capturedMarkers = {};

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              favouritesStorageProvider.overrideWithValue(storage),
              poiRepositoryProvider.overrideWithValue(
                _FakePoiRepository(() async => const [poiA]),
              ),
              mapApiKeyConfiguredProvider.overrideWith((_) => false),
            ],
            child: MaterialApp(theme: AppTheme.light(), home: const AppShell()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byTooltip('Save place'), findsOneWidget);

        await tester.tap(find.byTooltip('Save place'));
        await tester.pumpAndSettle();

        expect(find.text('Saved Stephansdom'), findsOneWidget);
        expect(find.text('Saved'), findsNWidgets(2));

        ScaffoldMessenger.of(
          tester.element(find.byType(AppShell)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
        await tester.pumpAndSettle();
        expect(find.text('Saved Places (1)'), findsOneWidget);
        expect(find.text('Stephansdom'), findsOneWidget);

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('map-sync-scope'),
            overrides: [
              favouritesStorageProvider.overrideWithValue(storage),
              poiRepositoryProvider.overrideWithValue(
                _FakePoiRepository(() async => const [poiA]),
              ),
              mapApiKeyConfiguredProvider.overrideWith((_) => true),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: MapScreen(
                  isActive: false,
                  mapBuilder: (context, pos, markers, onMapCreated) {
                    capturedMarkers = markers;
                    return const ColoredBox(color: Colors.grey);
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        capturedMarkers.first.onTap?.call();
        await tester.pump();
        expect(find.byType(SelectedPoiCard), findsOneWidget);
        expect(find.text('Saved to places'), findsOneWidget);
      },
    );
  });
}
