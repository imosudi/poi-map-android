import 'package:flutter_test/flutter_test.dart';
import 'package:poi_map_android/core/errors/app_exception.dart';
import 'package:poi_map_android/features/poi/data/models/vienna_ogd_poi_dto.dart';
import 'package:poi_map_android/features/poi/domain/entities/poi.dart';

void main() {
  group('ViennaOgdFeatureCollectionDto & ViennaOgdPoiDto', () {
    test('parses valid Vienna OGD GeoJSON FeatureCollection', () {
      const rawJson = '''
      {
        "type": "FeatureCollection",
        "totalFeatures": 1,
        "numberReturned": 1,
        "timeStamp": "2026-11-17T22:00:00Z",
        "features": [
          {
            "type": "Feature",
            "id": "SEHENSWUERDIGOGD.643871",
            "geometry": {
              "type": "Point",
              "coordinates": [16.37367575, 48.21076056]
            },
            "geometry_name": "SHAPE",
            "properties": {
              "OBJECTID": 643871,
              "NAME": "Ankeruhr",
              "ADRESSE": "Hoher Markt 10/",
              "WEITERE_INF": "http://www.wien.info/article.asp?IDArticle=2018",
              "THUMBNAIL": "https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg",
              "SE_ANNO_CAD_DATA": null
            }
          }
        ]
      }
      ''';

      final collection = ViennaOgdFeatureCollectionDto.parseJsonString(rawJson);
      expect(collection.totalFeatures, 1);
      expect(collection.numberReturned, 1);
      expect(collection.skippedFeatureCount, 0);

      final pois = collection.toDomainList();
      expect(pois, hasLength(1));

      final poi = pois.first;
      expect(poi.id, 'SEHENSWUERDIGOGD.643871');
      expect(poi.name, 'Ankeruhr');
      expect(poi.longitude, closeTo(16.37367575, 1e-8));
      expect(poi.latitude, closeTo(48.21076056, 1e-8));
      expect(poi.address, 'Hoher Markt 10/');
      expect(
        poi.infoUrl,
        Uri.parse('http://www.wien.info/article.asp?IDArticle=2018'),
      );
      expect(
        poi.thumbnailUrl,
        Uri.parse('https://www.wien.gv.at/viennagis/bubble/ankeruhr.jpg'),
      );
      expect(poi.sourceObjectId, 643871);
    });

    test('handles missing optional fields and null values safely', () {
      final collection = ViennaOgdFeatureCollectionDto.fromJson({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'SEHENSWUERDIGOGD.100',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 48.20],
            },
            'properties': {
              'OBJECTID': null,
              'NAME': '  Stephansdom  ',
              'ADRESSE': '   ',
              'WEITERE_INF': null,
              'THUMBNAIL': 'not-a-valid-url',
            },
          },
        ],
      });

      final pois = collection.toDomainList();
      expect(pois, hasLength(1));
      final poi = pois.first;
      expect(poi.id, 'SEHENSWUERDIGOGD.100');
      expect(poi.name, 'Stephansdom');
      expect(poi.address, isNull);
      expect(poi.infoUrl, isNull);
      expect(poi.thumbnailUrl, isNull);
      expect(poi.sourceObjectId, isNull);
    });

    test('skips records with invalid coordinates or non-Point geometry', () {
      final collection = ViennaOgdFeatureCollectionDto.fromJson({
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'id': 'bad-lat',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 91.0],
            },
            'properties': {'NAME': 'Too North'},
          },
          {
            'type': 'Feature',
            'id': 'bad-lon',
            'geometry': {
              'type': 'Point',
              'coordinates': [-181.0, 48.20],
            },
            'properties': {'NAME': 'Too West'},
          },
          {
            'type': 'Feature',
            'id': 'short-coords',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37],
            },
            'properties': {'NAME': 'Missing Lat'},
          },
          {
            'type': 'Feature',
            'id': 'polygon',
            'geometry': {
              'type': 'Polygon',
              'coordinates': [
                [
                  [16.3, 48.2],
                ],
              ],
            },
            'properties': {'NAME': 'Not A Point'},
          },
        ],
      });

      expect(collection.features, isEmpty);
      expect(collection.skippedFeatureCount, 4);
      expect(Poi.isValidCoordinate(double.nan, 16.37), isFalse);
      expect(Poi.isValidCoordinate(48.20, double.infinity), isFalse);
    });

    test('skips records with unexpected data types or missing name', () {
      final collection = ViennaOgdFeatureCollectionDto.fromJson({
        'type': 'FeatureCollection',
        'features': [
          'not-a-map',
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': ['16.37', '48.20'],
            },
            'properties': {'NAME': 'String Coords'},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 48.20],
            },
            'properties': {'NAME': 12345},
          },
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [16.37, 48.20],
            },
            'properties': {'NAME': '   '},
          },
        ],
      });

      expect(collection.features, isEmpty);
      expect(collection.skippedFeatureCount, 4);
    });

    test('throws PoiDataException on malformed JSON or invalid root', () {
      expect(
        () => ViennaOgdFeatureCollectionDto.parseJsonString('{bad json'),
        throwsA(isA<PoiDataException>()),
      );
      expect(
        () => ViennaOgdFeatureCollectionDto.parseJsonString('[1, 2, 3]'),
        throwsA(isA<PoiDataException>()),
      );
      expect(
        () => ViennaOgdFeatureCollectionDto.parseJsonString(
          '{"type": "FeatureCollection"}',
        ),
        throwsA(isA<PoiDataException>()),
      );
    });

    test('generates stable identifiers with deterministic fallback', () {
      final fromObjectId = ViennaOgdPoiDto.tryFromJson({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [16.3728, 48.2082],
        },
        'properties': {'OBJECTID': 999, 'NAME': 'Schloss Belvedere'},
      })?.toDomain();

      expect(fromObjectId?.id, 'SEHENSWUERDIGOGD.999');

      final fallbackA = ViennaOgdPoiDto.tryFromJson({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [16.3728, 48.2082],
        },
        'properties': {'NAME': 'Schloss Belvedere'},
      })?.toDomain();

      final fallbackB = ViennaOgdPoiDto.tryFromJson({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [16.3728, 48.2082],
        },
        'properties': {'NAME': '  schloss belvedere '},
      })?.toDomain();

      expect(fallbackA, isNotNull);
      expect(fallbackA!.id, startsWith('poi_'));
      expect(fallbackA.id, fallbackB!.id);
    });
  });
}
