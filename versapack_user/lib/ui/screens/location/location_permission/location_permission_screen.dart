import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../di/repository_providers.dart';
import '../../../../navigation/route_paths.dart';
import '../../../../platform/location/location_service.dart';
import '../../home/home_provider.dart';
import '../../../common/widgets/buttons/primary_button.dart';
import '../../../common/widgets/buttons/secondary_button.dart';
import '../../../common/widgets/feedback/app_toast.dart';

/// Asks for location so we can quote a real delivery time and fee.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({super.key});

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen> {
  bool _locating = false;

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final location = await ref.read(locationServiceProvider).currentLocation();
      if (!mounted) return;
      await _openAddressAndEnter(extra: location);
    } on LocationPermissionDenied {
      if (mounted) {
        AppToast.error(context, 'We could not access your location');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  /// Opens the address form and, only if it reports a successful backend save
  /// (`pop(true)`), advances the onboarding user to Home.
  ///
  /// This screen owns that decision because the address form is shared with the
  /// address book and checkout, where a save should just pop back — not jump to
  /// Home. Pushing the form left the onboarding user here on a `pop`, which is
  /// why saving an address never reached Home on a fresh install.
  Future<void> _openAddressAndEnter({Object? extra}) async {
    final saved =
        await context.push<bool>(RoutePaths.addressSelection, extra: extra);
    if (saved != true || !mounted) return;

    // Rebuild Home against the address just selected, then replace the whole
    // onboarding stack with it — `go` leaves no location/login screens behind
    // to back into, so there is only ever one Home.
    ref.invalidate(homeProvider);
    context.go(RoutePaths.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const Spacer(),
              const _LocationIllustration(),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'Where should we deliver?',
                textAlign: TextAlign.center,
                style: context.text.displaySmall,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sharing your location lets us show what is in stock near you '
                'and give you an honest delivery time.',
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!
                    .copyWith(color: context.semantic.textSecondary),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Allow location access',
                icon: Icons.my_location_rounded,
                isLoading: _locating,
                onPressed: _useCurrentLocation,
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Enter address manually',
                expand: true,
                onPressed: () => _openAddressAndEnter(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationIllustration extends StatelessWidget {
  const _LocationIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            height: 132,
            width: 132,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: context.colors.primary,
              borderRadius: AppRadii.rXl,
              boxShadow: context.semantic.floatingShadow,
            ),
            child: Icon(
              Icons.location_on_rounded,
              size: 40,
              color: context.colors.surface,
            ),
          ),
        ],
      ),
    );
  }
}
