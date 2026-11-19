import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:poi_map_android/app/theme/app_theme.dart';
import 'package:poi_map_android/core/network/cancellation_token.dart';
import 'package:poi_map_android/features/map/presentation/mappers/poi_marker_builder.dart';
import 'package:poi_map_android/features/map/presentation/providers/map_providers.dart';
import 'package:poi_map_android/features/map/presentation/screens/map_screen.dart';
import 'package:poi_map_android/features/map/presentation/widgets/selected_poi_card.dart';
import 'package:poi_map_android/features/poi/data/poi_providers.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';
import 'package:poi_map_android/features/poi/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/features/poi/presentation/providers/poi_catalogue_provider.dart';

final class _ScriptedPoiRepository implements PoiRepository {
  _ScriptedPoiRepository(this._batches);

  final List<List<Poi>> _batches;
  int _index = 0;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    final batch =
        _batches[_index < _batches.length ? _index : _batches.length - 1];
    _index++;
    return batch;
  }
}

void main() {
  const poiA = Poi(
    id: 'SEHENSWUERDIGOGD.1',
    name: 'Stephansdom',
    category: 'Landmark',
    latitude: 48.2085,
    longitude: 16.3731,
    address: 'Stephansplatz 3',
  );
  const poiB = Poi(
    id: 'SEHENSWUERDIGOGD.2',
    name: 'Kunsthistorisches Museum',
    category: 'Museum',
    latitude: 48.2038,
    longitude: 16.3614,
    address: 'Maria-Theresien-Platz',
  );

  group('PoiMarkerBuilder', () {
    test('skips invalid coordinates and deduplicates by POI id', () {
      const invalidLat = Poi(
        id: 'bad-lat',
        name: 'Invalid Lat',
        latitude: 95.0,
        longitude: 16.37,
      );
      const nanLon = Poi(
        id: 'bad-lon',
        name: 'NaN Lon',
        latitude: 48.20,
        longitude: double.nan,
      );
      const duplicateA = Poi(
        id: 'SEHENSWUERDIGOGD.1',
        name: 'Stephansdom Duplicate',
        latitude: 48.2085,
        longitude: 16.3731,
      );

      final markers = PoiMarkerBuilder.build(
        pois: [poiA, invalidLat, nanLon, duplicateA, poiB],
        selectedPoiId: poiB.id,
      );

      expect(markers, hasLength(2));
      final ids = markers.map((m) => m.markerId.value).toSet();
      expect(ids, {poiA.id, poiB.id});

      final selectedMarker = markers.firstWhere(
        (m) => m.markerId.value == poiB.id,
      );
      expect(selectedMarker.zIndexInt, 1);
      expect(selectedMarker.position, LatLng(poiB.latitude, poiB.longitude));
    });
  });

  group('Selected POI state consistency', () {
    test(
      'selectedMapPoiProvider stays consistent across catalogue refreshes',
      () async {
        const updatedPoiA = Poi(
          id: 'SEHENSWUERDIGOGD.1',
          name: 'Stephansdom (Updated)',
          latitude: 48.2085,
          longitude: 16.3731,
        );

        final repo = _ScriptedPoiRepository([
          [poiA, poiB],
          [updatedPoiA],
        ]);
        final container = ProviderContainer(
          overrides: [poiRepositoryProvider.overrideWithValue(repo)],
        );
        addTearDown(container.dispose);

        await container.read(poiCatalogueProvider.future);
        container.read(selectedPoiIdProvider.notifier).select(poiA.id);
        expect(container.read(selectedMapPoiProvider), poiA);

        await container.read(poiCatalogueProvider.notifier).refresh();
        expect(container.read(selectedMapPoiProvider), updatedPoiA);

        container.read(selectedPoiIdProvider.notifier).select(poiB.id);
        expect(container.read(selectedMapPoiProvider), isNull);
      },
    );
  });

  group('MapScreen marker selection and dismissal', () {
    testWidgets(
      'selects marker, switches between markers, and dismisses selection card',
      (WidgetTester tester) async {
        final repo = _ScriptedPoiRepository([
          [poiA, poiB],
        ]);
        Set<Marker> capturedMarkers = {};

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              poiRepositoryProvider.overrideWithValue(repo),
              mapApiKeyConfiguredProvider.overrideWith((_) => true),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: MapScreen(
                  mapBuilder:
                      (context, initialPosition, markers, onMapCreated) {
                        capturedMarkers = markers;
                        return const ColoredBox(
                          key: Key('stub-map'),
                          color: Colors.grey,
                        );
                      },
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(capturedMarkers, hasLength(2));
        expect(find.byType(SelectedPoiCard), findsNothing);

        capturedMarkers
            .firstWhere((m) => m.markerId.value == poiA.id)
            .onTap
            ?.call();
        await tester.pump();

        expect(find.byType(SelectedPoiCard), findsOneWidget);
        expect(find.text('Stephansdom'), findsOneWidget);
        expect(find.text('Landmark'), findsOneWidget);
        expect(find.text('Stephansplatz 3'), findsOneWidget);

        capturedMarkers
            .firstWhere((m) => m.markerId.value == poiB.id)
            .onTap
            ?.call();
        await tester.pump();

        expect(find.byType(SelectedPoiCard), findsOneWidget);
        expect(find.text('Kunsthistorisches Museum'), findsOneWidget);
        expect(find.text('Stephansdom'), findsNothing);

        await tester.tap(find.byTooltip('Dismiss'));
        await tester.pump();

        expect(find.byType(SelectedPoiCard), findsNothing);
      },
    );
  });
}
