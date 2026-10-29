import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/feedback/domain/feedback_model.dart';

final feedbackControllerProvider =
    AsyncNotifierProvider<FeedbackController, List<FeedbackModel>>(
      FeedbackController.new,
    );

class FeedbackController extends AsyncNotifier<List<FeedbackModel>> {
  late final FeedbackRepository _repository;

  @override
  Future<List<FeedbackModel>> build() async {
    _repository = ref.watch(feedbackRepositoryProvider);
    return _repository.getFeedbackList();
  }

  Future<void> reply(String feedbackId, String text) async {
    await _repository.replyToFeedback(feedbackId, text);
    state = await AsyncValue.guard(() => _repository.getFeedbackList());
  }
}
