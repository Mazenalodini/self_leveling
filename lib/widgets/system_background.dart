import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Animated dark background with floating particles, gradient overlay, and glowing orbs.
/// Used as the base layer for every screen.
class SystemBackground extends StatefulWidget {
  final Widget child;
  final int particleCount;
  final bool showOrbs;

  const SystemBackground({
    super.key,
    required this.child,
    this.particleCount = 12,
    this.showOrbs = true,
  });

  @override
  State<SystemBackground> createState() => _SystemBackgroundState();
}

class _SystemBackgroundState extends State<SystemBackground>
    with TickerProviderStateMixin {
  late List<_Particle> _particles;
  late List<AnimationController> _controllers;
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _particles = List.generate(widget.particleCount, (_) => _Particle(_random));
    _controllers = List.generate(widget.particleCount, (i) {
      final controller = AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 3000 + _random.nextInt(2000),
        ),
      );
      Future.delayed(Duration(milliseconds: _random.nextInt(2000)), () {
        if (mounted) controller.repeat();
      });
      return controller;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: AppColors.backgroundGradient,
          ),
        ),

        // Glowing orbs
        if (widget.showOrbs) ...[
          Positioned(
            top: 80,
            right: 40,
            child: IgnorePointer(
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      blurRadius: 120,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 160,
            left: 40,
            child: IgnorePointer(
              child: Container(
                width: 256,
                height: 256,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryCyan.withOpacity(0.1),
                      blurRadius: 120,
                      spreadRadius: 40,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],

        // Animated particles — isolated with RepaintBoundary + IgnorePointer
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: _ParticlesLayer(
                particles: _particles,
                controllers: _controllers,
                screenSize: screenSize,
              ),
            ),
          ),
        ),

        // Main content
        widget.child,
      ],
    );
  }
}

/// Separate widget for particles so they don't cause parent rebuilds.
class _ParticlesLayer extends StatelessWidget {
  final List<_Particle> particles;
  final List<AnimationController> controllers;
  final Size screenSize;

  const _ParticlesLayer({
    required this.particles,
    required this.controllers,
    required this.screenSize,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(particles.length, (i) {
        return AnimatedBuilder(
          animation: controllers[i],
          builder: (_, __) {
            final value = controllers[i].value;
            final opacity = (sin(value * pi) * 0.6).clamp(0.0, 1.0);
            final scale = (sin(value * pi) * 1.5).clamp(0.1, 2.0);
            return Positioned(
              left: particles[i].x * screenSize.width,
              top: particles[i].y * screenSize.height,
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 4 * scale,
                  height: 4 * scale,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryBlue.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class _Particle {
  final double x;
  final double y;

  _Particle(Random r)
      : x = r.nextDouble(),
        y = r.nextDouble();
}
