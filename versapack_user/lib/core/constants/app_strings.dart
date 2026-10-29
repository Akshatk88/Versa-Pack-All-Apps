/// Centralised user-facing copy. Keeps UI files free of string literals.
abstract final class AppStrings {
  static const appName = 'Versapack';
  static const tagline = 'Groceries. Instantly.';

  // Auth
  static const loginTitle = 'Enter your mobile number';
  static const loginSubtitle =
      'We will send you a verification code to get you shopping in seconds.';
  static const otpTitle = 'Verify your number';
  static const resendOtp = 'Resend code';
  static const continueLabel = 'Continue';

  // Generic
  static const retry = 'Retry';
  static const cancel = 'Cancel';
  static const remove = 'Remove';
  static const save = 'Save';
  static const change = 'Change';
  static const seeAll = 'See all';
  static const somethingWentWrong = 'Something went wrong';
  static const offline = 'You are offline. Showing what we have.';

  // Cart / checkout
  static const addToCart = 'Add to cart';
  static const proceedToCheckout = 'Proceed to Checkout';
  static const proceedToPay = 'Proceed to Pay';
  static const billDetails = 'Bill details';
  static const grandTotal = 'To pay';
}
