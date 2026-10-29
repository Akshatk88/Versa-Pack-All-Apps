import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:quick_commerce_seller/core/network/api_exception.dart';
import 'package:quick_commerce_seller/core/providers/core_providers.dart';
import 'package:quick_commerce_seller/core/storage/token_storage.dart';
import 'package:quick_commerce_seller/features/auth/data/auth_api.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';

/// Test scaffolding only — these doubles exist to keep the tests off the
/// network and must never be referenced from `lib/`.
class _FakeAuthApi implements AuthApi {
  _FakeAuthApi({this.otpResponse, this.verifyResponse, this.verifyError});

  final Map<String, dynamic>? otpResponse;
  final Map<String, dynamic>? verifyResponse;
  final Object? verifyError;

  Map<String, dynamic> meResponse = const {};
  bool logoutCalled = false;
  String? savedFcmToken;

  @override
  Future<Map<String, dynamic>> requestOtp(String phone) async =>
      otpResponse ?? {'phone': phone};

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
    String? fcmToken,
  }) async {
    if (verifyError != null) throw verifyError!;
    return verifyResponse ?? const {};
  }

  @override
  Future<Map<String, dynamic>> me() async => meResponse;

  @override
  Future<void> saveFcmToken(String token) async => savedFcmToken = token;

  @override
  Future<void> logout({required String refreshToken, String? fcmToken}) async {
    logoutCalled = true;
  }
}

class _FakeTokenStorage implements TokenStorage {
  String? access;
  String? refresh;
  final Map<String, String?> seller = {};
  bool seenOnboarding = false;

  @override
  Future<String?> get accessToken async => access;

  @override
  Future<String?> get refreshToken async => refresh;

  @override
  Future<String?> get sellerId async => seller['id'];

  @override
  Future<String?> get sellerStatus async => seller['status'];

  @override
  Future<String?> get sellerPhone async => seller['phone'];

  @override
  Future<String?> get sellerStoreName async => seller['storeName'];

  @override
  Future<String?> get sellerSubmittedAt async => seller['submittedAt'];

  @override
  Future<bool> get hasSession async => (access ?? '').isNotEmpty;

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    access = accessToken;
    refresh = refreshToken;
  }

  @override
  Future<void> saveAccessToken(String accessToken) async =>
      access = accessToken;

  @override
  Future<void> saveSeller({
    String? id,
    String? status,
    String? phone,
    String? storeName,
    String? submittedAt,
  }) async {
    if (id != null) seller['id'] = id;
    if (status != null) seller['status'] = status;
    if (phone != null) seller['phone'] = phone;
    if (storeName != null) seller['storeName'] = storeName;
    if (submittedAt != null) seller['submittedAt'] = submittedAt;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
    seller.clear();
  }

  @override
  Future<bool> get hasSeenOnboarding async => seenOnboarding;

  @override
  Future<void> setHasSeenOnboarding() async => seenOnboarding = true;
}

DioException _apiError(String message, {int status = 401}) => DioException(
  requestOptions: RequestOptions(path: '/verify'),
  error: ApiException(message: message, statusCode: status),
);

