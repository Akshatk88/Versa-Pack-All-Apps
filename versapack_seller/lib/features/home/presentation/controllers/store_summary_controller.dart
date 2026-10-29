import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/features/auth/data/auth_api.dart';
import 'package:quick_commerce_seller/features/auth/domain/seller_model.dart';

/// The signed-in store, re-read from the server.
///
/// Session-scoped: registered in `resetSessionScopedProviders`.
class StoreSummaryController extends AsyncNotifier<SellerModel> {
  @override
  Future<SellerModel> build() async {
    final payload = await ref.read(authApiProvider).me();
    return SellerModel.fromJson(payload);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final payload = await ref.read(authApiProvider).me();
      return SellerModel.fromJson(payload);
    });
  }
}

final storeSummaryControllerProvider =
    AsyncNotifierProvider<StoreSummaryController, SellerModel>(
      StoreSummaryController.new,
    );
