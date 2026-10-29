import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_commerce_seller/features/feedback/domain/feedback_model.dart';

/// Customer reviews of this store.
///
/// The backend keeps per-order ratings on the order itself and only an
/// aggregate on the store; there is no endpoint that lists reviews. Rather than
/// invent one, the individual ratings are read back off the seller's own
/// delivered orders, which is the same data seen from the side that is
/// actually exposed.
class ApiFeedbackRepository implements FeedbackRepository {
  const ApiFeedbackRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<FeedbackModel>> getFeedbackList() async {
    final response = await _dio.get<dynamic>(
      '/food/restaurant/orders',
      queryParameters: {'status': 'delivered', 'limit': 50},
    );

    final data = _asMap(response.data);
    final orders = _asList(data['orders'] ?? data['data']);

    final reviews = <FeedbackModel>[];
    for (final order in orders) {
      final ratings = _asMap(order['ratings']);
      // The store's own rating, not the rider's -- a seller should not be
      // shown, or judged by, feedback about the delivery.
      final score = _asNum(
        ratings['restaurant'] ?? ratings['restaurantRating'] ?? order['rating'],
      )?.toDouble();
      if (score == null || score <= 0) continue;

      reviews.add(
        FeedbackModel(
          id: (order['_id'] ?? '').toString(),
          customerName: _firstNonEmpty([
            order['customerName'],
            _asMap(order['deliveryAddress'])['fullName'],
          ], fallback: 'Customer'),
          rating: score,
          reviewText: (ratings['restaurantComment'] ?? ratings['comment'] ?? '')
              .toString(),
          createdAt:
              _asDate(ratings['ratedAt'] ?? order['deliveredAt']) ??
              DateTime.now(),
          sellerReply: null,
          orderId: (order['order_id'] ?? order['_id'] ?? '').toString(),
        ),
      );
    }

    return reviews;
  }

  @override
  Future<void> replyToFeedback(String feedbackId, String reply) async {
    // Logging reply action as backend has no reply endpoint currently.
    debugPrint('--------------------------------------------------');
    debugPrint('>>> [REPLY TO FEEDBACK]');
    debugPrint('Feedback ID: $feedbackId');
    debugPrint('Reply Text: $reply');
    debugPrint('--------------------------------------------------');
  }

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
}
