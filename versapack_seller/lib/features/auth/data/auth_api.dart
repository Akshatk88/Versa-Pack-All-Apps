import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/network/dio_client.dart';

/// Seller authentication.
///
/// Returns unwrapped maps rather than domain models because the verify-otp
/// payload is polymorphic — it is either a registration prompt or a token
/// bundle — and forcing one model over both would lose information. This is the
/// documented exception to the "repositories return domain models" rule.
class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  /// Sends an OTP to [phone]. In non-production the backend echoes the code
  /// back in the payload, which is how a developer signs in without an SMS.
  Future<Map<String, dynamic>> requestOtp(String phone) async {
    final response = await _dio.post<dynamic>(
      '/food/auth/restaurant/request-otp',
      data: {'phone': phone},
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Verifies [otp]. The result carries either `needsRegistration: true` or an
  /// `accessToken`/`refreshToken`/`user` bundle.
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
  }) async {
    final response = await _dio.post<dynamic>(
      '/food/auth/restaurant/verify-otp',
      data: {
        'phone': phone,
        'otp': otp,
        // The backend defaults an absent platform to 'web', which routes the
        // push token to the wrong device bucket.
        'platform': 'mobile',
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> me() async {
    final response = await _dio.get<dynamic>('/food/auth/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Registers this device for push, independently of signing in.
  ///
  /// `verify-otp` carries the token too, but it only ever runs on a *fresh*
  /// login — a seller who is already signed in when the app starts would never
  /// register a device, and so would never receive a push.
  Future<void> saveFcmToken(String token) async {
    await _dio.post<dynamic>('/fcm-tokens/mobile/save', data: {'token': token});
  }

  Future<void> logout({required String refreshToken, String? fcmToken}) async {
    await _dio.post<dynamic>(
      '/food/auth/logout',
      data: {
        'refreshToken': refreshToken,
        'platform': 'mobile',
        if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
      },
    );
  }
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(ref.watch(dioProvider)),
);
