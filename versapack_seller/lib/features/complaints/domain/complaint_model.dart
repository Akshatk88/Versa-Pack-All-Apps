enum ComplaintStatus { open, resolved, rejected }

class ComplaintModel {
  final String id;
  final String orderId;
  final String customerName;
  final String issueType;
  final String description;
  final DateTime createdAt;
  final ComplaintStatus status;
  final double refundAmountRequested;
  final String? sellerResponse;

  const ComplaintModel({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.issueType,
    required this.description,
    required this.createdAt,
    required this.status,
    required this.refundAmountRequested,
    this.sellerResponse,
  });

  ComplaintModel copyWith({ComplaintStatus? status, String? sellerResponse}) {
    return ComplaintModel(
      id: id,
      orderId: orderId,
      customerName: customerName,
      issueType: issueType,
      description: description,
      createdAt: createdAt,
      status: status ?? this.status,
      refundAmountRequested: refundAmountRequested,
      sellerResponse: sellerResponse ?? this.sellerResponse,
    );
  }
}

abstract class ComplaintRepository {
  Future<List<ComplaintModel>> getComplaints();
  Future<void> resolveComplaint(String complaintId, String responseText);
  Future<void> rejectComplaint(String complaintId, String reason);
}
