import '../../domain/entities/point_of_interest.dart';
import '../../domain/repositories/poi_repository.dart';
import '../services/vienna_poi_service.dart';

/// Repository implementation backed by [ViennaPoiService].
class ViennaPoiRepository implements PoiRepository {
  ViennaPoiRepository({required ViennaPoiService service}) : _service = service;

  final ViennaPoiService _service;

  @override
  Future<List<PointOfInterest>> fetchPointsOfInterest() {
    return _service.fetchPointsOfInterest();
  }
}
