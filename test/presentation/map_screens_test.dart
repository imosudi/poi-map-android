import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/application/providers/catalogue_provider.dart';
import 'package:poi_map_android/application/providers/location_provider.dart';
import 'package:poi_map_android/core/theme/app_theme.dart';
import 'package:poi_map_android/data/services/location_service.dart';
import 'package:poi_map_android/domain/entities/geo_coordinate.dart';
import 'package:poi_map_android/domain/entities/point_of_interest.dart';
import 'package:poi_map_android/domain/repositories/poi_repository.dart';
import 'package:poi_map_android/presentation/screens/all_places_map_screen.dart';
import 'package:poi_map_android/presentation/screens/poi_detail_map_screen.dart';

class _StubRepo implements PoiRepository {
  _StubRepo(this.places);

  final List<PointOfInterest> places;

  @override
  Future<List<PointOfInterest>> fetchPointsOfInterest() async => places;
}

class _StubLocation implements LocationService {
  @override
  Future<LocationLookupResult> getCurrentLocation({
    bool requestPermission = true,
  }) async {
    return const LocationLookupResult(
      outcome: LocationLookupOutcome.success,
      coordinate: GeoCoordinate(latitude: 48.2085, longitude: 16.3731),
    );
  }

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

void main() {
  final validPoi = PointOfInterest(
    id: 'belvedere',
    name: 'Unteres Belvedere',
    address: 'Rennweg 6',
    informationUrl: Uri.parse('https://www.belvedere.at'),
    latitude: 48.1915,
    longitude: 16.3808,
  );
  const invalidPoi = PointOfInterest(
    id: 'invalid',
    name: 'Invalid Coordinate POI',
    latitude: 120.0,
    longitude: 16.0,
  );

  testWidgets('AllPlacesMapScreen filters invalid markers and shows callout', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          poiRepositoryProvider.overrideWithValue(
            _StubRepo([validPoi, invalidPoi]),
          ),
          locationServiceProvider.overrideWithValue(_StubLocation()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AllPlacesMapScreen(
            mapBuilder: (context, camera, markers, myLocationEnabled) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Markers: ${markers.length}'),
                  for (final marker in markers)
                    ElevatedButton(
                      onPressed: marker.onTap,
                      child: Text('Select ${marker.markerId.value}'),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Markers: 1'), findsOneWidget);

    await tester.tap(find.text('Select belvedere'));
    await tester.pumpAndSettle();

    expect(find.text('Unteres Belvedere'), findsOneWidget);
    expect(find.text('Rennweg 6'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
  });

  testWidgets('PoiDetailMapScreen renders selected POI and distance', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [locationServiceProvider.overrideWithValue(_StubLocation())],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: PoiDetailMapScreen(
            selectedPlace: validPoi,
            mapBuilder: (_, camera, markers, _) {
              return Center(child: Text('Zoom: ${camera.zoom}'));
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unteres Belvedere'), findsWidgets);
    expect(find.text('Rennweg 6'), findsOneWidget);
    expect(find.textContaining('km away'), findsOneWidget);
    expect(find.text('More information'), findsOneWidget);
  });
}
