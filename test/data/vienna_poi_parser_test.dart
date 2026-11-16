import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/data/models/vienna_poi_dto.dart';
import 'package:poi_map_android/domain/entities/poi_marker_style.dart';

void main() {
  group('ViennaPoiParser', () {
    test('parses valid GeoJSON FeatureCollection records', () {
      final payload = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'SEHENSWUERDIGOGD.640963',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37367575, 48.21076056],
            },
            'properties': {
              'OBJECTID': 640963,
              'NAME': 'Ankeruhr',
              'ADRESSE': 'Hoher Markt 10/',
              'WEITERE_INF': 'http://www.wien.info/article.asp?IDArticle=2018',
              'THUMBNAIL':
                  'https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg',
            },
          },
          {
            'type': 'Feature',
            'id': 'SEHENSWUERDIGOGD.640964',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.40167012, 48.18297383],
            },
            'properties': {
              'OBJECTID': 640964,
              'NAME': 'Friedhof St. Marx',
              'ADRESSE': '  ',
              'WEITERE_INF': 'ftp://invalid.example.com',
              'THUMBNAIL': null,
            },
          },
        ],
      };

      final places = ViennaPoiParser.parseFeatureCollection(payload);

      expect(places, hasLength(2));
      expect(places[0].id, 'SEHENSWUERDIGOGD.640963');
      expect(places[0].name, 'Ankeruhr');
      expect(places[0].address, 'Hoher Markt 10/');
      expect(
        places[0].informationUrl?.toString(),
        'http://www.wien.info/article.asp?IDArticle=2018',
      );
      expect(PoiMarkerStyle.fromPoi(places[0]), PoiMarkerStyle.informationLink);

      expect(places[1].id, 'SEHENSWUERDIGOGD.640964');
      expect(places[1].address, isNull);
      expect(places[1].informationUrl, isNull);
      expect(PoiMarkerStyle.fromPoi(places[1]), PoiMarkerStyle.neutral);
    });

    test('skips incomplete or invalid records and deduplicates stable IDs', () {
      final payload = {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'missing-name',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 48.20],
            },
            'properties': {'OBJECTID': 1, 'NAME': '   '},
          },
          {
            'type': 'Feature',
            'id': 'bad-coords',
            'geometry': {
              'type': 'Point',
              'coordinates': [210.0, 48.20],
            },
            'properties': {'OBJECTID': 2, 'NAME': 'Out of range'},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 48.21],
            },
            'properties': {'OBJECTID': 42, 'NAME': 'Fallback ID Place'},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.38, 48.22],
            },
            'properties': {'OBJECTID': 42, 'NAME': 'Duplicate ID Place'},
          },
        ],
      };

      final places = ViennaPoiParser.parseFeatureCollection(payload);

      expect(places, hasLength(1));
      expect(places.single.id, '42');
      expect(places.single.name, 'Fallback ID Place');
    });

    test('throws PoiDataException when collection is malformed', () {
      expect(
        () => ViennaPoiParser.parseFeatureCollection({'type': 'Invalid'}),
        throwsA(isA<PoiDataException>()),
      );
    });
  });
}
