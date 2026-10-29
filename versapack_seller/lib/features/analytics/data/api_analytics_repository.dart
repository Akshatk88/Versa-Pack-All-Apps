import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';
import 'package:quick_commerce_seller/features/analytics/domain/analytics_model.dart';

/// Analytics computed from the seller's own delivered orders.
///
/// There is no analytics endpoint on the backend. Rather than show invented
/// figures, the numbers are derived here from the order list, and anything the
/// orders cannot answer is left out instead of guessed at.
class ApiAnalyticsRepository {
  const ApiAnalyticsRepository(this._dio);

  final Dio _dio;

  /// [days] is the window; the same length immediately before it is the
  /// comparison period.
  Future<AnalyticsSummary> getSummary({int days = 1}) async {
    final allOrders = <Map<String, dynamic>>[];
    int page = 1;
    int totalPages = 1;

    try {
      do {
        final Map<String, dynamic> queryParams = {
          'status': 'delivered',
          'limit': 100,
          'page': page,
        };

        debugPrint('--------------------------------------------------');
        debugPrint('>>> [ANALYTICS ORDERS REQUEST - PAGE $page]');
        debugPrint('URL: ${_dio.options.baseUrl}/food/restaurant/orders');
        debugPrint('Query Parameters: $queryParams');
        debugPrint('--------------------------------------------------');

        final response = await _dio.get<dynamic>(
          '/food/restaurant/orders',
          queryParameters: queryParams,
        );

        final data = _asMap(response.data);
        final list = _asList(data['orders'] ?? data['data']);
        allOrders.addAll(list);

        final meta = _asMap(data['meta'] ?? data['pagination']);
        totalPages = _asNum(meta['totalPages'])?.toInt() ?? 1;

        debugPrint('Fetched ${list.length} orders (Page $page of $totalPages, Total: ${allOrders.length})');

        if (meta.isEmpty && list.length >= 100) {
          totalPages = page + 1;
        }

        page++;
      } while (page <= totalPages && page <= 5 && allOrders.length < 500);
    } catch (e) {
      debugPrint('Error fetching analytics orders: $e');
      if (allOrders.isEmpty) rethrow;
    }

    if (allOrders.isEmpty) return const AnalyticsSummary.empty();

    final now = DateTime.now();
    final windowStart = now.subtract(Duration(days: days));
    final priorStart = now.subtract(Duration(days: days * 2));

    final current = <Map<String, dynamic>>[];
    final prior = <Map<String, dynamic>>[];
    // Earliest order per customer across everything fetched, which is what
    // makes "new" mean new to this store rather than new to the window.
    final firstSeen = <String, DateTime>{};

    for (final o in allOrders) {
      final at = _extractDeliveredAt(o);
      if (at == null) continue;

      final customer = _customerKey(o);
      if (customer.isNotEmpty) {
        final seen = firstSeen[customer];
        if (seen == null || at.isBefore(seen)) firstSeen[customer] = at;
      }

      if (at.isAfter(windowStart)) {
        current.add(o);
      } else if (at.isAfter(priorStart)) {
        prior.add(o);
      }
    }

    final sales = current.fold<double>(0, (sum, o) => sum + _total(o));
    final priorSales = prior.fold<double>(0, (sum, o) => sum + _total(o));

    final items = current.fold<int>(
      0,
      (sum, o) =>
          sum +
          _asList(
            o['items'],
          ).fold<int>(0, (n, i) => n + (_asNum(i['quantity'])?.toInt() ?? 0)),
    );

    var newCustomers = 0;
    var returning = 0;
    final counted = <String>{};
    for (final o in current) {
      final customer = _customerKey(o);
      if (customer.isEmpty || !counted.add(customer)) continue;
      final first = firstSeen[customer];
      if (first != null && first.isAfter(windowStart)) {
        newCustomers++;
      } else {
        returning++;
      }
    }

    return AnalyticsSummary(
      totalSales: sales,
      totalOrders: current.length,
      averageOrderValue: current.isEmpty ? 0 : sales / current.length,
      itemsSold: items,
      newCustomers: newCustomers,
      returningCustomers: returning,
      salesTrendPercent: _trend(sales, priorSales),
      ordersTrendPercent: _trend(
        current.length.toDouble(),
        prior.length.toDouble(),
      ),
    );
  }

  /// Null when there is nothing to compare against. Growth from zero is not a
  /// percentage, and rendering it as one would print an infinity.
  static double? _trend(double now, double before) {
    if (before <= 0) return null;
    return ((now - before) / before) * 100;
  }

  static String _customerKey(Map<String, dynamic> order) {
    final user = order['userId'];
    if (user is Map) return (user['_id'] ?? '').toString();
    final id = (user ?? '').toString();
    return id.isNotEmpty ? id : (order['customerPhone'] ?? '').toString();
  }

  static double _total(Map<String, dynamic> order) =>
      _asNum(_asMap(order['pricing'])['total'])?.toDouble() ?? 0;

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  static List<Map<String, dynamic>> _asList(dynamic v) => v is List
      ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : const [];

  static num? _asNum(dynamic v) =>
      v is num ? v : num.tryParse((v ?? '').toString());

  static DateTime? _extractDeliveredAt(Map<String, dynamic> o) {
    final direct = _asDate(o['deliveredAt']);
    if (direct != null) return direct;

    final history = _asList(o['statusHistory']);
    for (final h in history.reversed) {
      final status = (h['status'] ?? '').toString();
      if (status == 'delivered' || status == 'reached_drop' || status == 'picked_up') {
        final at = _asDate(h['at'] ?? h['timestamp'] ?? h['createdAt']);
        if (at != null) return at;
      }
    }

    return _asDate(o['updatedAt'] ?? o['createdAt']);
  }

  static DateTime? _asDate(dynamic v) =>
      DateTime.tryParse((v ?? '').toString())?.toLocal();
}

final analyticsRepositoryProvider = Provider<ApiAnalyticsRepository>(
  (ref) => ApiAnalyticsRepository(ref.watch(dioProvider)),
);

/// Today against yesterday, which is what the screen's copy claims.
final analyticsSummaryProvider = FutureProvider<AnalyticsSummary>(
  (ref) => ref.watch(analyticsRepositoryProvider).getSummary(),
);

/// The same summary over an arbitrary window, for the cards whose copy says
/// "this week" rather than "today".
final analyticsSummaryForProvider =
    FutureProvider.family<AnalyticsSummary, int>(
      (ref, days) => ref.watch(analyticsRepositoryProvider).getSummary(
        days: days,
      ),
    );
