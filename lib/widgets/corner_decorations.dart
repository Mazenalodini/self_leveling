import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Corner border decorations for auth/splash screens.
class CornerDecorations extends StatelessWidget {
  final Color color;
  final double size;

  const CornerDecorations({
    super.key,
    this.color = AppColors.primaryBlue,
    this.size = 96,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top-left
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color.withOpacity(0.2), width: 2),
                left: BorderSide(color: color.withOpacity(0.2), width: 2),
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
              ),
            ),
          ),
        ),
        // Bottom-right
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color.withOpacity(0.2), width: 2),
                right: BorderSide(color: color.withOpacity(0.2), width: 2),
              ),
              borderRadius: const BorderRadius.only(
                bottomRight: Radius.circular(24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
