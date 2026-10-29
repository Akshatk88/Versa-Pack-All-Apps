import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashCompletedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markCompleted() {
    state = true;
  }
}

final splashCompletedProvider = NotifierProvider<SplashCompletedNotifier, bool>(
  SplashCompletedNotifier.new,
);
