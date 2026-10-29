enum OrderStatus { newOrder, preparing, ready, delivered, cancelled }

class OrderItemModel {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final String? variant;
  final List<String> addons;

  /// Snapshotted on the order line at purchase time, so it still resolves after
  /// the seller edits or delists the product. Empty for older orders.
  final String? imageUrl;

  const OrderItemModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.variant,
    this.addons = const [],
    this.imageUrl,
  });

  double get totalPrice => price * quantity;
}

class CustomerModel {
  final String name;
  final String phone;
  final String address;
  final String? instructions;

  const CustomerModel({
    required this.name,
    required this.phone,
    required this.address,
    this.instructions,
  });
}

class OrderModel {
  final String id;
  final String orderNumber;
  final CustomerModel customer;
  final List<OrderItemModel> items;
  final OrderStatus status;
  final DateTime createdAt;
  final double subtotal;
  final double tax;
  final double deliveryFee;
  final double discount;
  final double totalAmount;
  final String paymentMethod;
  final String? deliveryRiderName;
  final String? deliveryRiderPhone;

  /// The seller's own store, as recorded on the order. Shown so an account
  /// running more than one outlet can tell which one the order is for.
  final String? storeName;

  /// Store → customer distance and drive time. Both null on orders placed
  /// before the backend started resolving a route, so every use is optional.
  final double? distanceKm;
  final int? durationMinutes;

  /// Pickup and drop coordinates, when the order carries them.
  ///
  /// Only the single-order route populates the store's `location`, so these are
  /// routinely null on orders taken from the list. Everything that reads them
  /// hides itself rather than guessing a position — a map pin in the wrong
  /// place is worse than no map.
  final double? storeLat;
  final double? storeLng;
  final double? customerLat;
  final double? customerLng;

  bool get hasRoute =>
      storeLat != null &&
      storeLng != null &&
      customerLat != null &&
      customerLng != null;

  const OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customer,
    required this.items,
    required this.status,
    required this.createdAt,
    required this.subtotal,
    required this.tax,
    required this.deliveryFee,
    required this.discount,
    required this.totalAmount,
    required this.paymentMethod,
    this.deliveryRiderName,
    this.deliveryRiderPhone,
    this.storeName,
    this.distanceKm,
    this.durationMinutes,
    this.storeLat,
    this.storeLng,
    this.customerLat,
    this.customerLng,
  });

  OrderModel copyWith({
    OrderStatus? status,
    String? deliveryRiderName,
    String? deliveryRiderPhone,
  }) {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      customer: customer,
      items: items,
      status: status ?? this.status,
      createdAt: createdAt,
      subtotal: subtotal,
      tax: tax,
      deliveryFee: deliveryFee,
      discount: discount,
      totalAmount: totalAmount,
      paymentMethod: paymentMethod,
      deliveryRiderName: deliveryRiderName ?? this.deliveryRiderName,
      deliveryRiderPhone: deliveryRiderPhone ?? this.deliveryRiderPhone,
      storeName: storeName,
      distanceKm: distanceKm,
      durationMinutes: durationMinutes,
      storeLat: storeLat,
      storeLng: storeLng,
      customerLat: customerLat,
      customerLng: customerLng,
    );
  }
}
