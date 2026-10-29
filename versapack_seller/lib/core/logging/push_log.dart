import 'package:flutter/foundation.dart';

/// Traces the new-order push flow: message received, tapped, order fetched,
/// accepted or rejected.
///
/// The flow spans a background isolate, a cold start, the router and three API
/// calls, and most of it happens before there is any UI to inspect — these
/// lines are the only way to tell which leg failed.
///
/// Debug-only, like [startupLog]: `kDebugMode` is a compile-time constant, so
/// the calls and their string interpolation are tree shaken out of release.
void pushLog(String step, [Object? detail]) {
  if (!kDebugMode) return;
  debugPrint('[push] $step${detail == null ? '' : ' — $detail'}');
}
