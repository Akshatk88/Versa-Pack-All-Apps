import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/features/explore/domain/explore_repository.dart';
import 'package:quick_commerce_seller/features/explore/domain/store_settings_model.dart';

/// The store itself: profile, trading hours, and whether it is open.
///
/// Delivery settings are read-only here. Radius, minimum order and packaging
/// charge are platform-wide figures an admin sets, not a seller — writing them
/// from this app would let one store change every store's economics.
class ApiExploreRepository implements ExploreRepository {
  const ApiExploreRepository(this._dio);

  final Dio _dio;

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  Future<StoreProfileModel> getStoreProfile() async {
    final store = await _currentStore();

    return StoreProfileModel(
      id: (store['_id'] ?? store['id'] ?? '').toString(),
      name: (store['restaurantName'] ?? store['name'] ?? '').toString(),
      description: (store['description'] ?? '').toString(),
      // The store's own line if it has one, otherwise the owner's.
      phone: _firstNonEmpty([
        store['primaryContactNumber'],
        store['ownerPhone'],
      ]),
      email: _firstNonEmpty([store['ownerEmail'], store['email']]),
      address: _formatAddress(store),
      fssaiLicense: (store['fssaiNumber'] ?? '').toString(),
      gstNumber: (store['gstNumber'] ?? '').toString(),
      isOnline: store['isAcceptingOrders'] != false,
      offlineReason: (store['offlineReason'] ?? '').toString(),
    );
  }

  @override
  Future<void> updateStoreProfile(StoreProfileModel profile) =>
      _dio.patch<dynamic>(
        '/food/restaurant/profile',
        data: {
          'restaurantName': profile.name,
          'description': profile.description,
          'primaryContactNumber': profile.phone,
          'ownerEmail': profile.email,
          'fssaiNumber': profile.fssaiLicense,
          'gstNumber': profile.gstNumber,
        },
      );

  @override
  Future<void> setStoreOnlineStatus(bool isOnline, {String reason = ''}) =>
      _dio.patch<dynamic>(
        '/food/restaurant/profile',
        data: {
          'isAcceptingOrders': isOnline,
          if (reason.isNotEmpty) 'offlineReason': reason,
        },
      );

  @override
  Future<List<DayTimingModel>> getOutletTimings() async {
    final response = await _dio.get<dynamic>('/food/restaurant/outlet-timings');
    final timings = _asMap(_asMap(response.data)['outletTimings']);

    // Built from a fixed week rather than from the payload's keys, so the
    // screen always renders seven rows in order even for a store that has
    // never saved its hours.
    return _days.map((day) {
      final t = _asMap(timings[day]);
      return DayTimingModel(
        dayName: day,
        isOpen: t['isOpen'] != false,
        openTime: (t['openingTime'] ?? '09:00').toString(),
        closeTime: (t['closingTime'] ?? '22:00').toString(),
      );
    }).toList();
  }

  @override
  Future<void> updateOutletTimings(List<DayTimingModel> timings) =>
      _dio.put<dynamic>(
        '/food/restaurant/outlet-timings',
        data: {
          'outletTimings': {
            for (final t in timings)
              t.dayName: {
                'isOpen': t.isOpen,
                'openingTime': t.openTime,
                'closingTime': t.closeTime,
              },
          },
        },
      );

  @override
  Future<DeliverySettingsModel> getDeliverySettings() async {
    final response = await _dio.get<dynamic>('/food/admin/fee-settings/public');
    final fees = _asMap(_asMap(response.data)['feeSettings'] ?? response.data);
    final store = await _currentStore();

    return DeliverySettingsModel(
      deliveryRadiusKm: _asNum(fees['deliveryRadiusKm'])?.toDouble() ?? 0,
      minOrderValue: _asNum(fees['minOrderValue'])?.toDouble() ?? 0,
      packagingCharge: _asNum(fees['packagingFee'])?.toDouble() ?? 0,
      // Only the platform's own fleet delivers; a seller never carries.
      isSelfDelivery: false,
      freeDeliveryThreshold:
          _asNum(fees['freeDeliveryThreshold'])?.toDouble() ??
          _asNum(store['freeDeliveryThreshold'])?.toDouble() ??
          0,
    );
  }

  @override
  Future<void> updateDeliverySettings(DeliverySettingsModel settings) async {
    // Deliberately inert. These are platform-wide figures owned by an admin,
    // and there is no seller-facing endpoint that writes them -- silently
    // POSTing somewhere would either 404 or change another store's terms.
  }

  Future<Map<String, dynamic>> _currentStore() async {
    final response = await _dio.get<dynamic>('/food/restaurant/current');
    final data = _asMap(response.data);
    final nested = data['restaurant'];
    return nested is Map ? Map<String, dynamic>.from(nested) : data;
  }

  static String _formatAddress(Map<String, dynamic> s) =>
      [
            s['addressLine1'],
            s['addressLine2'],
            s['area'],
            s['city'],
            s['state'],
            s['pincode'],
          ]
          .map((e) => (e ?? '').toString().trim())
          .where((e) => e.isNotEmpty)
          .join(', ');

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static num? _asNum(dynamic v) =>
      v is num ? v : num.tryParse((v ?? '').toString());

  static String _firstNonEmpty(List<dynamic> values) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }
}
