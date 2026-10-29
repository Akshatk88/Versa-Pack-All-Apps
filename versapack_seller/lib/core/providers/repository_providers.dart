import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';
import 'package:quick_commerce_seller/features/complaints/data/api_complaint_repository.dart';
import 'package:quick_commerce_seller/features/feedback/data/api_feedback_repository.dart';
import 'package:quick_commerce_seller/features/notifications/data/api_notification_repository.dart';
import 'package:quick_commerce_seller/features/support/data/api_support_repository.dart';
import 'package:quick_commerce_seller/features/support/domain/support_repository.dart';
import 'package:quick_commerce_seller/features/complaints/domain/complaint_model.dart';
import 'package:quick_commerce_seller/features/explore/data/api_explore_repository.dart';
import 'package:quick_commerce_seller/features/explore/domain/explore_repository.dart';
import 'package:quick_commerce_seller/features/feedback/domain/feedback_model.dart';
import 'package:quick_commerce_seller/features/inventory/data/api_inventory_repository.dart';
import 'package:quick_commerce_seller/features/inventory/domain/inventory_repository.dart';
import 'package:quick_commerce_seller/features/notifications/domain/notification_model.dart';
import 'package:quick_commerce_seller/features/offers/data/api_offer_repository.dart';
import 'package:quick_commerce_seller/features/offers/domain/offer_repository.dart';
import 'package:quick_commerce_seller/features/orders/data/api_order_repository.dart';
import 'package:quick_commerce_seller/features/orders/domain/order_repository.dart';
import 'package:quick_commerce_seller/features/payouts/data/api_payout_repository.dart';
import 'package:quick_commerce_seller/features/payouts/domain/payout_repository.dart';

/// Centralized Dependency Injection Repository Providers.
///
/// Every repository here is backed by the live API over the shared [dioProvider].
/// There is no mock implementation left in the app, and none should be added —
/// a screen that renders invented data is indistinguishable from one that works.

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return ApiOrderRepository(ref.watch(dioProvider));
});

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return ApiInventoryRepository(ref.watch(dioProvider));
});

final payoutRepositoryProvider = Provider<PayoutRepository>((ref) {
  return ApiPayoutRepository(ref.watch(dioProvider));
});

final offerRepositoryProvider = Provider<OfferRepository>((ref) {
  return ApiOfferRepository(ref.watch(dioProvider));
});

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ApiExploreRepository(ref.watch(dioProvider));
});

final complaintRepositoryProvider = Provider<ComplaintRepository>((ref) {
  return ApiComplaintRepository(ref.watch(dioProvider));
});

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return ApiFeedbackRepository(ref.watch(dioProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return ApiNotificationRepository(ref.watch(dioProvider));
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return ApiSupportRepository(ref.watch(dioProvider));
});
