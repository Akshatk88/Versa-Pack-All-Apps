class DayTimingModel {
  final String dayName;
  final bool isOpen;
  final String openTime;
  final String closeTime;

  const DayTimingModel({
    required this.dayName,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  DayTimingModel copyWith({bool? isOpen, String? openTime, String? closeTime}) {
    return DayTimingModel(
      dayName: dayName,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

class DeliverySettingsModel {
  final double deliveryRadiusKm;
  final double minOrderValue;
  final double packagingCharge;
  final bool isSelfDelivery;
  final double freeDeliveryThreshold;

  const DeliverySettingsModel({
    required this.deliveryRadiusKm,
    required this.minOrderValue,
    required this.packagingCharge,
    required this.isSelfDelivery,
    required this.freeDeliveryThreshold,
  });

  DeliverySettingsModel copyWith({
    double? deliveryRadiusKm,
    double? minOrderValue,
    double? packagingCharge,
    bool? isSelfDelivery,
    double? freeDeliveryThreshold,
  }) {
    return DeliverySettingsModel(
      deliveryRadiusKm: deliveryRadiusKm ?? this.deliveryRadiusKm,
      minOrderValue: minOrderValue ?? this.minOrderValue,
      packagingCharge: packagingCharge ?? this.packagingCharge,
      isSelfDelivery: isSelfDelivery ?? this.isSelfDelivery,
      freeDeliveryThreshold:
          freeDeliveryThreshold ?? this.freeDeliveryThreshold,
    );
  }
}

class StoreProfileModel {
  final String id;
  final String name;
  final String description;
  final String phone;
  final String email;
  final String address;
  final String fssaiLicense;
  final String gstNumber;
  final bool isOnline;
  final String offlineReason;

  const StoreProfileModel({
    required this.id,
    required this.name,
    required this.description,
    required this.phone,
    required this.email,
    required this.address,
    required this.fssaiLicense,
    required this.gstNumber,
    required this.isOnline,
    this.offlineReason = '',
  });

  StoreProfileModel copyWith({
    String? name,
    String? description,
    String? phone,
    String? email,
    String? address,
    String? fssaiLicense,
    String? gstNumber,
    bool? isOnline,
    String? offlineReason,
  }) {
    return StoreProfileModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
      gstNumber: gstNumber ?? this.gstNumber,
      isOnline: isOnline ?? this.isOnline,
      offlineReason: offlineReason ?? this.offlineReason,
    );
  }
}
