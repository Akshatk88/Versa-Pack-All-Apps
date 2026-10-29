import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/providers/repository_providers.dart';
import 'package:quick_commerce_seller/features/support/domain/cms_page_model.dart';

final privacyPolicyProvider = FutureProvider<CmsPageModel>((ref) async {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getPrivacyPolicy();
});

final helpCenterFaqProvider = FutureProvider<CmsPageModel>((ref) async {
  final repo = ref.watch(supportRepositoryProvider);
  return repo.getFaqHelpCenter();
});
