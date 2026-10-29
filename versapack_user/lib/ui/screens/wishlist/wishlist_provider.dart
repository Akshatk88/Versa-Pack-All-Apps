import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../di/app_providers.dart';
import '../../../di/repository_providers.dart';
import '../../../domain/model/product.dart';

/// Full wishlist products (the global `wishlistProvider` holds ids only, so
/// cards everywhere can show the right heart without loading products).
final wishlistProductsProvider = FutureProvider<List<Product>>((ref) async {
  if (!ref.watch(authProvider).isSignedIn) return const [];
  // Re-fetch whenever an item is toggled anywhere in the app.
  ref.watch(wishlistProvider);
  return ref.read(wishlistRepositoryProvider).list();
});
