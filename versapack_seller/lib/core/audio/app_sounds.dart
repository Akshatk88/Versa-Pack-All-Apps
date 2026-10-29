import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:quick_commerce_seller/core/logging/push_log.dart';

/// The app's two sounds.
///
/// They are played by different machinery on purpose. The pull-to-refresh
/// chirp is a one-shot that only matters while the seller is looking at the
/// screen, so an in-app player is right. The new-order alert has to keep
/// sounding when the app is backgrounded or killed, where no Dart runs at all,
/// so it is owned end to end by a native foreground service and this class only
/// starts and stops it.
class AppSounds {
  const AppSounds._();

  /// Mirrors `MainActivity.ALARM_CHANNEL`.
  static const MethodChannel _alarmChannel = MethodChannel(
    'com.quick.seller/new_order_alarm',
  );

  /// Named as it exists on disk. The file is a misspelt `.mp4` container, not
  /// the `refresh.mp3` it is usually called; ExoPlayer reads it by content, so
  /// it plays. Renaming the file is the only change needed here if it is ever
  /// replaced with a real mp3.
  static const String _refreshAsset = 'sound/refersh.mp4';

  static AudioPlayer? _refreshPlayer;

  /// Orders whose alert has already been started. Keyed by order id so the
  /// duplicate leg of the same push — or a redelivery — cannot restart a loop
  /// that is already running, while a genuinely different order still can.
  static final Set<String> _alerted = <String>{};

  /// Loops [_newOrderAsset] until [stopNewOrderAlert]. Safe to call repeatedly
  /// for the same [orderId] — only the first call starts anything.
  static Future<void> startNewOrderAlert(String orderId) async {
    if (!_alerted.add(orderId)) {
      pushLog('alert already sounding', orderId);
      return;
    }
    pushLog('alert start', orderId);
    try {
      // Handed to the native foreground service rather than played here.
      // An in-app player stops existing the moment the app is backgrounded,
      // which is exactly when a seller needs the alert most — and running both
      // would put two copies of the same loop on top of each other.
      await _alarmChannel.invokeMethod<bool>('startAlarm', {
        'orderId': orderId,
      });
    } on MissingPluginException {
      // The channel is registered on MainActivity, so it is absent from the
      // background isolate. Nothing to do: the native FCM service has already
      // started the alarm in that case.
      pushLog('alert start skipped', 'no channel in this isolate');
    } catch (error) {
      pushLog('alert failed', error);
      _alerted.remove(orderId);
    }
  }

  /// The seller has answered [orderId]. Silences the loop only once every
  /// order it was sounding for has been answered — accepting one of two
  /// waiting orders must not silence the one still unanswered.
  static Future<void> resolveOrder(String orderId) async {
    _alerted.remove(orderId);
    pushLog('alert resolved', '$orderId, ${_alerted.length} still waiting');
    if (_alerted.isEmpty) await stopNewOrderAlert();
  }

  /// Silences the loop and forgets the orders it was sounding for, so a later
  /// order rings again.
  static Future<void> stopNewOrderAlert() async {
    final wasAlerting = _alerted.isNotEmpty;
    _alerted.clear();
    if (!wasAlerting) return;

    pushLog('alert stop');
    try {
      // Idempotent on the native side — it returns early when nothing is
      // ringing, so an extra stop costs nothing.
      await _alarmChannel.invokeMethod<bool>('stopAlarm');
    } on MissingPluginException {
      pushLog('alert stop skipped', 'no channel in this isolate');
    } catch (error) {
      pushLog('alert stop failed', error);
    }
  }

  /// One-shot, for a pull-to-refresh the seller actually performed.
  ///
  /// Reuses a single player and restarts it rather than layering a second
  /// copy, so a fast double pull sounds once per pull instead of doubling.
  static Future<void> playRefresh() async {
    try {
      final player = _refreshPlayer ??= AudioPlayer();
      await player.stop();
      await player.play(AssetSource(_refreshAsset));
    } catch (error) {
      // A refresh that cannot make a noise is still a refresh. Never let this
      // surface as a failed reload.
      pushLog('refresh sound failed', error);
    }
  }

  /// Frees both players. Called when the app is detached.
  static Future<void> dispose() async {
    await stopNewOrderAlert();
    final refresh = _refreshPlayer;
    _refreshPlayer = null;
    await refresh?.dispose();
  }
}
