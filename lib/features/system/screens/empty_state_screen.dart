import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/system_decorative_line.dart';

/// Empty state when user has no habits yet.
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                ),
                child: const Icon(Icons.inbox_outlined, color: AppColors.primaryBlue, size: 48),
              ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),

              const SizedBox(height: 32),
              Text(AppStrings.noDataYet, style: AppTextStyles.h2).animate().fadeIn(delay: 300.ms),
              const SizedBox(height: 12),
              Text(AppStrings.startBuildingHabits, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: 48),
              SizedBox(width: 240, child: GlowButton(text: AppStrings.addFirstHabit, icon: Icons.add, onPressed: () {})).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 64),
              SystemDecorativeLine(label: AppStrings.awaitingInput).animate().fadeIn(delay: 800.ms),
            ]),
          ),
        ),
      ),
    );
  }
}
