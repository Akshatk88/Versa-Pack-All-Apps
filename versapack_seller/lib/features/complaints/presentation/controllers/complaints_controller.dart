import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/complaints/domain/complaint_model.dart';

final complaintsControllerProvider =
    AsyncNotifierProvider<ComplaintsController, List<ComplaintModel>>(
      ComplaintsController.new,
    );

class ComplaintsController extends AsyncNotifier<List<ComplaintModel>> {
  late final ComplaintRepository _repository;

  @override
  Future<List<ComplaintModel>> build() async {
    _repository = ref.watch(complaintRepositoryProvider);
    return _repository.getComplaints();
  }

  Future<void> resolve(String complaintId, String responseText) async {
    await _repository.resolveComplaint(complaintId, responseText);
    state = await AsyncValue.guard(() => _repository.getComplaints());
  }

  Future<void> reject(String complaintId, String reason) async {
    await _repository.rejectComplaint(complaintId, reason);
    state = await AsyncValue.guard(() => _repository.getComplaints());
  }
}
