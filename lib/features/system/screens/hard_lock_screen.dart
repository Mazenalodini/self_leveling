import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/utils/formatters.dart';

import '../../../widgets/system_decorative_line.dart';

class HardLockScreen extends StatefulWidget {
  const HardLockScreen({super.key});

  @override
  State<HardLockScreen> createState() => _HardLockScreenState();
}

class _HardLockScreenState extends State<HardLockScreen>
    with SingleTickerProviderStateMixin {
  int _timeRemaining = 3600; // 1 hour
  late AnimationController _warningPulse;

  @override
  void initState() {
    super.initState();
    _warningPulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
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
  void dispose() { _warningPulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(color: AppColors.background),
          // Red glow overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.center,
                colors: [AppColors.danger.withOpacity(0.05), Colors.transparent],
              ),
            ),
          ),
          // Red orb
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25, right: 40,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.1), blurRadius: 150, spreadRadius: 50)])),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.25, left: 40,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.15), blurRadius: 150, spreadRadius: 50)])),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Alert icon
                  Container(
                    width: 112, height: 112,
                    decoration: BoxDecoration(
                      gradient: AppColors.dangerGradient,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.danger.withOpacity(0.5), width: 2),
                      boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.4), blurRadius: 40)],
                    ),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 56),
                  ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0, 0), curve: Curves.easeOut),

                  const SizedBox(height: 16),

                  // Warning badge
                  AnimatedBuilder(
                    animation: _warningPulse,
                    builder: (_, __) => Opacity(
                      opacity: 0.3 + _warningPulse.value * 0.7,
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                        const SizedBox(width: 8),
                        Text(AppStrings.systemAlert.toUpperCase(), style: AppTextStyles.captionSmall.copyWith(color: AppColors.warning, fontWeight: FontWeight.w700, letterSpacing: 3)),
                        const SizedBox(width: 8),
                        const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Text(AppStrings.accessRestricted, style: AppTextStyles.h1.copyWith(fontSize: 40)).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: 12),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 64, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, AppColors.danger]))),
                    const SizedBox(width: 12),
                    Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Container(width: 64, height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.danger, Colors.transparent]))),
                  ]).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 32),

                  // Message
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                      boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.15), blurRadius: 40)],
                    ),
                    child: RichText(textAlign: TextAlign.center, text: TextSpan(style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), children: [
                      TextSpan(text: AppStrings.appLockedToProtect),
                      TextSpan(text: AppStrings.locked, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger, fontWeight: FontWeight.w600)),
                      TextSpan(text: AppStrings.toProtectFocus),
                    ])),
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 24),

                  // Timer
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
                      boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.2), blurRadius: 40)],
                    ),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.schedule, color: AppColors.primaryBlue, size: 24),
                        const SizedBox(width: 12),
                        Text(AppStrings.lockedFor.toUpperCase(), style: AppTextStyles.captionSmall.copyWith(color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 16),
                      ShaderMask(
                        shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                        child: Text(Formatters.formatHourMinSec(_timeRemaining), style: AppTextStyles.timer.copyWith(color: Colors.white)),
                      ),
                    ]),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 24),

                  // Penalty
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.danger.withOpacity(0.4)),
                      boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.15), blurRadius: 40)],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.trending_down, color: AppColors.danger, size: 20),
                      const SizedBox(width: 12),
                      Text(AppStrings.selfControlPenalty(5), style: AppTextStyles.bodyLarge.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700)),
                    ]),
                  ).animate().fadeIn(delay: 900.ms),

                  const SizedBox(height: 32),

                  RichText(text: TextSpan(style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary), children: [
                    TextSpan(text: AppStrings.enforcedForGrowth),
                    TextSpan(text: AppStrings.forYourGrowth, style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
                  ])).animate().fadeIn(delay: 1100.ms),

                  const SizedBox(height: 48),
                  SystemDecorativeLine(label: AppStrings.enforcedRestriction, color: AppColors.danger).animate().fadeIn(delay: 1300.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
