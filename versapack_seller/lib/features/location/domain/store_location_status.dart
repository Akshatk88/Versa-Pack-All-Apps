class StoreLocationInfo {
  final double latitude;
  final double longitude;
  final String address;

  const StoreLocationInfo({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  factory StoreLocationInfo.fromJson(Map<String, dynamic> json) {
    return StoreLocationInfo(
      latitude: _toDouble(json['latitude'] ?? json['lat'] ?? json['center_lat']),
      longitude: _toDouble(json['longitude'] ?? json['lng'] ?? json['center_lng']),
      address: (json['address'] ?? json['formattedAddress'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }
}

class StoreLocationStatus {
  final String name;
  final String? zoneId;
  final StoreLocationInfo? location;
  final StoreLocationInfo? pendingLocation;
  final String locationUpdateStatus;
  final String locationRejectionReason;

  const StoreLocationStatus({
    required this.name,
    this.zoneId,
    this.location,
    this.pendingLocation,
    required this.locationUpdateStatus,
    required this.locationRejectionReason,
  });

  bool get isPending => locationUpdateStatus.toLowerCase() == 'pending';
  bool get isRejected => locationUpdateStatus.toLowerCase() == 'rejected';

  factory StoreLocationStatus.fromRestaurantJson(Map<String, dynamic> restaurant) {
    return StoreLocationStatus(
      name: (restaurant['name'] ?? restaurant['restaurantName'] ?? '').toString(),
      zoneId: restaurant['zoneId']?.toString() ?? restaurant['zone_id']?.toString(),
      location: restaurant['location'] != null
          ? StoreLocationInfo.fromJson(Map<String, dynamic>.from(restaurant['location']))
          : null,
      pendingLocation: restaurant['pendingLocation'] != null
          ? StoreLocationInfo.fromJson(Map<String, dynamic>.from(restaurant['pendingLocation']))
          : null,
      locationUpdateStatus: (restaurant['locationUpdateStatus'] ?? 'none').toString(),
      locationRejectionReason: (restaurant['locationRejectionReason'] ?? '').toString(),
    );
  }

  StoreLocationStatus copyWith({
    String? name,
    String? zoneId,
    StoreLocationInfo? location,
    StoreLocationInfo? pendingLocation,
    String? locationUpdateStatus,
    String? locationRejectionReason,
  }) {
    return StoreLocationStatus(
      name: name ?? this.name,
      zoneId: zoneId ?? this.zoneId,
      location: location ?? this.location,
      pendingLocation: pendingLocation ?? this.pendingLocation,
      locationUpdateStatus: locationUpdateStatus ?? this.locationUpdateStatus,
      locationRejectionReason: locationRejectionReason ?? this.locationRejectionReason,
    );
  }
}
