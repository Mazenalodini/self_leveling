import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_spacing.dart';

/// Floating bottom navigation bar with glow effects on the active tab.
class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  /// Labels for each tab — passed in from the screen that uses localization.
  final List<String> labels;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.labels = const ['Home', 'Habits', 'AI', 'Stats', 'Settings'],
  });

  static const _icons = [
    Icons.home_rounded,
    Icons.track_changes_rounded,
    Icons.psychology_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.bottomNavMargin),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(AppSpacing.radiusXL),
            border: Border.all(
              color: AppColors.primaryBlue.withOpacity(0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryBlue.withOpacity(0.2),
                blurRadius: 40,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_icons.length, (index) {
              final isActive = currentIndex == index;
              return GestureDetector(
                onTap: () => onTap(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isActive)
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withOpacity(0.6),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                          ),
                        Icon(
                          _icons[index],
                          size: 24,
                          color: isActive
                              ? AppColors.primaryBlue
                              : AppColors.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      labels[index],
                      style: AppTextStyles.caption.copyWith(
                        color: isActive
                            ? AppColors.primaryBlue
                            : AppColors.textSecondary,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
