import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Decorative system line used at the bottom of screens.
/// Pattern: ── ● LABEL ● ──
class SystemDecorativeLine extends StatelessWidget {
  final String label;
  final Color color;

  const SystemDecorativeLine({
    super.key,
    required this.label,
    this.color = AppColors.primaryBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.2,
      child: Row(
        children: [
          // Left line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, color],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Label
          Flexible(
            flex: 0,
            child: Text(
              label,
              style: AppTextStyles.captionSmall.copyWith(
                color: color,
                letterSpacing: 2,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Right line
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
