import 'package:quick_commerce_seller/features/payouts/domain/payout_model.dart';

abstract class PayoutRepository {
  Future<PayoutSummaryModel> getPayoutSummary();
  Future<List<PayoutTransactionModel>> getPayoutTransactions();
  Future<BankDetailsModel> getBankDetails();
  Future<void> updateBankDetails(BankDetailsModel bankDetails);
  Future<bool> requestInstantPayout(double amount);
}
