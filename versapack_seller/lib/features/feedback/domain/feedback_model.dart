class FeedbackModel {
  final String id;
  final String customerName;
  final double rating;
  final String reviewText;
  final DateTime createdAt;
  final String? sellerReply;
  final String orderId;

  const FeedbackModel({
    required this.id,
    required this.customerName,
    required this.rating,
    required this.reviewText,
    required this.createdAt,
    this.sellerReply,
    required this.orderId,
  });

  FeedbackModel copyWith({String? sellerReply}) {
    return FeedbackModel(
      id: id,
      customerName: customerName,
      rating: rating,
      reviewText: reviewText,
      createdAt: createdAt,
      sellerReply: sellerReply ?? this.sellerReply,
      orderId: orderId,
    );
  }
}

abstract class FeedbackRepository {
  Future<List<FeedbackModel>> getFeedbackList();
  Future<void> replyToFeedback(String feedbackId, String reply);
}