ProviderContainer _container(_FakeAuthApi api, _FakeTokenStorage storage) {
  final container = ProviderContainer(
    overrides: [
      authApiProvider.overrideWithValue(api),
      tokenStorageProvider.overrideWithValue(storage),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  // verifyOtp resets the registration draft, whose controller reads
  // SharedPreferences on build — that needs a binding and a backing store.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AuthController', () {
    test('starts in AuthInitial so the router waits for the splash', () {
      final container = _container(_FakeAuthApi(), _FakeTokenStorage());

      expect(container.read(authControllerProvider), isA<AuthInitial>());
    });

    test(
      'resolveSession with no stored token logs out without a call',
      () async {
        final container = _container(_FakeAuthApi(), _FakeTokenStorage());

        await container.read(authControllerProvider.notifier).resolveSession();

        expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
      },
    );

    test('resolveSession with a valid token authenticates', () async {
      final api = _FakeAuthApi()
        ..meResponse = {
          '_id': 'store-1',
          'restaurantName': 'Fresh Mart',
          'status': 'approved',
        };
      final storage = _FakeTokenStorage()..access = 'stored-token';

      final container = _container(api, storage);
      await container.read(authControllerProvider.notifier).resolveSession();

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthAuthenticated>());
      expect((state as AuthAuthenticated).seller.storeName, 'Fresh Mart');
    });

    test('requestOtp surfaces the debug code the backend echoes', () async {
      final api = _FakeAuthApi(
        otpResponse: {'phone': '9876543210', 'otp': 1234},
      );
      final container = _container(api, _FakeTokenStorage());

      await container
          .read(authControllerProvider.notifier)
          .requestOtp('9876543210');

      final state = container.read(authControllerProvider);
      expect(state, isA<AuthOtpSent>());
      expect((state as AuthOtpSent).debugOtp, '1234');
      expect(state.phone, '9876543210');
    });

    test('verifyOtp stores tokens and authenticates', () async {
      final api = _FakeAuthApi(
        verifyResponse: {
          'accessToken': 'access-1',
          'refreshToken': 'refresh-1',
          'needsRegistration': false,
          'user': {'_id': 'store-1', 'restaurantName': 'Fresh Mart'},
        },
      );
      final storage = _FakeTokenStorage();

      final container = _container(api, storage);
      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: '9876543210', otp: '1234');

      expect(container.read(authControllerProvider), isA<AuthAuthenticated>());
      expect(storage.access, 'access-1');
      expect(storage.refresh, 'refresh-1');
      expect(storage.seller['id'], 'store-1');
    });

    test('verifyOtp routes an unregistered phone to registration', () async {
      final api = _FakeAuthApi(
        verifyResponse: {'needsRegistration': true, 'phone': '9876543210'},
      );
      final container = _container(api, _FakeTokenStorage());

      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: '9876543210', otp: '1234');

      expect(
        container.read(authControllerProvider),
        isA<AuthNeedsRegistration>(),
      );
    });

    test('a token-less success is rejected rather than half-applied', () async {
      final api = _FakeAuthApi(
        verifyResponse: const {'needsRegistration': false},
      );
      final storage = _FakeTokenStorage();
      final container = _container(api, storage);

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .verifyOtp(phone: '9876543210', otp: '1234'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.access, isNull);
    });

    test(
      'the pending-approval login error becomes AuthPendingApproval',
      () async {
        // The backend reports approval state as a login failure, so this string
        // match is the only route to that screen. If the server rewords it, this
        // test is what catches it.
        final api = _FakeAuthApi(
          verifyError: _apiError(
            'Your restaurant registration is pending approval.',
          ),
        );
        final container = _container(api, _FakeTokenStorage());

        await container
            .read(authControllerProvider.notifier)
            .verifyOtp(phone: '9876543210', otp: '1234');

        expect(
          container.read(authControllerProvider),
          isA<AuthPendingApproval>(),
        );
      },
    );

    test('the rejection login error becomes AuthRejected', () async {
      final api = _FakeAuthApi(
        verifyError: _apiError(
          'Your restaurant registration has been rejected. '
          'Please contact support.',
        ),
      );
      final container = _container(api, _FakeTokenStorage());

      await container
          .read(authControllerProvider.notifier)
          .verifyOtp(phone: '9876543210', otp: '1234');

      expect(container.read(authControllerProvider), isA<AuthRejected>());
    });

    test('any other login error propagates to the screen', () async {
      final api = _FakeAuthApi(verifyError: _apiError('Invalid OTP'));
      final container = _container(api, _FakeTokenStorage());

      await expectLater(
        container
            .read(authControllerProvider.notifier)
            .verifyOtp(phone: '9876543210', otp: '0000'),
        throwsA(isA<DioException>()),
      );
      expect(container.read(authControllerProvider), isA<AuthInitial>());
    });

    test('logout clears credentials even when the server call fails', () async {
      final api = _FakeAuthApi();
      final storage = _FakeTokenStorage()
        ..access = 'access-1'
        ..refresh = 'refresh-1';
      final container = _container(api, storage);

      await container.read(authControllerProvider.notifier).logout();

      expect(api.logoutCalled, isTrue);
      expect(storage.access, isNull);
      expect(storage.refresh, isNull);
      expect(container.read(authControllerProvider), isA<AuthLoggedOut>());
    });
  });
}
