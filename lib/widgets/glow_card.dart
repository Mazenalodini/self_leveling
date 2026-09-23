import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';

/// Glassmorphic card with configurable glow color and border.
class GlowCard extends StatelessWidget {
  final Widget child;
  final Color glowColor;
  final double glowOpacity;
  final double glowBlur;
  final double borderOpacity;
  final double backgroundOpacity;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double borderWidth;
  final VoidCallback? onTap;

  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = AppColors.primaryBlue,
    this.glowOpacity = 0.15,
    this.glowBlur = 40,
    this.borderOpacity = 0.3,
    this.backgroundOpacity = 0.5,
    this.borderRadius = AppSpacing.radiusXL,
    this.padding = const EdgeInsets.all(AppSpacing.cardPadding),
    this.borderWidth = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(backgroundOpacity),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: glowColor.withOpacity(borderOpacity),
            width: borderWidth,
          ),
          boxShadow: [
            BoxShadow(
              color: glowColor.withOpacity(glowOpacity),
              blurRadius: glowBlur,
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}
