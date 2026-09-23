import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/system_decorative_line.dart';

class OverlayLockScreen extends StatefulWidget {
  const OverlayLockScreen({super.key});

  @override
  State<OverlayLockScreen> createState() => _OverlayLockScreenState();
}

class _OverlayLockScreenState extends State<OverlayLockScreen>
    with SingleTickerProviderStateMixin {
  int _timeRemaining = 900; // 15 minutes
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() { if (_timeRemaining > 0) _timeRemaining--; });
      return _timeRemaining > 0;
    });
  }

  @override
  void dispose() { _pulseController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        particleCount: 20,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shield icon
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (_, __) {
                    return Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3 + _pulseController.value * 0.2), blurRadius: 40 + _pulseController.value * 20),
                          BoxShadow(color: AppColors.primaryCyan.withOpacity(0.2 + _pulseController.value * 0.1), blurRadius: 60),
                        ],
                      ),
                      child: const Icon(Icons.shield, color: Colors.white, size: 48),
                    );
                  },
                ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0, 0), curve: Curves.easeOut),

                const SizedBox(height: 32),
                Text(AppStrings.focusModeActivated, style: AppTextStyles.h2.copyWith(fontSize: 32)).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(width: 48, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.primaryBlue]))),
                  const SizedBox(width: 8),
                  const Icon(Icons.auto_awesome, color: AppColors.primaryBlue, size: 16),
                  const SizedBox(width: 8),
                  Container(width: 48, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryBlue, Colors.transparent]))),
                ]).animate().fadeIn(delay: 400.ms),

                const SizedBox(height: 32),

                // Message
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                  ),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textSecondary), children: [
                      TextSpan(text: AppStrings.usingAppTooLong),
                      TextSpan(text: AppStrings.tooLong, style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 32),

                // Timer
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.4)),
                    boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.2), blurRadius: 40)],
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.schedule, color: AppColors.primaryBlue, size: 24),
                      const SizedBox(width: 12),
                      Text(AppStrings.timeRemaining.toUpperCase(), style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary)),
                    ]),
                    const SizedBox(height: 16),
                    ShaderMask(
                      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                      child: Text(Formatters.formatMinSec(_timeRemaining), style: AppTextStyles.timer.copyWith(color: Colors.white)),
                    ),
                  ]),
                ).animate().fadeIn(delay: 700.ms).scale(begin: const Offset(0.9, 0.9)),

                const SizedBox(height: 32),

                RichText(
                  text: TextSpan(style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), children: [
                    TextSpan(text: AppStrings.takeTimeTo),
                    TextSpan(text: AppStrings.resetAndRefocus, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                    TextSpan(text: AppStrings.andWord),
                    TextSpan(text: AppStrings.refocus, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryCyan, fontWeight: FontWeight.w600)),
                  ]),
                ).animate().fadeIn(delay: 900.ms),

                const SizedBox(height: 48),
                SystemDecorativeLine(label: AppStrings.systemIntervention).animate().fadeIn(delay: 1100.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
