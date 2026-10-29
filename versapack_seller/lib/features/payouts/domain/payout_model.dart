enum PayoutStatus { completed, processing, failed }

class BankDetailsModel {
  final String accountHolderName;
  final String accountNumber;
  final String ifscCode;
  final String bankName;
  final String branchName;
  final String upiId;
  final bool isVerified;

  const BankDetailsModel({
    required this.accountHolderName,
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
    required this.branchName,
    required this.upiId,
    this.isVerified = true,
  });

  BankDetailsModel copyWith({
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? bankName,
    String? branchName,
    String? upiId,
    bool? isVerified,
  }) {
    return BankDetailsModel(
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      bankName: bankName ?? this.bankName,
      branchName: branchName ?? this.branchName,
      upiId: upiId ?? this.upiId,
      isVerified: isVerified ?? this.isVerified,
    );
  }
}

class PayoutTransactionModel {
  final String id;
  final String referenceNumber;
  final double amount;
  final DateTime date;
  final PayoutStatus status;
  final String payoutMethod;

  const PayoutTransactionModel({
    required this.id,
    required this.referenceNumber,
    required this.amount,
    required this.date,
    required this.status,
    required this.payoutMethod,
  });
}

class PayoutSummaryModel {
  final double totalEarnings;
  final double availableBalance;
  final double pendingPayout;
  final double lastPayoutAmount;
  final DateTime? lastPayoutDate;

  const PayoutSummaryModel({
    required this.totalEarnings,
    required this.availableBalance,
    required this.pendingPayout,
    required this.lastPayoutAmount,
    this.lastPayoutDate,
  });
}
