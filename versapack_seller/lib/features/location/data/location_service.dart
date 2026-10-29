import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location.dart';

/// Device location and address lookup.
///
/// Every platform failure is converted into a [LocationFailure] here so screens
/// never have to interpret a `PlatformException` message, and so the "denied"
/// and "denied forever" cases stay distinguishable — they need different
/// remedies and only one of them can be fixed by asking again.
class LocationService {
  const LocationService();

  /// A fix usually arrives in a second or two; indoors it may never arrive at
  /// all, so the wait is bounded rather than left to hang.
  static const Duration fixTimeout = Duration(seconds: 15);

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Opens the OS app-settings page, for a permanently denied permission.
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  /// Opens the OS location page, for location services switched off.
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// Requests permission if needed. Throws [LocationException] describing why
  /// it cannot proceed.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationException(LocationFailure.serviceDisabled);
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    // `deniedForever` never resolves by asking again — only the settings page
    // can change it. Android also reports `restricted` for device policy.
    if (permission == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationFailure.permissionPermanentlyDenied,
      );
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.unableToDetermine) {
      throw const LocationException(LocationFailure.permissionDenied);
    }
  }

  /// The device's current position, permissions handled.
  Future<StoreLocation> currentLocation() async {
    await ensurePermission();

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: fixTimeout,
        ),
      );
      return StoreLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationException(LocationFailure.timeout);
    } on LocationServiceDisabledException {
      throw const LocationException(LocationFailure.serviceDisabled);
    } catch (_) {
      throw const LocationException(LocationFailure.unknown);
    }
  }

  /// Resolves coordinates to a readable address.
  ///
  /// Returns the location with whatever it could resolve rather than throwing:
  /// a pin without a street name is still a valid pin, and the seller can type
  /// the address themselves. Only the caller decides whether to warn.
  Future<StoreLocation> reverseGeocode(StoreLocation location) async {
    try {
      final marks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      ).timeout(const Duration(seconds: 10));

      if (marks.isEmpty) return location;
      final m = marks.first;

      // Placemark fields are inconsistent across devices and regions — several
      // are routinely null or repeat each other, so build the line from the
      // parts that are present and drop duplicates.
      final parts = <String>[
        m.name ?? '',
        m.subLocality ?? '',
        m.locality ?? '',
        m.administrativeArea ?? '',
        m.postalCode ?? '',
      ];
      final seen = <String>{};
      final address = parts
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty && seen.add(p.toLowerCase()))
          .join(', ');

      return location.copyWith(
        formattedAddress: address,
        city: m.locality ?? '',
        state: m.administrativeArea ?? '',
        pincode: m.postalCode ?? '',
      );
    } catch (_) {
      // Offline, or the geocoder is unavailable on this device. The coordinates
      // survive; only the label is missing.
      return location;
    }
  }

  /// Current position with its address resolved, which is what the picker wants.
  Future<StoreLocation> currentLocationWithAddress() async =>
      reverseGeocode(await currentLocation());
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => const LocationService(),
);
