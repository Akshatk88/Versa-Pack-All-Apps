import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/location/data/location_service.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location.dart';

/// Full-screen map for placing the store pin.
///
/// Pops a [StoreLocation] when confirmed, or null when dismissed. The caller
/// keeps ownership of the value — this screen writes nothing.
class LocationPickerScreen extends ConsumerStatefulWidget {
  const LocationPickerScreen({super.key, this.initial});

  /// Where to open. Null means "ask the device", falling back to a wide view.
  final StoreLocation? initial;

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  /// Shown only until the device answers. Deliberately zoomed out so it never
  /// looks like a real, confirmable pin.
  static const LatLng _fallbackCentre = LatLng(20.5937, 78.9629);

  GoogleMapController? _map;
  StoreLocation? _picked;
  bool _busy = true;
  bool _resolvingAddress = false;

  /// Reverse geocoding runs on every pin move; without this, a drag fires a
  /// burst of lookups and a slow earlier one can overwrite a newer result.
  int _lookupToken = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _map?.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final initial = widget.initial;
    if (initial != null) {
      setState(() {
        _picked = initial;
        _busy = false;
      });
      if (!initial.hasAddress) unawaited(_resolve(initial));
      return;
    }
    await _useCurrentLocation(silent: true);
  }

  Future<void> _useCurrentLocation({bool silent = false}) async {
    setState(() => _busy = true);
    try {
      final located = await ref
          .read(locationServiceProvider)
          .currentLocationWithAddress();
      if (!mounted) return;
      setState(() {
        _picked = located;
        _busy = false;
      });
      await _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(located.latitude, located.longitude),
          17,
        ),
      );
    } on LocationException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      // On first open a refusal is not an error — the seller can still place
      // the pin by hand, so only an explicit tap gets a message.
      if (!silent) _showFailure(e.failure);
    }
  }

  /// Offers the settings page when that is the only remedy, a plain message
  /// otherwise.
  void _showFailure(LocationFailure failure) {
    if (!failure.needsSettings) {
      AppToast.showError(context, failure.message);
      return;
    }

    final service = ref.read(locationServiceProvider);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => failure == LocationFailure.serviceDisabled
                ? service.openLocationSettings()
                : service.openAppSettings(),
          ),
        ),
      );
  }

  /// Moves the pin, then resolves the address for the new spot.
  void _setPin(LatLng target) {
    final next = StoreLocation(
      latitude: target.latitude,
      longitude: target.longitude,
    );
    setState(() => _picked = next);
    unawaited(_resolve(next));
  }

  Future<void> _resolve(StoreLocation location) async {
    final token = ++_lookupToken;
    setState(() => _resolvingAddress = true);

    final resolved = await ref
        .read(locationServiceProvider)
        .reverseGeocode(location);

    // A newer pin move won the race — discard this result.
    if (!mounted || token != _lookupToken) return;
    setState(() {
      _picked = resolved;
      _resolvingAddress = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final picked = _picked;
    final centre = picked == null
        ? _fallbackCentre
        : LatLng(picked.latitude, picked.longitude);

    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Set Store Location',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: context.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: centre,
              zoom: picked == null ? 4 : 17,
            ),
            onMapCreated: (controller) => _map = controller,
            // Tap anywhere to move the pin.
            onTap: _setPin,
            markers: picked == null
                ? const {}
                : {
                    Marker(
                      markerId: const MarkerId('store'),
                      position: centre,
                      draggable: true,
                      // Drag updates only on release; onDrag would fire a
                      // geocode request for every frame of the gesture.
                      onDragEnd: _setPin,
                    ),
                  },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
          ),

          if (_busy)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.25),
              child: const Center(child: CircularProgressIndicator()),
            ),

          Positioned(
            right: 16,
            bottom: 210,
            child: FloatingActionButton(
              heroTag: 'locate',
              backgroundColor: context.surface,
              onPressed: _busy ? null : () => _useCurrentLocation(),
              child: const Icon(
                Icons.my_location_rounded,
                color: Color(0xFF16A34A),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildAddressSheet(picked),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSheet(StoreLocation? picked) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFF16A34A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Selected Location',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: context.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_resolvingAddress)
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              picked == null
                  ? 'Tap the map or use your current location to place the pin.'
                  : picked.displayLabel,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: picked == null
                    ? context.textSecondary
                    : context.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Confirm needs a pin, not an address: a resolved street name
                // is a nicety, the coordinates are what the backend zones on.
                onPressed: picked == null
                    ? null
                    : () => Navigator.of(context).pop(picked),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFD9027),
                  disabledBackgroundColor: const Color(0xFFFDE68A),
                  foregroundColor: const Color(0xFF181C2E),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Confirm Location',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
