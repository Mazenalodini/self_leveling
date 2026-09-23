import 'dart:math';
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Custom circular progress indicator with gradient stroke and glow.
class CircularProgressWidget extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Widget? center;

  const CircularProgressWidget({
    super.key,
    required this.progress,
    this.size = 192,
    this.strokeWidth = 12,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background track
          CustomPaint(
            size: Size(size, size),
            painter: _CircleTrackPainter(
              strokeWidth: strokeWidth,
              color: AppColors.cardBackground.withOpacity(0.5),
            ),
          ),
          // Progress arc
          CustomPaint(
            size: Size(size, size),
            painter: _CircleProgressPainter(
              progress: progress,
              strokeWidth: strokeWidth,
              colors: const [AppColors.primaryBlue, AppColors.primaryCyan],
            ),
          ),
          // Glow layer
          CustomPaint(
            size: Size(size, size),
            painter: _CircleProgressPainter(
              progress: progress,
              strokeWidth: strokeWidth + 8,
              colors: [
                AppColors.primaryBlue.withOpacity(0.3),
                AppColors.primaryCyan.withOpacity(0.3),
              ],
              isGlow: true,
            ),
          ),
          // Center content
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _CircleTrackPainter extends CustomPainter {
  final double strokeWidth;
  final Color color;

  _CircleTrackPainter({required this.strokeWidth, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircleProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final List<Color> colors;
  final bool isGlow;

  _CircleProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.colors,
    this.isGlow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final gradient = SweepGradient(
      startAngle: -pi / 2,
      endAngle: 3 * pi / 2,
      colors: colors,
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (isGlow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    }

    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircleProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
