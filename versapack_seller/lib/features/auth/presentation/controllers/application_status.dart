import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:quick_commerce_seller/core/providers/core_providers.dart';

/// What the app knows about a seller who cannot sign in yet.
///
/// A seller awaiting approval — or rejected — has no access token, so there is
/// **no endpoint to read their application from**. `GET /food/auth/me` and
/// `/food/restaurant/current` both require a Bearer token, and the public
/// restaurant list filters on `status: 'approved'`. The backend only reveals
/// the decision as the error message on verify-otp.
///
/// So these values are captured at registration and at every successful
/// sign-in, and the live status comes from the auth state.
class ApplicationSummary {
  const ApplicationSummary({
    required this.storeName,
    required this.applicationId,
    required this.submittedAt,
    required this.phone,
  });

  final String storeName;
  final String applicationId;
  final String submittedAt;
  final String phone;

  bool get hasStoreName => storeName.isNotEmpty;
  bool get hasApplicationId => applicationId.isNotEmpty;

  /// The seller-facing reference. The raw Mongo id is 24 hex characters, which
  /// is unreadable over the phone to support — the last 8, upper-cased, is
  /// enough to identify the record and short enough to read aloud.
  String get referenceCode => applicationId.isEmpty
      ? ''
      : 'APZ-${applicationId.substring(applicationId.length > 8 ? applicationId.length - 8 : 0).toUpperCase()}';

  /// Formatted submission date, or empty when it was never captured (for
  /// instance, a seller who registered on another device).
  String get submittedOnLabel {
    if (submittedAt.isEmpty) return '';
    final parsed = DateTime.tryParse(submittedAt);
    if (parsed == null) return '';
    return DateFormat('d MMM yyyy, h:mm a').format(parsed.toLocal());
  }
}

final applicationSummaryProvider = FutureProvider<ApplicationSummary>((
  ref,
) async {
  final storage = ref.watch(tokenStorageProvider);
  return ApplicationSummary(
    storeName: await storage.sellerStoreName ?? '',
    applicationId: await storage.sellerId ?? '',
    submittedAt: await storage.sellerSubmittedAt ?? '',
    phone: await storage.sellerPhone ?? '',
  );
});
