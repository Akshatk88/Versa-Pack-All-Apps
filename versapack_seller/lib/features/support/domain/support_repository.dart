import 'package:quick_commerce_seller/features/support/domain/cms_page_model.dart';

abstract class SupportRepository {
  Future<CmsPageModel> getPrivacyPolicy();
  Future<CmsPageModel> getFaqHelpCenter();
}
