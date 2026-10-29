import 'package:flutter/material.dart';
import 'package:quick_commerce_seller/config/theme/app_colors.dart';
import 'package:quick_commerce_seller/core/audio/app_sounds.dart';

/// All pull-to-refresh goes through here so the colour and behaviour stay
/// identical across screens. Never use a bare `RefreshIndicator`.
class AppRefreshIndicator extends StatelessWidget {
  const AppRefreshIndicator({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // Fires only when the seller actually completes a pull — RefreshIndicator
      // does not call onRefresh for an ordinary page load, nor for a drag that
      // is released short of the threshold. That is why the sound lives here
      // and not in the controllers, which also run on first build.
      onRefresh: () {
        AppSounds.playRefresh();
        return onRefresh();
      },
      color: AppColors.primary,
      backgroundColor: Theme.of(context).cardTheme.color,
      child: child,
    );
  }
}
