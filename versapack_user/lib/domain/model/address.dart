/// Saved delivery address. `label` is constrained by the backend enum.
enum AddressLabel {
  home('Home'),
  office('Office'),
  other('Other');

  const AddressLabel(this.wireValue);

  final String wireValue;

  static AddressLabel fromWire(String? value) => AddressLabel.values.firstWhere(
        (l) => l.wireValue.toLowerCase() == (value ?? '').toLowerCase(),
        orElse: () => AddressLabel.other,
      );
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.state,
    required this.latitude,
    required this.longitude,
    this.additionalDetails = '',
    this.zipCode = '',
    this.phone = '',
    this.isDefault = false,
  });

  final String id;
  final AddressLabel label;
  final String street;
  final String city;
  final String state;
  final String additionalDetails;
  final String zipCode;
  final String phone;
  final double? latitude;
  final double? longitude;
  final bool isDefault;

  bool get hasCoordinates => latitude != null && longitude != null;

  /// One-line form for the home header, kept short on purpose.
  String get shortLine {
    final detail = additionalDetails.trim();
    return detail.isNotEmpty ? '$detail, $street' : street;
  }

  String get fullLine => [
        additionalDetails.trim(),
        street.trim(),
        city.trim(),
        state.trim(),
        zipCode.trim(),
      ].where((p) => p.isNotEmpty).join(', ');

  Address copyWith({
    AddressLabel? label,
    String? street,
    String? city,
    String? state,
    String? additionalDetails,
    String? zipCode,
    String? phone,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) =>
      Address(
        id: id,
        label: label ?? this.label,
        street: street ?? this.street,
        city: city ?? this.city,
        state: state ?? this.state,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        additionalDetails: additionalDetails ?? this.additionalDetails,
        zipCode: zipCode ?? this.zipCode,
        phone: phone ?? this.phone,
        isDefault: isDefault ?? this.isDefault,
      );

  @override
  bool operator ==(Object other) => other is Address && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
