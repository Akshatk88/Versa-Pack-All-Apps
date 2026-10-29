import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_model.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_repository.dart';

final payoutSummaryProvider =
    AsyncNotifierProvider<PayoutSummaryController, PayoutSummaryModel>(
      PayoutSummaryController.new,
    );

class PayoutSummaryController extends AsyncNotifier<PayoutSummaryModel> {
  PayoutRepository get _repository => ref.read(payoutRepositoryProvider);

  @override
  Future<PayoutSummaryModel> build() async {
    ref.watch(payoutRepositoryProvider);
    return _repository.getPayoutSummary();
  }

  Future<bool> requestPayout(double amount) async {
    final success = await _repository.requestInstantPayout(amount);
    if (success) {
      state = await AsyncValue.guard(() => _repository.getPayoutSummary());
      ref.invalidate(payoutTransactionsProvider);
    }
    return success;
  }
}

final payoutTransactionsProvider = FutureProvider<List<PayoutTransactionModel>>(
  (ref) async {
    final repository = ref.watch(payoutRepositoryProvider);
    return repository.getPayoutTransactions();
  },
);

final bankDetailsControllerProvider =
    AsyncNotifierProvider<BankDetailsController, BankDetailsModel>(
      BankDetailsController.new,
    );

class BankDetailsController extends AsyncNotifier<BankDetailsModel> {
  PayoutRepository get _repository => ref.read(payoutRepositoryProvider);

  @override
  Future<BankDetailsModel> build() async {
   ref.watch(payoutRepositoryProvider);
    return _repository.getBankDetails();
  }

  Future<void> updateBankDetails(BankDetailsModel details) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repository.updateBankDetails(details);
      return details;
    });
  }
}
