import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether onboarding has already been shown on this install.
///
/// The stored flag lives in preferences and is read asynchronously, but the
/// router's redirect is synchronous — so the splash screen loads it once and
/// pushes it here. Defaults to `true` so a slow read can never flash onboarding
/// at a returning seller.
class HasSeenOnboardingNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void set(bool value) => state = value;
}

final hasSeenOnboardingProvider =
    NotifierProvider<HasSeenOnboardingNotifier, bool>(
      HasSeenOnboardingNotifier.new,
    );
