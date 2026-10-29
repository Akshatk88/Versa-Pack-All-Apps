import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:quick_commerce_seller/features/support/domain/cms_page_model.dart';
import 'package:quick_commerce_seller/features/support/domain/support_repository.dart';

class ApiSupportRepository implements SupportRepository {
  const ApiSupportRepository(this._dio);

  final Dio _dio;

  @override
  Future<CmsPageModel> getPrivacyPolicy() async {
    try {
      final response = await _dio.get<dynamic>('/food/restaurant/privacy');
      if (response.data != null) {
        return CmsPageModel.fromJson(_asMap(response.data));
      }
    } on DioException catch (e) {
      debugPrint('GET /food/restaurant/privacy failed: ${e.message}, trying fallback CMS endpoint');
    }

    final response = await _dio.get<dynamic>(
      '/food/pages/privacy',
      queryParameters: {'module': 'RESTAURANT'},
    );
    return CmsPageModel.fromJson(_asMap(response.data));
  }

  @override
  Future<CmsPageModel> getFaqHelpCenter() async {
    try {
      final response = await _dio.get<dynamic>('/food/restaurant/faq');
      if (response.data != null) {
        return CmsPageModel.fromJson(_asMap(response.data));
      }
    } on DioException catch (e) {
      debugPrint('GET /food/restaurant/faq failed: ${e.message}, trying help-center endpoint');
    }

    try {
      final response = await _dio.get<dynamic>('/food/restaurant/help-center');
      if (response.data != null) {
        return CmsPageModel.fromJson(_asMap(response.data));
      }
    } on DioException catch (e) {
      debugPrint('GET /food/restaurant/help-center failed: ${e.message}, trying fallback CMS endpoint');
    }

    final response = await _dio.get<dynamic>(
      '/food/pages/faq',
      queryParameters: {'module': 'RESTAURANT'},
    );
    return CmsPageModel.fromJson(_asMap(response.data));
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
}
