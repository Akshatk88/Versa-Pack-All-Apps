import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device currently has a network route.
///
/// This is connectivity, not reachability — a connected device behind a captive
/// portal still reads as online. Request failures remain the authority on
/// whether the backend is actually usable; this only drives the global overlay.
class NetworkController extends Notifier<bool> {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  bool build() {
    final connectivity = Connectivity();

    _subscription = connectivity.onConnectivityChanged.listen((results) {
      state = _isOnline(results);
    });
    unawaited(
      connectivity.checkConnectivity().then((results) {
        state = _isOnline(results);
      }),
    );

    ref.onDispose(() {
      _subscription?.cancel();
    });

    // Assume online until told otherwise, so a slow first check never flashes
    // the offline overlay over a working app.
    return true;
  }

  static bool _isOnline(List<ConnectivityResult> results) =>
      results.isNotEmpty && !results.every((r) => r == ConnectivityResult.none);
}

final networkControllerProvider = NotifierProvider<NetworkController, bool>(
  NetworkController.new,
);
