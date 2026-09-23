import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Horizontal progress bar with gradient fill, glow, and optional shimmer.
class ProgressBarWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final Gradient? gradient;
  final Color? glowColor;
  final bool showBorder;
  final Color borderColor;

  const ProgressBarWidget({
    super.key,
    required this.progress,
    this.height = 16,
    this.gradient,
    this.glowColor,
    this.showBorder = true,
    this.borderColor = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? AppColors.primaryGradient;
    final effectiveGlow = glowColor ?? AppColors.primaryBlue;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(height / 2),
        border: showBorder
            ? Border.all(
                color: borderColor.withOpacity(0.2),
              )
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            // Progress fill
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: effectiveGradient,
                  borderRadius: BorderRadius.circular(height / 2),
                  boxShadow: [
                    BoxShadow(
                      color: effectiveGlow.withOpacity(0.5),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
            ),
            // Glow underneath
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: effectiveGlow.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
