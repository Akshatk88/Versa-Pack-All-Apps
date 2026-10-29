import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Thin wrapper so log calls are greppable and stripped in release.
abstract final class AppLogger {
  /// Records a user interaction without exposing secrets or personal data.
  static void action(String name, {String? details, String scope = 'action'}) {
    final suffix = details == null || details.isEmpty ? '' : ' | $details';
    debug('$name$suffix', scope: scope);
  }

  static void debug(String message, {String scope = 'app'}) {
    if (kDebugMode) developer.log(message, name: 'suvio.$scope');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      developer.log(
        message,
        name: 'suvio.error',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
