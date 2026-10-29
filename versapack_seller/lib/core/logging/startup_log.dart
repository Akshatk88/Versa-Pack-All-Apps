import 'package:flutter/foundation.dart';

/// Traces the cold-start sequence.
///
/// Startup is the one flow with no UI to inspect when it goes wrong — a stuck
/// splash looks identical whether storage hung, the network timed out, or the
/// router simply declined to move. These lines say which.
///
/// Debug-only: `kDebugMode` is a compile-time constant, so every call is tree
/// shaken out of a release build along with its string interpolation.
void startupLog(String step, [Object? detail]) {
  if (!kDebugMode) return;
  final elapsed = _stopwatch.elapsedMilliseconds;
  debugPrint(
    '[startup +${elapsed}ms] $step${detail == null ? '' : ' — $detail'}',
  );
}

final Stopwatch _stopwatch = Stopwatch()..start();
