/// Every backend path the app calls, relative to `API_BASE_URL` (which already
/// ends in `/api/v1`). Verified against the backend's route files.
abstract final class ApiPaths {
  // Auth — core/auth/auth.routes.js
  static const requestOtp = '/food/auth/user/request-otp';
  static const verifyOtp = '/food/auth/user/verify-otp';
  static const refreshToken = '/food/auth/refresh-token';
  static const logout = '/food/auth/logout';
  static const me = '/food/auth/me';

  // User — modules/food/user/routes/user.routes.js
  static const profile = '/food/user/profile';
  static const wallet = '/food/user/wallet';
  static const walletTopupOrder = '/food/user/wallet/topup/order';
  static const walletTopupVerify = '/food/user/wallet/topup/verify';
  static const addresses = '/food/user/addresses';
  static String address(String id) => '/food/user/addresses/$id';
  static String addressDefault(String id) => '/food/user/addresses/$id/default';
  static const favorites = '/food/user/favorites';
  static String favoriteFood(String id) => '/food/user/favorites/foods/$id';
  static const cartSync = '/food/user/cart';
  static const supportTicket = '/food/user/support/ticket';

  // Catalog — modules/food/search + modules/food/restaurant
  static const searchProducts = '/food/search/products';
  static const adminCategories = '/food/search/categories/admin';
  static String sellerMenu(String id) => '/food/restaurant/restaurants/$id/menu';
  static String sellerAddons(String id) => '/food/restaurant/restaurants/$id/addons';
  static const offers = '/food/restaurant/offers';

  // Landing — modules/food/landing
  static const heroBanners = '/food/hero-banners/public';
  static const topBanners = '/food/top-banners/public';
  static const promotionBanners = '/food/hero-banners/home-promotion/public';

  // CMS pages — modules/food/landing (`/pages/:key`), keys: terms, privacy,
  // refund, shipping, cancellation, support, about.
  static String page(String key) => '/food/pages/$key';

  // Public settings — modules/food/admin
  static const feeSettings = '/food/admin/fee-settings/public';

  // Orders — modules/food/orders/routes/order.routes.user.js
  static const orders = '/food/orders';
  static const calculateOrder = '/food/orders/calculate';
  static const verifyPayment = '/food/orders/verify-payment';
  static String order(String id) => '/food/orders/$id';
  static String orderRoute(String id) => '/food/orders/$id/route';
  static String orderDropOtp(String id) => '/food/orders/$id/drop-otp';
  static String orderCancel(String id) => '/food/orders/$id/cancel';
  static String orderRatings(String id) => '/food/orders/$id/ratings';
  static String orderInstructions(String id) => '/food/orders/$id/instructions';
  static String orderPendingPayment(String id) => '/food/orders/$id/pending-payment';

  // Push tokens — core/notifications/fcm.routes.js. Mounted at `/v1/fcm-tokens`,
  // outside the `/food` namespace the rest of the app lives in.
  static const fcmTokenSave = '/fcm-tokens/mobile/save';
  static const fcmTokenRemove = '/fcm-tokens/remove';

  // Chat — modules/food/chat/routes/chat.routes.js. Customer↔rider threads are
  // keyed on the order id (conversationId == orderId).
  static const chatMessages = '/food/chat/messages';
  static String chatRead(String conversationId) =>
      '/food/chat/conversations/$conversationId/read';

  // Notifications — core/notifications/notification.routes.js
  static const notificationInbox = '/food/notifications/inbox';
  static String notificationRead(String id) => '/food/notifications/$id/read';
  static String notificationDismiss(String id) => '/food/notifications/$id';
  static const notificationReadAll = '/food/notifications/inbox/read-all';
  static const notificationDismissAll = '/food/notifications/inbox/all';
  static const termsAndServices = '/food/pages/terms';

}
