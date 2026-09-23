import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Custom toggle switch matching the design system.
class ToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ToggleSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 28,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? AppColors.primaryBlue.withOpacity(0.4)
              : AppColors.background,
          border: Border.all(
            color: value
                ? AppColors.primaryBlue
                : AppColors.primaryBlue.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    blurRadius: 8,
                  ),
                ]
              : [],
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              left: value ? 28 : 2,
              top: 1,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: value
                      ? AppColors.primaryBlue
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
