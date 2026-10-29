import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/config/theme/app_palette.dart';
import 'package:quick_commerce_seller/config/theme/app_text_styles.dart';
import 'package:quick_commerce_seller/core/widgets/app_toast.dart';
import 'package:quick_commerce_seller/features/explore/domain/seller_zone_model.dart';
import 'package:quick_commerce_seller/features/explore/presentation/controllers/seller_zones_controller.dart';
import 'package:quick_commerce_seller/features/location/domain/store_location_status.dart';
import 'package:quick_commerce_seller/features/location/presentation/controllers/store_location_controller.dart';

class ZoneSetupScreen extends ConsumerStatefulWidget {
  const ZoneSetupScreen({super.key});

  @override
  ConsumerState<ZoneSetupScreen> createState() => _ZoneSetupScreenState();
}

class _ZoneSetupScreenState extends ConsumerState<ZoneSetupScreen> {
  static const LatLng _fallbackCenter = LatLng(19.0760, 72.8777);

  GoogleMapController? _mapController;
  LatLng _userCenter = _fallbackCenter;
  bool _isLoadingLocation = true;
  bool _isSubmittingLocation = false;

  final TextEditingController _searchController = TextEditingController();
  String _currentAddress = 'Locating shop address...';

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _finishLoading();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _finishLoading();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;
      setState(() {
        _userCenter = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_userCenter, 15),
      );

      _reverseGeocode(_userCenter);
    } catch (_) {
      _finishLoading();
    }
  }

  void _finishLoading() {
    if (!mounted) return;
    setState(() => _isLoadingLocation = false);
    _reverseGeocode(_userCenter);
  }

  Future<void> _reverseGeocode(LatLng target) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        target.latitude,
        target.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final p = placemarks.first;
        final addr = [
          p.name,
          p.street,
          p.subLocality,
          p.locality,
          p.postalCode,
        ].where((e) => e != null && e.trim().isNotEmpty).join(', ');

        setState(() {
          _currentAddress = addr.isNotEmpty
              ? addr
              : '${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)}';
          _searchController.text = _currentAddress;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _currentAddress =
              '${target.latitude.toStringAsFixed(4)}, ${target.longitude.toStringAsFixed(4)}';
          _searchController.text = _currentAddress;
        });
      }
    }
  }

  Future<void> _searchAndMoveMap(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        final newLatLng = LatLng(loc.latitude, loc.longitude);
        setState(() => _userCenter = newLatLng);
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(newLatLng, 16),
        );
        _reverseGeocode(newLatLng);
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, 'Location not found. Try dragging map pin.');
      }
    }
  }

  Future<void> _confirmStoreLocation() async {
    setState(() => _isSubmittingLocation = true);

    final success = await ref
        .read(storeLocationNotifierProvider.notifier)
        .updateLocation(
          lat: _userCenter.latitude,
          lng: _userCenter.longitude,
          address: _currentAddress,
          onError: (errMsg) {
            AppToast.show(context, errMsg);
          },
        );

    if (mounted) {
      setState(() => _isSubmittingLocation = false);
      if (success) {
        AppToast.show(
          context,
          'Store location submitted successfully!',
        );
      }
    }
  }

  Set<Circle> _buildCircles(List<SellerZoneModel> zones) {
    if (zones.isEmpty) {
      return {
        Circle(
          circleId: const CircleId('fallback_zone'),
          center: _userCenter,
          radius: 5000,
          fillColor: AppColors.primary.withValues(alpha: 0.2),
          strokeColor: AppColors.primaryDark,
          strokeWidth: 2,
        ),
      };
    }

    return zones.map((zone) {
      final isPrimary = zone.isActive;
      return Circle(
        circleId: CircleId(zone.id),
        center: LatLng(zone.centerLat, zone.centerLng),
        radius: zone.radiusM.toDouble(),
        fillColor: isPrimary
            ? AppColors.primary.withValues(alpha: 0.25)
            : Colors.grey.withValues(alpha: 0.15),
        strokeColor: isPrimary ? AppColors.primaryDark : Colors.grey.shade600,
        strokeWidth: isPrimary ? 3 : 1,
      );
    }).toSet();
  }

  Widget _buildStatusBanner(StoreLocationStatus? locationStatus) {
    if (locationStatus == null) return const SizedBox.shrink();

    if (locationStatus.isPending) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          children: [
            Icon(Icons.hourglass_top_rounded, color: Colors.amber.shade900),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Update Pending Approval',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your new store pin is under review by admin. Current live location remains active.',
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (locationStatus.isRejected) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red.shade800),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Location Update Rejected',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade800,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    locationStatus.locationRejectionReason.isNotEmpty
                        ? locationStatus.locationRejectionReason
                        : 'Your store pin change was rejected. Please re-position your pin within the service area.',
                    style: TextStyle(color: Colors.red.shade800, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final zonesAsync = ref.watch(sellerZonesNotifierProvider);
    final zones = zonesAsync.value ?? [];

    final locationStatusAsync = ref.watch(storeLocationNotifierProvider);
    final locationStatus = locationStatusAsync.value;

    return Scaffold(
      backgroundColor: context.pageBg,
      appBar: AppBar(
        backgroundColor: context.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 18,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Store Location Setup',
          style: AppTextStyles.h3.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStatusBanner(locationStatus),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _searchAndMoveMap,
                decoration: InputDecoration(
                  hintText: 'Search shop location or area...',
                  prefixIcon: Icon(Icons.search_rounded, color: context.textPrimary),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    onPressed: () => _searchAndMoveMap(_searchController.text),
                  ),
                  filled: true,
                  fillColor: context.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: context.borderColor),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD1D5DB)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _userCenter,
                          zoom: 15,
                        ),
                        circles: _buildCircles(zones),
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        compassEnabled: false,
                        rotateGesturesEnabled: false,
                        tiltGesturesEnabled: false,
                        onMapCreated: (controller) {
                          _mapController = controller;
                          if (!_isLoadingLocation) {
                            controller.animateCamera(
                              CameraUpdate.newLatLngZoom(_userCenter, 15),
                            );
                          }
                        },
                        onCameraMove: (position) {
                          _userCenter = position.target;
                        },
                        onCameraIdle: () {
                          _reverseGeocode(_userCenter);
                        },
                      ),
                      IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 44,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      if (_isLoadingLocation || zonesAsync.isLoading)
                        const Positioned.fill(
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: GestureDetector(
                          onTap: _fetchCurrentLocation,
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.surface,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.gps_fixed_rounded,
                              color: AppColors.primaryDark,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.storefront_rounded, color: AppColors.primaryDark, size: 26),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected Store Location:',
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _isSubmittingLocation ? null : _confirmStoreLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: const Color(0xFF181C2E),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmittingLocation
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF181C2E),
                            ),
                          )
                        : Text(
                            'Confirm Store Location',
                            style: AppTextStyles.button.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}