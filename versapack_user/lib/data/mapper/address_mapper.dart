import '../../domain/model/address.dart';
import '../dto/address_dto.dart';

abstract final class AddressMapper {
  static Address toDomain(AddressDto dto) => Address(
        id: dto.id,
        label: AddressLabel.fromWire(dto.label),
        street: dto.street,
        city: dto.city,
        state: dto.state,
        additionalDetails: dto.additionalDetails,
        zipCode: dto.zipCode,
        phone: dto.phone,
        latitude: dto.latitude,
        longitude: dto.longitude,
        isDefault: dto.isDefault,
      );

  static List<Address> toDomainList(List<AddressDto> dtos) {
    final list = dtos.map(toDomain).toList();
    // Default first — the checkout picks addresses[0] when nothing is chosen.
    list.sort((a, b) {
      if (a.isDefault == b.isDefault) return 0;
      return a.isDefault ? -1 : 1;
    });
    return list;
  }

  /// Request body for POST/PATCH `/food/user/addresses`.
  static Map<String, dynamic> toCreateJson(Address address) => {
        'label': address.label.wireValue,
        'street': address.street,
        'additionalDetails': address.additionalDetails,
        'city': address.city,
        'state': address.state,
        if (address.zipCode.trim().isNotEmpty) 'zipCode': address.zipCode,
        if (address.phone.trim().isNotEmpty) 'phone': address.phone,
        'latitude': address.latitude,
        'longitude': address.longitude,
      };

  /// Address shape embedded in `POST /food/orders`.
  static Map<String, dynamic> toOrderJson(Address address, {String? customerName}) => {
        'label': address.label.wireValue,
        if (customerName != null && customerName.isNotEmpty) 'name': customerName,
        'street': address.street,
        'additionalDetails': address.additionalDetails,
        'city': address.city,
        'state': address.state,
        if (address.zipCode.trim().isNotEmpty) 'zipCode': address.zipCode,
        if (address.phone.trim().isNotEmpty) 'phone': address.phone,
        if (address.hasCoordinates)
          'location': {
            'type': 'Point',
            'coordinates': [address.longitude, address.latitude],
          },
      };
}
