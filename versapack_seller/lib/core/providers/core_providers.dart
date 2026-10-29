import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:quick_commerce_seller/core/storage/token_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  // Android encryption is now the plugin's default; iOS needs the
  // accessibility level set explicitly so a backgrounded app can still read
  // the token after first unlock.
  (ref) => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  ),
);

final tokenStorageProvider = Provider<TokenStorage>(
  (ref) => TokenStorage(ref.watch(secureStorageProvider)),
);
