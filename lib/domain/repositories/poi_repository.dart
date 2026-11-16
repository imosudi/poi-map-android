import '../entities/point_of_interest.dart';

/// Contract for retrieving Vienna Points of Interest.
abstract interface class PoiRepository {
  Future<List<PointOfInterest>> fetchPointsOfInterest();
}

