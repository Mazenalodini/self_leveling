import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';

/// Primary CTA button with gradient background and glow effect.
class GlowButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final IconData? icon;
  final double borderRadius;
  final Gradient? gradient;
  final double glowOpacity;

  const GlowButton({
    super.key,
    required this.text,
    this.onPressed,
    this.enabled = true,
    this.icon,
    this.borderRadius = AppSpacing.radiusXL,
    this.gradient,
    this.glowOpacity = 0.5,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = widget.gradient ?? AppColors.primaryGradient;
    final isActive = widget.enabled && widget.onPressed != null;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        if (isActive) widget.onPressed!();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: AnimatedOpacity(
          opacity: isActive ? 1.0 : 0.5,
          duration: const Duration(milliseconds: 200),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Glow layer
              if (isActive)
                Positioned(
                  left: -4,
                  right: -4,
                  top: -4,
                  bottom: -4,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(
                            (_pressed ? widget.glowOpacity * 1.5 : widget.glowOpacity).clamp(0.0, 1.0),
                          ),
                          blurRadius: 40,
                        ),
                      ],
                    ),
                  ),
                ),
              // Button body
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  gradient: isActive ? effectiveGradient : null,
                  color: isActive ? null : AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: isActive
                      ? null
                      : Border.all(
                          color: AppColors.primaryBlue.withOpacity(0.2),
                          width: 2,
                        ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          widget.text,
                          style: AppTextStyles.buttonLarge.copyWith(
                            color: isActive ? Colors.white : AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
