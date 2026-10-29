import 'package:quick_commerce_seller/features/auth/domain/seller_model.dart';

/// Every state the backend can put a seller in. Sealed so a `switch` over it is
/// exhaustive and a new state cannot be silently ignored.
sealed class AuthState {
  const AuthState();
}

/// Before the stored session has been resolved. The splash screen owns this.
class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoggedOut extends AuthState {
  const AuthLoggedOut({this.reason});

  /// Set when the backend ended the session — e.g. the account signed in on
  /// another device. Shown once on the login screen.
  final String? reason;
}

class AuthOtpSent extends AuthState {
  const AuthOtpSent({required this.phone, this.debugOtp});

  final String phone;

  /// Echoed by the backend outside production so a developer can sign in
  /// without waiting for an SMS. Null in production.
  final String? debugOtp;
}

/// The phone verified but no store is attached to it yet.
class AuthNeedsRegistration extends AuthState {
  const AuthNeedsRegistration({required this.phone});

  final String phone;
}

class AuthPendingApproval extends AuthState {
  const AuthPendingApproval({required this.message});

  final String message;
}

class AuthRejected extends AuthState {
  const AuthRejected({required this.message});

  final String message;
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({required this.seller});

  final SellerModel seller;
}
