import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_decorative_line.dart';

class SystemLoadingScreen extends StatefulWidget {
  const SystemLoadingScreen({super.key});

  @override
  State<SystemLoadingScreen> createState() => _SystemLoadingScreenState();
}

class _SystemLoadingScreenState extends State<SystemLoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _rotateReverseController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _rotateReverseController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _rotateReverseController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Orbs
          Positioned(
            top: MediaQuery.of(context).size.height * 0.33, right: 40,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.15), blurRadius: 150, spreadRadius: 50)])),
          ),
          Positioned(
            bottom: MediaQuery.of(context).size.height * 0.33, left: 40,
            child: Container(width: 300, height: 300, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryCyan.withOpacity(0.15), blurRadius: 150, spreadRadius: 50)])),
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brain icon with rotating rings
                SizedBox(
                  width: 128, height: 128,
                  child: Stack(alignment: Alignment.center, children: [
                    // Outer ring
                    AnimatedBuilder(
                      animation: _rotateController,
                      builder: (_, __) => Transform.rotate(
                        angle: _rotateController.value * 2 * pi,
                        child: Stack(children: [
                          Container(width: 128, height: 128, decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 2),
                          )),
                          Positioned(top: 0, left: 60, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.8), blurRadius: 10)]))),
                        ]),
                      ),
                    ),
                    // Inner ring
                    AnimatedBuilder(
                      animation: _rotateReverseController,
                      builder: (_, __) => Transform.rotate(
                        angle: -_rotateReverseController.value * 2 * pi,
                        child: Stack(children: [
                          Container(width: 100, height: 100, decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primaryCyan.withOpacity(0.3), width: 2),
                          )),
                          Positioned(top: 8, left: 44, child: Container(width: 8, height: 8, decoration: BoxDecoration(color: AppColors.primaryCyan, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.primaryCyan.withOpacity(0.8), blurRadius: 10)]))),
                        ]),
                      ),
                    ),
                    // Pulsing glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Container(width: 80, height: 80, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3 + _pulseController.value * 0.3), blurRadius: 30 + _pulseController.value * 20)],
                      )),
                    ),
                    // Brain icon
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (_, __) => Transform.scale(
                        scale: 1.0 + _pulseController.value * 0.1,
                        child: const Icon(Icons.psychology, color: AppColors.primaryBlue, size: 64),
                      ),
                    ),
                  ]),
                ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),

                const SizedBox(height: 40),

                // Title
                Text(AppStrings.analyzing, style: AppTextStyles.h2).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 12),

                // Animated dots
                Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) =>
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle)))
                    .animate(onPlay: (c) => c.repeat())
                    .fadeIn(delay: Duration(milliseconds: i * 200))
                    .then().fadeOut(delay: 300.ms)
                    .then().fadeIn(delay: 300.ms),
                )),

                const SizedBox(height: 32),

                // Message card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 48),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: RichText(textAlign: TextAlign.center, text: TextSpan(style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary), children: [
                    const TextSpan(text: 'Your system is '),
                    TextSpan(text: 'understanding', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                    const TextSpan(text: ' your behavior'),
                  ])),
                ).animate().fadeIn(delay: 500.ms),

                const SizedBox(height: 32),

                // Processing steps
                ...['Processing data|0', 'Analyzing patterns|500', 'Building insights|1000'].map((e) {
                  final parts = e.split('|');
                  final icons = [Icons.memory, Icons.show_chart, Icons.psychology];
                  final idx = ['Processing data', 'Analyzing patterns', 'Building insights'].indexOf(parts[0]);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 6),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                      ),
                      child: Row(children: [
                        Icon(icons[idx], color: AppColors.primaryBlue, size: 20),
                        const SizedBox(width: 12),
                        Text(parts[0], style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        const Spacer(),
                        SizedBox(width: 80, height: 4, child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            backgroundColor: AppColors.background,
                            valueColor: const AlwaysStoppedAnimation(AppColors.primaryBlue),
                          ),
                        )),
                      ]),
                    ).animate().fadeIn(delay: Duration(milliseconds: 800 + int.parse(parts[1]))).slideX(begin: -0.2),
                  );
                }),

                const SizedBox(height: 48),
                SystemDecorativeLine(label: AppStrings.aiProcessing).animate().fadeIn(delay: 1500.ms),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
