/// The signed-in seller (a `RESTAURANT` in the backend's vocabulary).
///
/// Parsing is totally defensive: every field has a fallback so a payload that
/// drifts can never throw inside a controller. Plain Dart — no Flutter,
/// Riverpod, or Dio imports.
class SellerModel {
  const SellerModel({
    required this.id,
    required this.name,
    required this.storeName,
    required this.phone,
    required this.email,
    required this.status,
    required this.imageUrl,
    required this.isAcceptingOrders,
    required this.rating,
    required this.totalRatings,
    required this.createdAt,
  });

  factory SellerModel.fromJson(Map<String, dynamic> json) {
    num? asNum(dynamic v) => v is num ? v : num.tryParse((v ?? '').toString());

    return SellerModel(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      // `name` on a seller document is the store's name, not a person's, so the
      // owner is read from `ownerName` and `name` only as a fallback.
      name: (json['ownerName'] ?? json['name'] ?? '').toString(),
      // The backend exposes the store under `restaurantName` and falls back to
      // `name` for older records.
      storeName: (json['restaurantName'] ?? json['name'] ?? '').toString(),
      // A seller document carries no plain `phone`/`email`: the contact details
      // live on the owner, with the store's public line under
      // `primaryContactNumber`. Reading only `phone`/`email` left both blank
      // everywhere they are shown.
      phone:
          (json['ownerPhone'] ??
                  json['primaryContactNumber'] ??
                  json['phone'] ??
                  '')
              .toString(),
      email: (json['ownerEmail'] ?? json['email'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      imageUrl: (json['profileImage'] ?? json['image'] ?? '').toString(),
      // Explicit false means closed. Absent means the payload simply does not
      // carry it -- `/food/auth/me` never does -- and treating that as closed
      // made every seller's store look shut the moment their session was
      // restored from storage. The store document is the authority; until it
      // says otherwise, an approved seller is assumed to be trading.
      isAcceptingOrders: json['isAcceptingOrders'] is bool
          ? json['isAcceptingOrders'] as bool
          : true,
      rating: asNum(json['rating'])?.toDouble() ?? 0,
      totalRatings: asNum(json['totalRatings'])?.toInt() ?? 0,
      // Mongo timestamps. Kept as the raw string; the UI formats it, and an
      // unparseable value simply renders as unknown rather than throwing.
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }

  final String id;
  final String name;
  final String storeName;
  final String phone;
  final String email;

  /// One of `pending`, `approved`, `rejected` per the backend's enum.
  final String status;
  final String imageUrl;
  final bool isAcceptingOrders;
  final double rating;
  final int totalRatings;

  /// ISO-8601 creation timestamp, or empty when the payload omits it.
  final String createdAt;

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  /// What to show as the store's title, never empty.
  String get displayName =>
      storeName.isNotEmpty ? storeName : (name.isNotEmpty ? name : 'My store');
}
