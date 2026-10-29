import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quick_commerce_seller/app.dart';
import 'package:quick_commerce_seller/config/constants/app_constants.dart';
import 'package:quick_commerce_seller/core/logging/startup_log.dart';

void main() {
  // Everything runs inside the guarded zone so an error raised off the widget
  // tree — a stray async callback, a platform channel — cannot take the app
  // down without being seen.
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    startupLog('main: binding initialized');
    startupLog('main: baseUrl', AppConstants.baseUrl);

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _report(details.exception, details.stack);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _report(error, stack);
      return true;
    };

    startupLog('main: runApp');
    runApp(const ProviderScope(child: SellerApp()));
  }, (error, stack) => _report(error, stack));
}

/// Single funnel for uncaught errors. Crash reporting attaches here once it is
/// approved and configured; until then a debug log is the honest behaviour —
/// swallowing them silently would hide real defects.
void _report(Object error, StackTrace? stack) {
  if (kDebugMode) {
    startupLog('UNCAUGHT ERROR', error);
    debugPrint('Uncaught error: $error');
    if (stack != null) debugPrint('$stack');
  }
}
