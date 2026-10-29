import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/core/logging/startup_log.dart';
import 'package:quick_commerce_seller/core/providers/onboarding_provider.dart';
import 'package:quick_commerce_seller/features/auth/presentation/controllers/auth_controller.dart';
import 'package:quick_commerce_seller/core/providers/splash_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  static const Duration _watchdogTimeout = Duration(seconds: 15);
  Timer? _watchdog;

  @override
  void initState() {
    super.initState();
    debugPrint('[SPLASH] Splash screen opened');
    startupLog('splash.initState');

    _watchdog = Timer(_watchdogTimeout, () {
      if (!mounted) return;
      startupLog('splash.WATCHDOG FIRED — startup never completed');
      ref.read(authControllerProvider.notifier).forceLoggedOut();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    debugPrint('[SPLASH] Initialization started');
    startupLog('splash.bootstrap start');
    final startTime = DateTime.now();

    try {
      if (!mounted) return;
      ref.read(hasSeenOnboardingProvider.notifier).set(true);

      await ref.read(authControllerProvider.notifier).resolveSession();
      debugPrint('[SPLASH] Initialization completed');
    } catch (e, stack) {
      startupLog('splash.bootstrap FAILED', e);
      if (kDebugMode) debugPrint('$stack');
      if (!mounted) return;
      ref.read(authControllerProvider.notifier).forceLoggedOut();
      debugPrint('[SPLASH] Initialization completed (fallback logged out)');
    } finally {
      // Enforce minimum splash screen display time of 2 seconds (2000ms)
      const minDisplayDuration = Duration(milliseconds: 2000);
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed < minDisplayDuration) {
        await Future.delayed(minDisplayDuration - elapsed);
      }
      debugPrint(
        '[SPLASH] Minimum delay completed (${DateTime.now().difference(startTime).inMilliseconds}ms)',
      );

      _watchdog?.cancel();
      startupLog(
        'splash.bootstrap end',
        ref.read(authControllerProvider).runtimeType,
      );

      debugPrint('[SPLASH] Navigation started');
      if (mounted) {
        ref.read(splashCompletedProvider.notifier).markCompleted();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _buildLogoHeader(),
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Image.asset(
      'assets/images/logo.png',
      width: 220,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(
            Icons.shopping_bag_rounded,
            size: 80,
            color: Color(0xFFFD9027),
          ),
          SizedBox(height: 12),
          Text(
            'VersaPack',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Seller',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }
}
