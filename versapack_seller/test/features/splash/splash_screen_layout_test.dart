import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quick_commerce_seller/config/theme/app_theme.dart';
import 'package:quick_commerce_seller/features/splash/presentation/views/splash_screen.dart';

/// The splash lays out its logo, storefront graphic, tagline and spinner in a
/// fixed Column. On a short screen that column overflowed — visible as the
/// yellow/black stripe on a real device. One frame at the smallest supported
/// height is enough to catch a regression.
///
/// Kept out of all_screens_render_test because the splash starts a bootstrap
/// timer and navigates itself away, neither of which belongs in a pure layout
/// smoke test.
void main() {
  for (final size in const [Size(320, 568), Size(412, 915)]) {
    testWidgets('SplashScreen fits ${size.width}x${size.height}', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = errors.add;
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.light,
              home: const SplashScreen(),
            ),
          ),
        );
      } finally {
        FlutterError.onError = previousOnError;
      }

      expect(
        errors.map((e) => e.exception.toString()).toList(),
        isEmpty,
        reason: 'SplashScreen overflowed at $size',
      );

      // Drain the bootstrap timer so teardown finds none pending. Its
      // navigation has no router here and throws; that is this harness's
      // limitation, not a layout defect, so those errors are discarded.
      final ignored = <FlutterErrorDetails>[];
      FlutterError.onError = ignored.add;
      // The bootstrap chains timers, so drain in several steps.
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 5));
      }
      FlutterError.onError = previousOnError;
    });
  }
}
