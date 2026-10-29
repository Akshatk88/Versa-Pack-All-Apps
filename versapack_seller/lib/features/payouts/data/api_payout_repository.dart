import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_model.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_repository.dart';

/// Earnings, settlement history and bank details.
///
/// `/food/restaurant/finance` answers all of it in one call: the current cycle
/// is what is still owed, past cycles are what has been settled. Bank details
/// live on the store document, not in finance.
class ApiPayoutRepository implements PayoutRepository {
  const ApiPayoutRepository(this._dio);

  final Dio _dio;

  @override
  Future<PayoutSummaryModel> getPayoutSummary() async {
    try {
      final finance = await _finance();
      final wallet = _asMap(finance['wallet']);
      final current = _asMap(finance['currentCycle']);
      final past = _asMap(finance['pastCycles']);

      double pick(String key) =>
          _asNum(wallet[key])?.toDouble() ??
          _asNum(current[key])?.toDouble() ??
          _asNum(finance[key])?.toDouble() ??
          0;

      final settled = _asList(past['orders']);
      Map<String, dynamic>? firstSettled;
      if (settled.isNotEmpty) {
        firstSettled = settled.first;
      }

      final withdrawable = pick('withdrawableBalance') > 0
          ? pick('withdrawableBalance')
          : pick('balance');

      final pending = pick('estimatedPayout') > 0
          ? pick('estimatedPayout')
          : pick('pendingBalance');

      return PayoutSummaryModel(
        totalEarnings: pick('totalEarnings'),
        availableBalance: withdrawable,
        pendingPayout: pending,
        lastPayoutAmount: firstSettled == null
            ? 0
            : _asNum(firstSettled['amount'] ?? firstSettled['netAmount'])?.toDouble() ?? 0,
        lastPayoutDate: firstSettled == null
            ? null
            : _asDate(firstSettled['payoutDate'] ?? firstSettled['createdAt']),
      );
    } catch (e, st) {
      debugPrint('Error in getPayoutSummary: $e\n$st');
      return const PayoutSummaryModel(
        totalEarnings: 0,
        availableBalance: 0,
        pendingPayout: 0,
        lastPayoutAmount: 0,
        lastPayoutDate: null,
      );
    }
  }

  @override
  Future<List<PayoutTransactionModel>> getPayoutTransactions() async {
    try {
      final finance = await _finance();

      final currentOrders = _asList(_asMap(finance['currentCycle'])['orders']);
      final pastOrders = _asList(_asMap(finance['pastCycles'])['orders']);
      final directOrders = _asList(
        finance['transactions'] ?? finance['orders'] ?? finance['history'],
      );

      final rows = [...currentOrders, ...pastOrders, ...directOrders];

      final result = <PayoutTransactionModel>[];
      for (final r in rows) {
        try {
          final amount =
              _asNum(
                r['netAmount'] ?? r['amount'] ?? r['payoutAmount'],
              )?.toDouble() ??
              0;
          result.add(
            PayoutTransactionModel(
              id: (r['_id'] ?? r['id'] ?? r['orderId'] ?? '').toString(),
              referenceNumber:
                  (r['order_id'] ?? r['orderId'] ?? r['reference'] ?? r['_id'] ?? '')
                      .toString(),
              amount: amount,
              date: _asDate(r['payoutDate'] ?? r['createdAt'] ?? r['date']) ??
                  DateTime.now(),
              status: _toStatus((r['payoutStatus'] ?? r['status'] ?? '').toString()),
              payoutMethod:
                  (r['payoutMethod'] ?? r['paymentMethod'] ?? '').toString(),
            ),
          );
        } catch (e) {
          debugPrint('Error parsing transaction row: $e');
        }
      }
      return result;
    } catch (e, st) {
      debugPrint('Error in getPayoutTransactions: $e\n$st');
      return [];
    }
  }

  @override
  Future<BankDetailsModel> getBankDetails() async {
    try {
      final store = await _currentStore();

      debugPrint('--------------------------------------------------');
      debugPrint('>>> [GET BANK DETAILS RESPONSE]');
      debugPrint('Endpoint: GET /food/restaurant/current');
      debugPrint(
        'Bank Fields: {accountHolderName: ${store['accountHolderName']}, accountNumber: ${store['accountNumber']}, ifscCode: ${store['ifscCode']}, bankName: ${store['bankName']}, branchName: ${store['branchName']}, upiId: ${store['upiId']}}',
      );
      debugPrint('--------------------------------------------------');

      return BankDetailsModel(
        accountHolderName: (store['accountHolderName'] ?? '').toString(),
        accountNumber: (store['accountNumber'] ?? '').toString(),
        ifscCode: (store['ifscCode'] ?? '').toString(),
        bankName: (store['bankName'] ?? '').toString(),
        branchName: (store['branchName'] ?? '').toString(),
        upiId: (store['upiId'] ?? '').toString(),
        isVerified:
            (store['accountNumber'] ?? '').toString().isNotEmpty &&
            (store['ifscCode'] ?? '').toString().isNotEmpty,
      );
    } catch (e, st) {
      debugPrint('Error in getBankDetails: $e\n$st');
      return const BankDetailsModel(
        accountHolderName: '',
        accountNumber: '',
        ifscCode: '',
        bankName: '',
        branchName: '',
        upiId: '',
        isVerified: false,
      );
    }
  }

