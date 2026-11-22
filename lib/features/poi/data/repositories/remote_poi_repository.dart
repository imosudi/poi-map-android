import '../../../../core/logging/app_logger.dart';
import '../../../../core/network/cancellation_token.dart';
import '../../domain/entities/poi.dart';
import '../../domain/repositories/poi_repository.dart';
import '../datasources/vienna_ogd_api_service.dart';

/// Remote-backed [PoiRepository] reading from Vienna Open Government Data.
final class RemotePoiRepository implements PoiRepository {
  const RemotePoiRepository({
    required ViennaOgdApiService apiService,
    required AppLogger logger,
    this.extraPois = const <Poi>[],
  }) : _apiService = apiService,
       _logger = logger;

  final ViennaOgdApiService _apiService;
  final AppLogger _logger;
  final List<Poi> extraPois;

  @override
  Future<List<Poi>> fetchPois({CancellationToken? cancelToken}) async {
    final collection = await _apiService.fetchSights(cancelToken: cancelToken);
    if (collection.skippedFeatureCount > 0) {
      _logger.warning(
        'RemotePoiRepository',
        'Skipped malformed POI records during mapping',
        context: {'skippedCount': collection.skippedFeatureCount},
      );
    }
    final remotePois = collection.toDomainList();
    if (extraPois.isEmpty) {
      return remotePois;
    }
    final existingIds = <String>{for (final poi in remotePois) poi.id};
    return List<Poi>.unmodifiable([
      ...remotePois,
      for (final extra in extraPois)
        if (!existingIds.contains(extra.id)) extra,
    ]);
  }
}
