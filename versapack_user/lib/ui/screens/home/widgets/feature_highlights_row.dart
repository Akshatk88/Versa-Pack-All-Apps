import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// The 3-column trust feature banner sitting under the search bar in the top yellow header.
/// The 3-column trust feature banner sitting under the search bar in the top yellow header.
class FeatureHighlightsRow extends StatelessWidget {
  const FeatureHighlightsRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. 10 mins Fast Delivery
          Expanded(
            child: _FeatureItem(
              iconWidget: Icon(
                Icons.two_wheeler_rounded,
                size: 20,
                color: context.colors.primary,
              ),
              title: '10 mins',
              subtitle: 'Fast Delivery',
            ),
          ),
          _divider(context),
          // 2. 100% Secure Payment
          Expanded(
            child: _FeatureItem(
              iconWidget: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: context.colors.onPrimary,
                ),
              ),
              title: '100%',
              subtitle: 'Secure Payment',
            ),
          ),
          _divider(context),
          // 3. Best Prices On All Products
          Expanded(
            child: _FeatureItem(
              iconWidget: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: context.colors.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '%',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: context.colors.onPrimary,
                  ),
                ),
              ),
              title: 'Best Prices',
              subtitle: 'On All Products',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      height: 24,
      width: 1,
      color: context.semantic.surfaceAlt,
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.iconWidget,
    required this.title,
    required this.subtitle,
  });

  final Widget iconWidget;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          iconWidget,
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                  color: context.colors.onSurface,
                  height: 1.1,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall!.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 9,
                  color: context.semantic.textSecondary,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
