import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/errors/app_exception.dart';
import '../../domain/entities/point_of_interest.dart';
import '../models/vienna_poi_dto.dart';

/// Fetches Vienna Open Government Data sights via WFS GeoJSON.
class ViennaPoiService {
  ViennaPoiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              headers: const {'Accept': 'application/json'},
            ),
          );

  static const String endpoint =
      'https://data.wien.gv.at/daten/geo'
      '?service=WFS&request=GetFeature&version=1.1.0'
      '&typeName=ogdwien:SEHENSWUERDIGOGD&srsName=EPSG:4326&outputFormat=json';

  final Dio _dio;

  Future<List<PointOfInterest>> fetchPointsOfInterest() async {
    try {
      final response = await _dio.get<dynamic>(endpoint);
      final statusCode = response.statusCode;
      if (statusCode == null || statusCode < 200 || statusCode >= 300) {
        throw PoiDataException(
          'The Vienna data service returned HTTP ${statusCode ?? 'unknown'}.',
        );
      }

      var data = response.data;
      if (data is String) {
        try {
          data = jsonDecode(data);
        } on FormatException {
          throw const PoiDataException(
            'The Vienna places data could not be read.',
          );
        }
      }

      return ViennaPoiParser.parseFeatureCollection(data);
    } on PoiDataException {
      rethrow;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode != null) {
        throw PoiDataException(
          'The Vienna data service returned HTTP $statusCode.',
        );
      }
      throw const PoiDataException(
        'Could not reach the Vienna Open Government Data service.',
      );
    }
  }
}
