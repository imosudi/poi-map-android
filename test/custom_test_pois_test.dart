import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/features/poi/data/datasources/custom_test_pois.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';

void main() {
  test('CustomTestPois provides valid Vienna test entries', () {
    expect(CustomTestPois.entries.length, 2);

    final roetzergasse = CustomTestPois.entries.firstWhere(
      (p) => p.id == 'CUSTOM_TEST.ROETZERGASSE_73',
    );
    expect(roetzergasse.address, 'Rötzergasse 73, 1170 Wien');
    expect(
      Poi.isValidCoordinate(roetzergasse.latitude, roetzergasse.longitude),
      isTrue,
    );

    final fhtw = CustomTestPois.entries.firstWhere(
      (p) => p.id == 'CUSTOM_TEST.FHTW_WIEN',
    );
    expect(fhtw.address, 'Höchstädtplatz 6, 1200 Wien');
    expect(Poi.isValidCoordinate(fhtw.latitude, fhtw.longitude), isTrue);
  });
}

