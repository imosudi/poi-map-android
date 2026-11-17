import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/cancellation_token.dart';
import '../models/vienna_ogd_poi_dto.dart';

/// Remote API service for the Vienna OGD `ogdwien:SEHENSWUERDIGOGD` endpoint.
final class ViennaOgdApiService {
  const ViennaOgdApiService({
    required Dio dio,
    required ErrorHandler errorHandler,
  }) : _dio = dio,
       _errorHandler = errorHandler;

  final Dio _dio;
  final ErrorHandler _errorHandler;

  static const Map<String, String> defaultQueryParameters = {
    'service': 'WFS',
    'request': 'GetFeature',
    'version': '1.1.0',
    'typeName': 'ogdwien:SEHENSWUERDIGOGD',
    'srsName': 'EPSG:4326',
    'outputFormat': 'json',
  };

  /// Retrieves the GeoJSON FeatureCollection for Vienna sights.
  Future<ViennaOgdFeatureCollectionDto> fetchSights({
    CancellationToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const NetworkException('Request was cancelled.');
    }

    final dioCancelToken = CancelToken();
    final removeListener = cancelToken?.addListener(() {
      if (!dioCancelToken.isCancelled) {
        dioCancelToken.cancel('Cancelled by caller');
      }
    });

    try {
      final response = await _dio.get<String>(
        '',
        queryParameters: defaultQueryParameters,
        options: Options(responseType: ResponseType.plain),
        cancelToken: dioCancelToken,
      );

      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw NetworkException(
          'Vienna OGD returned an unexpected status ($statusCode).',
        );
      }

      final Object? payload = response.data;
      if (payload is String) {
        if (kDebugMode) {
          debugPrint(AppLogger.redactText(payload));
        }
        return ViennaOgdFeatureCollectionDto.parseJsonString(payload);
      }
      if (payload is Map) {
        final normalized = Map<String, dynamic>.from(payload);
        if (kDebugMode) {
          debugPrint(AppLogger.redactText(jsonEncode(normalized)));
        }
        return ViennaOgdFeatureCollectionDto.fromJson(normalized);
      }

      throw const PoiDataException(
        'Unexpected response payload from Vienna OGD.',
      );
    } on AppException {
      rethrow;
    } on DioException catch (error, stackTrace) {
      if (error.type == DioExceptionType.cancel) {
        throw NetworkException('Request was cancelled.', cause: error);
      }
      throw _errorHandler.handle(
        error,
        stackTrace: stackTrace,
        tag: 'ViennaOgdApiService',
      );
    } catch (error, stackTrace) {
      throw _errorHandler.handle(
        error,
        stackTrace: stackTrace,
        tag: 'ViennaOgdApiService',
      );
    } finally {
      removeListener?.call();
    }
  }
}
