import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/corner_decorations.dart';
import '../../../navigation/app_router.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _ringController;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ringController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        particleCount: 20,
        child: Stack(
          children: [
            const CornerDecorations(),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Title with glow
                      _buildTitle(),
                      const SizedBox(height: 32),

                      // Animated system icon
                      _buildSystemIcon(),
                      const SizedBox(height: 48),

                      // Subtitle
                      Text(
                        AppStrings.appTagline,
                        style: AppTextStyles.bodyLarge.copyWith(
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 800.ms),
                      const SizedBox(height: 64),

                      // CTA Button
                      SizedBox(
                        width: 280,
                        child: GlowButton(
                          text: AppStrings.startJourney,
                          onPressed: () => context.push(RoutePaths.login),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 900.ms, duration: 800.ms)
                          .slideY(begin: 0.2, end: 0),

                      const SizedBox(height: 64),

                      // Decorative dots
                      Opacity(
                        opacity: 0.3,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _dot(4),
                            const SizedBox(width: 8),
                            _dot(8),
                            const SizedBox(width: 8),
                            _dot(4),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 1100.ms, duration: 600.ms),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow layer
        Text(
          AppStrings.appName,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.primaryBlue,
            fontSize: 48,
          ),
        ),
        // Main text with gradient
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, AppColors.textSecondary],
          ).createShader(bounds),
          child: Text(
            AppStrings.appName,
            style: AppTextStyles.h1.copyWith(
              color: Colors.white,
              fontSize: 48,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildSystemIcon() {
    return SizedBox(
      width: 128,
      height: 128,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Rotating dashed ring
          AnimatedBuilder(
            animation: _ringController,
            builder: (context, _) => Transform.rotate(
              angle: _ringController.value * 2 * pi,
              child: Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primaryBlue.withOpacity(0.3),
                    width: 2,
                    // Note: dashed not available in Flutter, using solid with opacity
                  ),
                ),
              ),
            ),
          ),

          // Inner glowing circle
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              final glowValue = 0.3 + _glowController.value * 0.3;
              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(glowValue),
                      blurRadius: 20 + _glowController.value * 20,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 40,
                ),
              );
            },
          ),

          // Orbiting particles
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _ringController,
              builder: (context, _) {
                final angle = (_ringController.value * 2 * pi) +
                    (i * 2 * pi / 3);
                final x = cos(angle) * 56;
                final y = sin(angle) * 56;
                return Transform.translate(
                  offset: Offset(x, y),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.primaryCyan,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryCyan.withOpacity(0.8),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 800.ms)
        .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
  }

  Widget _dot(double size) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppColors.primaryBlue,
          shape: BoxShape.circle,
        ),
      );
}
