/// A picked store location: coordinates plus the address they resolve to.
///
/// The backend resolves the delivery zone from the coordinates, and stores the
/// zone it computed rather than one the client sends — so the pin is the part
/// that matters and the text is what the seller reads back.
class StoreLocation {
  const StoreLocation({
    required this.latitude,
    required this.longitude,
    this.formattedAddress = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
  });

  final double latitude;
  final double longitude;
  final String formattedAddress;
  final String city;
  final String state;
  final String pincode;

  bool get hasAddress => formattedAddress.trim().isNotEmpty;

  /// What to show when reverse geocoding has not produced anything readable —
  /// the raw pin is still useful and still submittable.
  String get displayLabel => hasAddress
      ? formattedAddress
      : '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  StoreLocation copyWith({
    double? latitude,
    double? longitude,
    String? formattedAddress,
    String? city,
    String? state,
    String? pincode,
  }) => StoreLocation(
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    formattedAddress: formattedAddress ?? this.formattedAddress,
    city: city ?? this.city,
    state: state ?? this.state,
    pincode: pincode ?? this.pincode,
  );
}

/// Why a location lookup failed, so the UI can offer the right way out —
/// a retry, the app settings, or the system location screen.
enum LocationFailure {
  /// The seller declined this time; asking again is allowed.
  permissionDenied,

  /// Declined permanently (or restricted). Only the OS settings page can undo
  /// this — re-requesting silently returns denied forever.
  permissionPermanentlyDenied,

  /// Location services are switched off device-wide.
  serviceDisabled,

  /// A fix took too long. Common indoors and on a cold GPS start.
  timeout,

  /// Reverse geocoding needs the network; the coordinates are still valid.
  network,

  unknown;

  String get message => switch (this) {
    permissionDenied =>
      'Location permission is needed to place your store on the map.',
    permissionPermanentlyDenied =>
      'Location permission is blocked. Enable it in Settings to use your '
          'current location.',
    serviceDisabled =>
      'Location services are off. Turn them on to use your current location.',
    timeout =>
      'Could not get a location fix. Move somewhere with a clearer signal, or '
          'set the pin manually.',
    network =>
      'Could not look up the address. Check your connection — your pin is '
          'still saved.',
    unknown => 'Could not get your location. Please set the pin manually.',
  };

  /// Whether the only route forward is the OS settings screen.
  bool get needsSettings =>
      this == permissionPermanentlyDenied || this == serviceDisabled;
}

/// Thrown by [LocationService] so callers switch on a cause rather than parsing
/// platform exception strings.
class LocationException implements Exception {
  const LocationException(this.failure);

  final LocationFailure failure;

  String get message => failure.message;

  @override
  String toString() => 'LocationException(${failure.name})';
}
