import 'address.dart';
import 'cart.dart';
import 'order_status.dart';
import 'payment_method.dart';

/// A line inside a placed order. Kept separate from [CartItem] because the
/// backend snapshots names/prices at order time and never re-resolves them.
class OrderLine {
  const OrderLine({
    required this.itemId,
    required this.name,
    required this.price,
    required this.quantity,
    this.variantName = '',
    this.imageUrl = '',
    this.isVeg = true,
    this.addonNames = const [],
  });

  final String itemId;
  final String name;
  final double price;
  final int quantity;
  final String variantName;
  final String imageUrl;
  final bool isVeg;
  final List<String> addonNames;

  double get lineTotal => price * quantity;
}

/// The assigned rider, present once dispatch has accepted.
class DeliveryPartner {
  const DeliveryPartner({
    required this.name,
    this.phone = '',
    this.rating = 0,
    this.photoUrl = '',
    this.vehicleNumber = '',
  });

  final String name;
  final String phone;
  final double rating;
  final String photoUrl;
  final String vehicleNumber;
}

/// A geographic point used by the tracking screen.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  // Value equality so a `select` on the rider position only rebuilds the map
  // when the coordinates actually changed — not on every identical GPS ping.
  @override
  bool operator ==(Object other) =>
      other is GeoPoint &&
      other.latitude == latitude &&
      other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Route between rider and target, from `GET /orders/:id/route`.
class OrderRoute {
  const OrderRoute({
    this.polyline = '',
    this.distanceKm,
    this.durationMins,
    this.origin,
    this.destination,
    this.target = '',
  });

  final String polyline;
  final double? distanceKm;
  final int? durationMins;
  final GeoPoint? origin;
  final GeoPoint? destination;
  final String target;

  static const empty = OrderRoute();
}

class Order {
  const Order({
    required this.id,
    required this.displayId,
    required this.status,
    required this.lines,
    required this.pricing,
    required this.placedAt,
    this.address,
    this.sellerId = '',
    this.sellerName = '',
    this.sellerImageUrl = '',
    this.paymentMethod = PaymentMethod.upi,
    this.paymentStatus = '',
    this.deliveryPartner,
    this.dropOtp = '',
    this.etaMinutes,
    this.deliveredAt,
    this.cancelledAt,
    this.cancellationReason = '',
    this.instructions = '',
    this.restaurantRating,
    this.riderLocation,
    this.statusTimestamps = const {},
  });

  final String id;
  final String displayId;
  final OrderStatus status;
  final List<OrderLine> lines;
  final CartPricing pricing;
  final DateTime placedAt;
  final Address? address;
  final String sellerId;
  final String sellerName;
  final String sellerImageUrl;
  final PaymentMethod paymentMethod;
  final String paymentStatus;
  final DeliveryPartner? deliveryPartner;
  final String dropOtp;
  final int? etaMinutes;
  final DateTime? deliveredAt;
  final DateTime? cancelledAt;
  final String cancellationReason;
  final String instructions;
  final double? restaurantRating;
  final GeoPoint? riderLocation;

  /// Milestone → when it was reached, derived from the backend status history.
  final Map<TrackingStep, DateTime> statusTimestamps;

  int get itemCount => lines.fold(0, (sum, l) => sum + l.quantity);

  bool get isRated => restaurantRating != null && restaurantRating! > 0;

  TrackingStep get currentStep => TrackingStep.forStatus(status);

  bool isStepReached(TrackingStep step) {
    if (status.isCancelled) return step == TrackingStep.placed;
    return step.index <= currentStep.index;
  }

  bool get awaitsPayment => status == OrderStatus.pendingPayment;

  Order copyWith({
    OrderStatus? status,
    String? dropOtp,
    GeoPoint? riderLocation,
    DeliveryPartner? deliveryPartner,
    int? etaMinutes,
  }) =>
      Order(
        id: id,
        displayId: displayId,
        status: status ?? this.status,
        lines: lines,
        pricing: pricing,
        placedAt: placedAt,
        address: address,
        sellerId: sellerId,
        sellerName: sellerName,
        sellerImageUrl: sellerImageUrl,
        paymentMethod: paymentMethod,
        paymentStatus: paymentStatus,
        deliveryPartner: deliveryPartner ?? this.deliveryPartner,
        dropOtp: dropOtp ?? this.dropOtp,
        etaMinutes: etaMinutes ?? this.etaMinutes,
        deliveredAt: deliveredAt,
        cancelledAt: cancelledAt,
        cancellationReason: cancellationReason,
        instructions: instructions,
        restaurantRating: restaurantRating,
        riderLocation: riderLocation ?? this.riderLocation,
        statusTimestamps: statusTimestamps,
      );

  @override
  bool operator ==(Object other) => other is Order && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Payload returned by order creation: the order plus any gateway handoff.
/// An order the backend has created. When it is an online-payment order the
/// backend has also created the matching Razorpay order and handed back the
/// checkout parameters — `POST /food/orders` → `razorpay: {key, orderId,
/// amount, currency}`.
class PlacedOrder {
  const PlacedOrder({
    required this.order,
    this.gatewayOrderId,
    this.gatewayKey,
    this.gatewayAmountPaise = 0,
    this.gatewayCurrency = 'INR',
  });

  final Order order;
  final String? gatewayOrderId;
  final String? gatewayKey;

  /// Amount in the smallest currency unit, exactly as Razorpay recorded it.
  /// Never recomputed here — the backend compares this against the captured
  /// payment paise-for-paise.
  final int gatewayAmountPaise;
  final String gatewayCurrency;

  bool get needsGatewayPayment =>
      gatewayOrderId != null && gatewayOrderId!.isNotEmpty;
}
