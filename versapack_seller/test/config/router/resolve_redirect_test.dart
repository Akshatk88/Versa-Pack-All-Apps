import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/router/app_router.dart';
import 'package:quick_commerce_seller/features/auth/domain/seller_model.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_state.dart';

const SellerModel _seller = SellerModel(
  id: 'store-1',
  name: 'Ravi',
  storeName: 'Fresh Mart',
  phone: '9876543210',
  email: '',
  status: 'approved',
  imageUrl: '',
  isAcceptingOrders: true,
  rating: 0,
  totalRatings: 0,
  createdAt: '',
);

String? redirect(
  AuthState auth,
  String location, {
  bool hasSeenOnboarding = true,
  bool splashCompleted = true,
}) => resolveRedirect(
  auth: auth,
  location: location,
  hasSeenOnboarding: hasSeenOnboarding,
  splashCompleted: splashCompleted,
);

void main() {
  group('the splash is never a resting place', () {
    // This is the regression the app actually hit: the splash route was listed
    // as a public route, so a resolved-but-logged-out seller sitting on it was
    // told "you are somewhere valid, stay put" — forever.
    test('a logged-out seller on the splash is always moved off it', () {
      expect(
        redirect(const AuthLoggedOut(), splashRoute),
        isNotNull,
        reason: 'returning null here strands the app on the splash',
      );
      expect(redirect(const AuthLoggedOut(), splashRoute), '/login');
    });

    test('every resolved auth state leaves the splash', () {
      final resolvedStates = <AuthState>[
        const AuthLoggedOut(),
        const AuthOtpSent(phone: '9876543210'),
        const AuthNeedsRegistration(phone: '9876543210'),
        const AuthPendingApproval(message: 'pending'),
        const AuthRejected(message: 'rejected'),
        const AuthAuthenticated(seller: _seller),
      ];

      for (final auth in resolvedStates) {
        expect(
          redirect(auth, splashRoute),
          isNotNull,
          reason: '${auth.runtimeType} would hang on the splash',
        );
      }
    });

    test('a first-run seller leaves the splash for login', () {
      expect(
        redirect(const AuthLoggedOut(), splashRoute, hasSeenOnboarding: false),
        '/login',
      );
    });

    test('only AuthInitial may stay on the splash', () {
      expect(redirect(const AuthInitial(), splashRoute), isNull);
    });

    test('AuthInitial pins every other location back to the splash', () {
      expect(redirect(const AuthInitial(), '/home'), splashRoute);
      expect(redirect(const AuthInitial(), '/login'), splashRoute);
    });
  });

  group('authenticated routing', () {
    test('lands on home from the splash and from public routes', () {
      const auth = AuthAuthenticated(seller: _seller);
      expect(redirect(auth, splashRoute), '/home');
      expect(redirect(auth, '/login'), '/home');
      expect(redirect(auth, '/onboarding'), '/home');
      expect(redirect(auth, '/account-status'), '/home');
    });

    test('stays put on an authenticated route', () {
      const auth = AuthAuthenticated(seller: _seller);
      expect(redirect(auth, '/home'), isNull);
      expect(redirect(auth, '/orders'), isNull);
      expect(redirect(auth, '/order-details'), isNull);
    });
  });

  group('blocked sellers', () {
    test('pending and rejected are pinned to the status screen', () {
      const pending = AuthPendingApproval(message: 'pending');
      const rejected = AuthRejected(message: 'rejected');

      expect(redirect(pending, '/home'), '/account-status');
      expect(redirect(rejected, '/home'), '/account-status');
      expect(redirect(pending, '/account-status'), isNull);
      expect(redirect(rejected, '/account-status'), isNull);
    });
  });

  group('logged-out routing', () {
    test('an authenticated-only route bounces to login', () {
      expect(redirect(const AuthLoggedOut(), '/home'), '/login');
      expect(redirect(const AuthLoggedOut(), '/payouts'), '/login');
    });

    test('public routes are reachable', () {
      expect(redirect(const AuthLoggedOut(), '/login'), isNull);
      expect(
        redirect(const AuthNeedsRegistration(phone: '1'), '/registration'),
        isNull,
      );
    });

    test('onboarding is skipped once seen', () {
      expect(redirect(const AuthLoggedOut(), '/onboarding'), '/login');
    });

    test('mid-OTP is not dragged back to onboarding', () {
      // The OTP step is only reachable after onboarding, but a stale flag must
      // not yank the seller out of a flow they are halfway through.
      expect(
        redirect(
          const AuthOtpSent(phone: '9876543210'),
          '/login',
          hasSeenOnboarding: false,
        ),
        isNull,
      );
    });
  });

  group('no redirect cycles', () {
    // A redirect whose destination itself redirects is a loop; go_router throws
    // after a few hops. Every destination must be a fixed point.
    test('each destination is stable for its own state', () {
      final cases = <AuthState, bool>{
        const AuthLoggedOut(): true,
        const AuthAuthenticated(seller: _seller): true,
        const AuthPendingApproval(message: 'p'): true,
      };

      for (final entry in cases.entries) {
        final auth = entry.key;
        final first = redirect(auth, splashRoute);
        expect(first, isNotNull);
        expect(
          redirect(auth, first!),
          isNull,
          reason: '$auth loops: $splashRoute -> $first -> ...',
        );
      }
    });

    test('first-run onboarding is a fixed point', () {
      final first = redirect(
        const AuthLoggedOut(),
        splashRoute,
        hasSeenOnboarding: false,
      );
      expect(first, '/onboarding');
      expect(
        redirect(const AuthLoggedOut(), first!, hasSeenOnboarding: false),
        isNull,
      );
    });
  });

  group('an unregistered phone reaches the form', () {
    // The reported bug: verify-otp returned needsRegistration, but the redirect
    // saw '/login' in the public set and answered "stay put", so the seller
    // never left the sign-in screen.
    test('AuthNeedsRegistration on /login goes to /registration', () {
      expect(
        redirect(const AuthNeedsRegistration(phone: '9876543210'), '/login'),
        '/registration',
      );
    });

    test('it rests on /registration and /registration-success', () {
      const auth = AuthNeedsRegistration(phone: '9876543210');
      expect(redirect(auth, '/registration'), isNull);
      expect(redirect(auth, '/registration-success'), isNull);
    });

    test('it cannot wander into the app', () {
      const auth = AuthNeedsRegistration(phone: '9876543210');
      expect(redirect(auth, '/home'), '/registration');
      expect(redirect(auth, '/orders'), '/registration');
      expect(redirect(auth, splashRoute), '/registration');
    });

    test('the destination is a fixed point, so there is no loop', () {
      const auth = AuthNeedsRegistration(phone: '9876543210');
      final first = redirect(auth, '/login');
      expect(redirect(auth, first!), isNull);
    });
  });
}