  @override
  Future<void> updateBankDetails(BankDetailsModel bankDetails) async {
    final payload = {
      'accountHolderName': bankDetails.accountHolderName,
      'accountNumber': bankDetails.accountNumber,
      'ifscCode': bankDetails.ifscCode,
      'bankName': bankDetails.bankName,
      'branchName': bankDetails.branchName,
      'upiId': bankDetails.upiId,
    };

    try {
      debugPrint('--------------------------------------------------');
      debugPrint('>>> [UPDATE BANK DETAILS REQUEST]');
      debugPrint('Endpoint: PATCH /food/restaurant/profile');
      debugPrint('Payload: $payload');
      debugPrint('--------------------------------------------------');

      final response = await _dio.patch<dynamic>(
        '/food/restaurant/profile',
        data: payload,
      );

      debugPrint('--------------------------------------------------');
      debugPrint('<<< [UPDATE BANK DETAILS RESPONSE SUCCESS]');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('--------------------------------------------------');
    } on DioException catch (e) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [UPDATE BANK DETAILS RESPONSE ERROR]');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('--------------------------------------------------');
      rethrow;
    } catch (e, stackTrace) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [UPDATE BANK DETAILS UNEXPECTED ERROR]');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('--------------------------------------------------');
      rethrow;
    }
  }

  @override
  Future<bool> requestInstantPayout(double amount) async {
    final payload = {'amount': amount};
    try {
      debugPrint('--------------------------------------------------');
      debugPrint('>>> [INSTANT PAYOUT / WITHDRAWAL REQUEST]');
      debugPrint('Endpoint: POST /food/restaurant/withdraw');
      debugPrint('Payload: $payload');
      debugPrint('--------------------------------------------------');

      final response = await _dio.post<dynamic>(
        '/food/restaurant/withdraw',
        data: payload,
      );

      debugPrint('--------------------------------------------------');
      debugPrint('<<< [INSTANT PAYOUT / WITHDRAWAL RESPONSE SUCCESS]');
      debugPrint('Status Code: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('--------------------------------------------------');

      final data = response.data;
      if (data is Map) {
        if (data['success'] == true) return true;
      }
      return response.statusCode == 200 || response.statusCode == 201;
    } on DioException catch (e) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [INSTANT PAYOUT / WITHDRAWAL RESPONSE ERROR]');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('--------------------------------------------------');
      return false;
    } catch (e, stackTrace) {
      debugPrint('--------------------------------------------------');
      debugPrint('<<< [INSTANT PAYOUT / WITHDRAWAL UNEXPECTED ERROR]');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('--------------------------------------------------');
      return false;
    }
  }

  Future<Map<String, dynamic>> _finance() async {
    try {
      debugPrint('--------------------------------------------------');
      debugPrint('>>> [GET FINANCE REQUEST]');
      debugPrint('Endpoint: GET /food/restaurant/finance');
      debugPrint('--------------------------------------------------');

      final response = await _dio.get<dynamic>('/food/restaurant/finance');
      
      debugPrint('<<< [GET FINANCE RESPONSE SUCCESS]: ${response.statusCode}');
      debugPrint('Response Data: ${response.data}');
      debugPrint('--------------------------------------------------');

      final rawMap = _asMap(response.data);
      if (rawMap.containsKey('data') && rawMap['data'] is Map) {
        return _asMap(rawMap['data']);
      }
      if (rawMap.containsKey('finance') && rawMap['finance'] is Map) {
        return _asMap(rawMap['finance']);
      }
      return rawMap;
    } on DioException catch (e) {
      debugPrint('<<< [GET FINANCE RESPONSE ERROR]');
      debugPrint('Status Code: ${e.response?.statusCode}');
      debugPrint('Response Data: ${e.response?.data}');
      debugPrint('Error Message: ${e.message}');
      debugPrint('--------------------------------------------------');
      return {};
    } catch (e) {
      debugPrint('<<< [GET FINANCE UNEXPECTED ERROR]: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> _currentStore() async {
    try {
      final response = await _dio.get<dynamic>('/food/restaurant/current');
      final data = _asMap(response.data);
      final nested = data['restaurant'] ?? data['data'];
      return nested is Map ? Map<String, dynamic>.from(nested) : data;
    } catch (e) {
      debugPrint('<<< [GET CURRENT STORE ERROR]: $e');
      return {};
    }
  }

  static PayoutStatus _toStatus(String wire) {
    switch (wire.toLowerCase()) {
      case 'paid':
      case 'settled':
      case 'completed':
      case 'captured':
        return PayoutStatus.completed;
      case 'failed':
      case 'reversed':
        return PayoutStatus.failed;
      default:
        return PayoutStatus.processing;
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
}
