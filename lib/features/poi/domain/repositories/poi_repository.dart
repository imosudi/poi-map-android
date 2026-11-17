import '../../../../core/network/cancellation_token.dart';
import '../entities/poi.dart';

/// Contract for retrieving Vienna Points of Interest.
abstract interface class PoiRepository {
  /// Fetches available Points of Interest.
  ///
  /// Throws an [AppException] subtype on transport or parsing failures.
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken});
}
