import 'package:dio/dio.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/features/complaints/domain/complaint_model.dart';

/// Customer complaints raised against this store.
class ApiComplaintRepository implements ComplaintRepository {
  const ApiComplaintRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<ComplaintModel>> getComplaints() async {
    final response = await _dio.get<dynamic>(
      '/food/restaurant/complaints',
      queryParameters: {'limit': 50},
    );

    final data = response.data;
    final list = data is List ? data : _asList(_asMap(data)['complaints']);

    return list.map((c) {
      final order = _asMap(c['orderId'] is Map ? c['orderId'] : c['order']);

      return ComplaintModel(
        id: (c['_id'] ?? c['id'] ?? '').toString(),
        // orderId is populated to the whole order on some responses and left
        // as a bare id on others.
        orderId: _firstNonEmpty([
          order['order_id'],
          order['_id'],
          c['orderId'],
        ]),
        customerName: _firstNonEmpty([
          c['customerName'],
          _asMap(c['userId'])['name'],
          order['customerName'],
        ], fallback: 'Customer'),
        issueType: _firstNonEmpty([
          c['issueType'],
          c['category'],
          c['subject'],
        ], fallback: 'General'),
        description: (c['description'] ?? c['message'] ?? '').toString(),
        createdAt: _asDate(c['createdAt']) ?? DateTime.now(),
        status: _toStatus((c['status'] ?? '').toString()),
        refundAmountRequested:
            _asNum(
              c['refundAmount'] ?? c['refundAmountRequested'],
            )?.toDouble() ??
            0,
        sellerResponse: _nullIfEmpty(
          c['restaurantResponse'] ?? c['sellerResponse'] ?? c['response'],
        ),
      );
    }).toList();
  }

  // Complaints are read-only for a seller: the backend exposes the list and
  // nothing that writes to it, because resolving one decides a refund and that
  // sits with support, not with the store being complained about.
  //
  // These throw rather than quietly succeeding. A seller who taps Resolve and
  // sees nothing happen assumes it worked and stops chasing the customer; an
  // error tells them where the case actually lives.
  @override
  Future<void> resolveComplaint(String complaintId, String responseText) =>
      throw const ApiException(
        message:
            'Complaints are resolved by the support team. '
            'Reply from the support chat to respond to this customer.',
      );

  @override
  Future<void> rejectComplaint(String complaintId, String reason) =>
      throw const ApiException(
        message:
            'Complaints are reviewed by the support team. '
            'Raise your side of the case from the support chat.',
      );

  static ComplaintStatus _toStatus(String wire) {
    switch (wire.toLowerCase()) {
      case 'resolved':
      case 'closed':
        return ComplaintStatus.resolved;
      case 'rejected':
      case 'declined':
        return ComplaintStatus.rejected;
      default:
        return ComplaintStatus.open;
    }
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

  static String? _nullIfEmpty(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  static String _firstNonEmpty(List<dynamic> values, {String fallback = ''}) {
    for (final v in values) {
      final s = (v ?? '').toString().trim();
      if (s.isNotEmpty) return s;
    }
    return fallback;
  }
}
