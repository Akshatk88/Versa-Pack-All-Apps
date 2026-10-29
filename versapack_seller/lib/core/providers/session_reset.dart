import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/features/home/presentation/controllers/store_summary_controller.dart';

/// Invalidates every session-scoped controller.
///
/// None of the data controllers are `autoDispose`, so they survive a logout and
/// would otherwise show the previous seller's data to the next one. Called on
/// login, on logout, and on a forced session expiry.
///
/// **Every new session-scoped controller must be added here.** This is the one
/// place that guarantees seller A's numbers never appear in seller B's app.
void resetSessionScopedProviders(Ref ref) {
  ref.invalidate(storeSummaryControllerProvider);
}
