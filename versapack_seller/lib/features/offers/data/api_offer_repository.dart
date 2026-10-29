import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_model.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_repository.dart';

/// Coupons the seller runs on their own store.
class ApiOfferRepository implements OfferRepository {
  const ApiOfferRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<CouponModel>> getCoupons() async {
    final response = await _dio.get<dynamic>('/food/restaurant/my-offers');
    final data = response.data;
    final list = _asList(data is List ? data : _asMap(data)['offers']);

    return list.map(_toCoupon).toList();
  }

  @override
  Future<void> toggleCouponActive(String couponId, bool isActive) =>
      _dio.patch<dynamic>(
        '/food/restaurant/my-offers/$couponId/status',
        // The backend models an offer's state as a word, not a flag.
        data: {'status': isActive ? 'active' : 'inactive'},
      );

  @override
  Future<void> createCoupon(CouponModel coupon) async {
    final payload = {
      'couponCode': coupon.code,
      'discountType': coupon.discountType == DiscountType.percentage
          ? 'percentage'
          // The backend's word for a fixed amount off.
          : 'flat-price',
      'discountValue': coupon.discountValue,
      'minOrderValue': coupon.minOrderAmount,
      if (coupon.maxDiscountAmount != null)
        'maxDiscount': coupon.maxDiscountAmount,
      if (coupon.usageLimit != null) 'usageLimit': coupon.usageLimit,
      'startDate': _formatDate(coupon.validFrom),
      'endDate': _formatDate(coupon.validTill),
    };

    try {
      debugPrint('--------------------------------------------------');
      debugPrint('>>> [CREATE COUPON REQUEST]');
      debugPrint('Endpoint: /food/restaurant/my-offers');
      debugPrint('Request Headers: ${_dio.options.headers}');
      debugPrint('Request Payload: $payload');
      debugPrint('--------------------------------------------------');

      final response = await _dio.post<dynamic>(
        '/food/restaurant/my-offers',
        data: payload,
      );

      debugPrint('--------------------------------------------------');
      debugPrint('<<< [CREATE COUPON RESPONSE SUCCESS]');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Headers: ${response.headers.map}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('--------------------------------------------------');
    } on DioException catch (e) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [CREATE COUPON RESPONSE ERROR]');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Headers: ${e.response?.headers.map}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('--------------------------------------------------');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [CREATE COUPON UNEXPECTED ERROR]');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('--------------------------------------------------');
      rethrow;
    }
  }

  @override
  Future<void> deleteCoupon(String couponId) =>
      _dio.delete<dynamic>('/food/restaurant/my-offers/$couponId');

  CouponModel _toCoupon(Map<String, dynamic> json) {
    final code = (json['couponCode'] ?? json['code'] ?? '').toString();

    return CouponModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      code: code,
      // Offers carry no separate title; the code is what a seller recognises.
      title: _firstNonEmpty([json['title'], json['name']], fallback: code),
      description: (json['description'] ?? '').toString(),
      discountType: (json['discountType'] ?? '') == 'percentage'
          ? DiscountType.percentage
          : DiscountType.fixedAmount,
      discountValue: _asNum(json['discountValue'])?.toDouble() ?? 0,
      minOrderAmount: _asNum(json['minOrderValue'])?.toDouble() ?? 0,
      maxDiscountAmount: _positiveOrNull(
        _asNum(json['maxDiscount'])?.toDouble(),
      ),
      validFrom: _asDate(json['startDate']) ?? DateTime.now(),
      // An offer with no end date runs until it is switched off. Far-future
      // rather than null, because the field is non-nullable and "today" would
      // render every open-ended coupon as already expired.
      validTill:
          _asDate(json['endDate']) ??
          DateTime.now().add(const Duration(days: 365)),
      usageCount: _asNum(json['usedCount'])?.toInt() ?? 0,
      // 0 is how the backend spells "no limit", which is not the same as a
      // limit of zero -- that would read as a coupon nobody may use.
      usageLimit: _positiveIntOrNull(_asNum(json['usageLimit'])?.toInt()),
      isActive: (json['status'] ?? '') == 'active',
    );
  }

  static double? _positiveOrNull(double? v) => (v == null || v <= 0) ? null : v;

  static int? _positiveIntOrNull(int? v) => (v == null || v <= 0) ? null : v;

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static num? _asNum(dynamic v) =>
      v is num ? v : num.tryParse((v ?? '').toString());

  static DateTime? _asDate(dynamic v) =>
      DateTime.tryParse((v ?? '').toString())?.toLocal();

  static String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }

  static String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
