enum DiscountType { percentage, fixedAmount }

class CouponModel {
  final String id;
  final String code;
  final String title;
  final String description;
  final DiscountType discountType;
  final double discountValue;
  final double minOrderAmount;
  final double? maxDiscountAmount;
  final DateTime validFrom;
  final DateTime validTill;
  final int usageCount;
  final int? usageLimit;
  final bool isActive;

  const CouponModel({
    required this.id,
    required this.code,
    required this.title,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.minOrderAmount,
    this.maxDiscountAmount,
    required this.validFrom,
    required this.validTill,
    this.usageCount = 0,
    this.usageLimit,
    this.isActive = true,
  });

  CouponModel copyWith({
    String? code,
    String? title,
    String? description,
    DiscountType? discountType,
    double? discountValue,
    double? minOrderAmount,
    double? maxDiscountAmount,
    DateTime? validFrom,
    DateTime? validTill,
    int? usageCount,
    int? usageLimit,
    bool? isActive,
  }) {
    return CouponModel(
      id: id,
      code: code ?? this.code,
      title: title ?? this.title,
      description: description ?? this.description,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      minOrderAmount: minOrderAmount ?? this.minOrderAmount,
      maxDiscountAmount: maxDiscountAmount ?? this.maxDiscountAmount,
      validFrom: validFrom ?? this.validFrom,
      validTill: validTill ?? this.validTill,
      usageCount: usageCount ?? this.usageCount,
      usageLimit: usageLimit ?? this.usageLimit,
      isActive: isActive ?? this.isActive,
    );
  }
}
