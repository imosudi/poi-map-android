import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/domain/services/poi_filter.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';

final class _CountingPoiRepository implements PoiRepository {
  _CountingPoiRepository(this._items);

  final List<Poi> _items;
  int fetchCount = 0;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    fetchCount++;
    return _items;
  }
}

void main() {
  const samplePois = [
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
    Poi(
      id: '3',
      name: 'Schloss Belvedere',
      category: 'Museum',
      latitude: 48.1915,
      longitude: 16.3809,
    ),
    Poi(id: '4', name: 'Ankeruhr', latitude: 48.2108, longitude: 16.3737),
  ];

  group('PoiFilter', () {
    test('returns original dataset for empty or whitespace-only queries', () {
      expect(
        PoiFilter.apply(samplePois, const PoiFilterCriteria()),
        same(samplePois),
      );
      expect(
        PoiFilter.apply(samplePois, const PoiFilterCriteria(query: '   ')),
        same(samplePois),
      );
    });

    test('matches names case-insensitively and trims whitespace', () {
      final result = PoiFilter.apply(
        samplePois,
        const PoiFilterCriteria(query: '  belvedere  '),
      );
      expect(result.map((p) => p.id), ['3']);
    });

    test('extracts sorted distinct categories and filters by category', () {
      expect(PoiFilter.extractCategories(samplePois), ['Landmark', 'Museum']);

      final museums = PoiFilter.apply(
        samplePois,
        const PoiFilterCriteria(category: 'museum'),
      );
      expect(museums.map((p) => p.id), ['2', '3']);
    });

    test('combines search query and category filter', () {
      final result = PoiFilter.apply(
        samplePois,
        const PoiFilterCriteria(query: 'kunst', category: 'Museum'),
      );
      expect(result.map((p) => p.id), ['2']);
    });

    test('returns empty list when no POIs match', () {
      final result = PoiFilter.apply(
        samplePois,
        const PoiFilterCriteria(query: 'prater', category: 'Museum'),
      );
      expect(result, isEmpty);
    });
  });

  group('Catalogue filter providers', () {
    test('filters locally without triggering extra network requests', () async {
      final repo = _CountingPoiRepository(samplePois);
      final container = ProviderContainer(
        overrides: [poiRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(poiCatalogueProvider.future);
      expect(repo.fetchCount, 1);

      final filterNotifier = container.read(poiFilterCriteriaProvider.notifier);
      filterNotifier.setQuery('  museum ');
      expect(
        container.read(filteredPoisProvider).asData?.value.map((p) => p.id),
        ['2'],
      );

      filterNotifier.setCategory('Landmark');
      expect(container.read(filteredPoisProvider).asData?.value, isEmpty);

      filterNotifier.clearAll();
      expect(container.read(filteredPoisProvider).asData?.value, hasLength(4));
      expect(repo.fetchCount, 1);
    });
  });
}
