import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/utils/distance_calculator.dart';
import 'package:poi_map_android/domain/entities/geo_coordinate.dart';
import 'package:poi_map_android/domain/entities/point_of_interest.dart';

void main() {
  group('DistanceCalculator', () {
    test('computes realistic distance between Vienna landmarks', () {
      const stephansdom = GeoCoordinate(latitude: 48.2085, longitude: 16.3731);
      const belvedere = PointOfInterest(
        id: 'belvedere',
        name: 'Unteres Belvedere',
        latitude: 48.1915,
        longitude: 16.3808,
      );

      final meters = DistanceCalculator.distanceToPoi(
        userCoordinate: stephansdom,
        poi: belvedere,
      );

      expect(meters, isNotNull);
      expect(meters!, inInclusiveRange(1850, 2100));
    });

    test('returns null for invalid coordinates', () {
      const invalid = GeoCoordinate(latitude: 95.0, longitude: 16.37);
      const valid = GeoCoordinate(latitude: 48.20, longitude: 16.37);

      expect(
        DistanceCalculator.distanceMeters(from: invalid, to: valid),
        isNull,
      );
    });

    test('formats metres and kilometres consistently', () {
      expect(DistanceCalculator.formatMeters(420.4), '420 m');
      expect(DistanceCalculator.formatMeters(999.4), '999 m');
      expect(DistanceCalculator.formatMeters(999.6), '1.0 km');
      expect(DistanceCalculator.formatMeters(2340), '2.3 km');
      expect(DistanceCalculator.formatMeters(-5), isNull);
    });
  });
}
