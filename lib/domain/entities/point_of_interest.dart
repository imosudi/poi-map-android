/// Domain entity representing a Vienna Point of Interest.
class PointOfInterest {
  const PointOfInterest({
    required this.id,
    required this.name,
    this.address,
    this.informationUrl,
    this.thumbnailUrl,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final String name;
  final String? address;
  final Uri? informationUrl;
  final Uri? thumbnailUrl;
  final double latitude;
  final double longitude;

  factory PointOfInterest.fromJson(Map<String, dynamic> json) {
    final infoRaw = json['informationUrl'] as String?;
    final thumbRaw = json['thumbnailUrl'] as String?;
    return PointOfInterest(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      informationUrl: infoRaw != null ? Uri.tryParse(infoRaw) : null,
      thumbnailUrl: thumbRaw != null ? Uri.tryParse(thumbRaw) : null,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'informationUrl': informationUrl?.toString(),
      'thumbnailUrl': thumbnailUrl?.toString(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PointOfInterest &&
        other.id == id &&
        other.name == name &&
        other.address == address &&
        other.informationUrl == informationUrl &&
        other.thumbnailUrl == thumbnailUrl &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    address,
    informationUrl,
    thumbnailUrl,
    latitude,
    longitude,
  );
}

