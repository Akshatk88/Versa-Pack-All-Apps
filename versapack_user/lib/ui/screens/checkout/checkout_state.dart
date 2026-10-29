import '../../../core/errors/failure.dart';
import '../../../domain/model/delivery_slot.dart';
import '../../../domain/model/payment_method.dart';
import '../../../domain/service/checkout_validation_service.dart';

class CheckoutState {
  const CheckoutState({
    this.slot = DeliverySlot.asap,
    this.paymentMethod = PaymentMethod.upi,
    this.instructions = '',
    this.sendCutlery = false,
    this.expandedSummary = false,
    this.isPlacing = false,
    this.issues = const [],
    this.failure,
    this.shakeAddressCard = false,
  });

  final DeliverySlot slot;
  final PaymentMethod paymentMethod;
  final String instructions;
  final bool sendCutlery;
  final bool expandedSummary;
  final bool isPlacing;

  /// Blocking problems surfaced after a failed "proceed" attempt.
  final List<CheckoutIssue> issues;
  final Failure? failure;

  /// Set for one frame to trigger the address card's shake animation.
  final bool shakeAddressCard;

  bool get isScheduled => !slot.isImmediate;

  CheckoutState copyWith({
    DeliverySlot? slot,
    PaymentMethod? paymentMethod,
    String? instructions,
    bool? sendCutlery,
    bool? expandedSummary,
    bool? isPlacing,
    List<CheckoutIssue>? issues,
    Failure? failure,
    bool? shakeAddressCard,
    bool clearFailure = false,
  }) =>
      CheckoutState(
        slot: slot ?? this.slot,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        instructions: instructions ?? this.instructions,
        sendCutlery: sendCutlery ?? this.sendCutlery,
        expandedSummary: expandedSummary ?? this.expandedSummary,
        isPlacing: isPlacing ?? this.isPlacing,
        issues: issues ?? this.issues,
        failure: clearFailure ? null : (failure ?? this.failure),
        shakeAddressCard: shakeAddressCard ?? this.shakeAddressCard,
      );
}
