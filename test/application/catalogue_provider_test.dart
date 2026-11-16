import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/application/providers/catalogue_provider.dart';
import 'package:poi_map_android/application/state/catalogue_state.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/domain/entities/point_of_interest.dart';
import 'package:poi_map_android/domain/repositories/poi_repository.dart';

class _FakePoiRepository implements PoiRepository {
  _FakePoiRepository(this._handler);

  final Future<List<PointOfInterest>> Function() _handler;

  @override
  Future<List<PointOfInterest>> fetchPointsOfInterest() => _handler();
}

void main() {
  final samplePlaces = [
    PointOfInterest(
      id: '1',
      name: 'Unteres Belvedere',
      address: 'Rennweg 6',
      informationUrl: Uri.parse('https://www.belvedere.at'),
      latitude: 48.1915,
      longitude: 16.3808,
    ),
    const PointOfInterest(
      id: '2',
      name: 'Wotrubakirche',
      address: 'Rysergasse',
      latitude: 48.1489,
      longitude: 16.2581,
    ),
    PointOfInterest(
      id: '3',
      name: 'Stephansdom',
      informationUrl: Uri.parse('https://www.stephanskirche.at'),
      latitude: 48.2085,
      longitude: 16.3731,
    ),
  ];

  group('CatalogueNotifier', () {
    test('loads places, filters by search and quick filter', () async {
      final repo = _FakePoiRepository(() async => samplePlaces);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(catalogueProvider.notifier).loadIfNeeded();
      var state = container.read(catalogueProvider);
      expect(state.status, CatalogueStatus.loaded);
      expect(state.filteredPlaces, hasLength(3));

      container.read(catalogueProvider.notifier).setSearchQuery('rennweg');
      state = container.read(catalogueProvider);
      expect(state.filteredPlaces.map((p) => p.id), ['1']);

      container.read(catalogueProvider.notifier).setSearchQuery('');
      container
          .read(catalogueProvider.notifier)
          .setQuickFilter(QuickFilter.withWebsite);
      state = container.read(catalogueProvider);
      expect(state.filteredPlaces.map((p) => p.id), ['1', '3']);

      container
          .read(catalogueProvider.notifier)
          .setQuickFilter(QuickFilter.withAddress);
      state = container.read(catalogueProvider);
      expect(state.filteredPlaces.map((p) => p.id), ['1', '2']);
    });

    test('retries after initial failure', () async {
      var shouldFail = true;
      final repo = _FakePoiRepository(() async {
        if (shouldFail) {
          throw const PoiDataException('Network unreachable');
        }
        return samplePlaces;
      });
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(catalogueProvider.notifier).loadIfNeeded();
      expect(container.read(catalogueProvider).status, CatalogueStatus.failed);

      shouldFail = false;
      await container.read(catalogueProvider.notifier).retry();
      expect(container.read(catalogueProvider).status, CatalogueStatus.loaded);
      expect(container.read(catalogueProvider).places, hasLength(3));
    });

    test('preserves existing places when refresh fails', () async {
      var shouldFail = false;
      final repo = _FakePoiRepository(() async {
        if (shouldFail) {
          throw const PoiDataException('Temporary timeout');
        }
        return samplePlaces;
      });
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(catalogueProvider.notifier).loadIfNeeded();
      shouldFail = true;
      await container.read(catalogueProvider.notifier).refresh();

      final state = container.read(catalogueProvider);
      expect(state.status, CatalogueStatus.loaded);
      expect(state.places, hasLength(3));
      expect(state.refreshError, contains('Could not refresh places'));
    });
  });
}
