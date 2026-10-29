import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only wrapper over secure storage in the app.
///
/// Credentials live in [FlutterSecureStorage]. One-time UI flags live in
/// [SharedPreferences] instead, deliberately: they are not sensitive, and they
/// must survive [clear] so a seller who logs out is not shown onboarding again.
class TokenStorage {
  const TokenStorage(this._storage);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _sellerIdKey = 'seller_id';
  static const String _sellerStatusKey = 'seller_status';
  static const String _sellerPhoneKey = 'seller_phone';
  static const String _sellerStoreNameKey = 'seller_store_name';
  static const String _sellerSubmittedAtKey = 'seller_submitted_at';

  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';

  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);
  Future<String?> get sellerId => _storage.read(key: _sellerIdKey);
  Future<String?> get sellerStatus => _storage.read(key: _sellerStatusKey);
  Future<String?> get sellerPhone => _storage.read(key: _sellerPhoneKey);

  /// Store name and application date, kept so the pending-approval screen has
  /// something real to show. A seller awaiting approval has no access token, so
  /// there is no endpoint to re-read these from — they are captured at
  /// registration and at every successful sign-in.
  Future<String?> get sellerStoreName =>
      _storage.read(key: _sellerStoreNameKey);

  Future<String?> get sellerSubmittedAt =>
      _storage.read(key: _sellerSubmittedAtKey);

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> saveAccessToken(String accessToken) =>
      _storage.write(key: _accessTokenKey, value: accessToken);

  Future<void> saveSeller({
    String? id,
    String? status,
    String? phone,
    String? storeName,
    String? submittedAt,
  }) async {
    if (id != null) await _storage.write(key: _sellerIdKey, value: id);
    if (status != null) {
      await _storage.write(key: _sellerStatusKey, value: status);
    }
    if (phone != null) await _storage.write(key: _sellerPhoneKey, value: phone);
    if (storeName != null && storeName.isNotEmpty) {
      await _storage.write(key: _sellerStoreNameKey, value: storeName);
    }
    if (submittedAt != null && submittedAt.isNotEmpty) {
      await _storage.write(key: _sellerSubmittedAtKey, value: submittedAt);
    }
  }

  /// True when there is a stored access token to attempt a session with. The
  /// token may still be expired or evicted — the splash screen resolves that
  /// against the server.
  Future<bool> get hasSession async {
    final token = await accessToken;
    return token != null && token.isNotEmpty;
  }

  /// Wipes the credential set. One-time flags are untouched by design.
  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _sellerIdKey),
      _storage.delete(key: _sellerStatusKey),
      _storage.delete(key: _sellerPhoneKey),
      _storage.delete(key: _sellerStoreNameKey),
      _storage.delete(key: _sellerSubmittedAtKey),
    ]);
  }

  Future<bool> get hasSeenOnboarding async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  Future<void> setHasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}
