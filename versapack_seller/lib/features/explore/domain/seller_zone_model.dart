class SellerZoneModel {
  final String id;
  final String? sellerId;
  final String name;
  final double centerLat;
  final double centerLng;
  final int radiusM;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  const SellerZoneModel({
    required this.id,
    this.sellerId,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.radiusM,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SellerZoneModel.fromJson(Map<String, dynamic> json) {
    return SellerZoneModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sellerId: json['seller_id']?.toString() ?? json['sellerId']?.toString(),
      name: (json['name'] ?? '').toString(),
      centerLat: _asDouble(json['center_lat'] ?? json['centerLat']),
      centerLng: _asDouble(json['center_lng'] ?? json['centerLng']),
      radiusM: _asInt(json['radius_m'] ?? json['radiusM']),
      isActive: json['is_active'] == true || json['isActive'] == true,
      createdAt: (json['created_at'] ?? json['createdAt'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? json['updatedAt'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (sellerId != null) 'seller_id': sellerId,
      'name': name,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'radius_m': radiusM,
      'is_active': isActive,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  SellerZoneModel copyWith({
    String? id,
    String? sellerId,
    String? name,
    double? centerLat,
    double? centerLng,
    int? radiusM,
    bool? isActive,
    String? createdAt,
    String? updatedAt,
  }) {
    return SellerZoneModel(
      id: id ?? this.id,
      sellerId: sellerId ?? this.sellerId,
      name: name ?? this.name,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      radiusM: radiusM ?? this.radiusM,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _asInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 5000;
    return 5000;
  }
}
