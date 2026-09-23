import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/input_field.dart';
import '../../../widgets/toggle_switch.dart';
import '../../../widgets/circular_progress_widget.dart';
import '../../../widgets/progress_bar_widget.dart';
import '../../../widgets/system_decorative_line.dart';

class FeedbackDemoScreen extends StatefulWidget {
  const FeedbackDemoScreen({super.key});

  @override
  State<FeedbackDemoScreen> createState() => _FeedbackDemoScreenState();
}

class _FeedbackDemoScreenState extends State<FeedbackDemoScreen> {
  bool _toggle = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                GestureDetector(onTap: () {}, child: const Icon(Icons.arrow_back, color: AppColors.primaryBlue, size: 24)),
                const SizedBox(width: 16),
                Text('Component Library', style: AppTextStyles.h2),
              ]),
              const SizedBox(height: 32),

              // Buttons
              Text('Buttons', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              GlowButton(text: 'Primary Button', onPressed: () {}),
              const SizedBox(height: 12),
              GlowButton(text: 'Disabled Button', enabled: false, onPressed: null),
              const SizedBox(height: 12),
              GlowButton(text: 'Success', gradient: AppColors.successGradient, onPressed: () {}),

              const SizedBox(height: 32),
              Text('Cards', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              GlowCard(child: Text('Default Glow Card', style: AppTextStyles.bodyMedium)),
              const SizedBox(height: 12),
              GlowCard(glowColor: AppColors.success, child: Text('Success Card', style: AppTextStyles.bodyMedium)),
              const SizedBox(height: 12),
              GlowCard(glowColor: AppColors.danger, child: Text('Danger Card', style: AppTextStyles.bodyMedium)),

              const SizedBox(height: 32),
              Text('Inputs', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              const InputField(label: 'Text Input', placeholder: 'Type something...', prefixIcon: Icons.edit),
              const SizedBox(height: 16),
              Row(children: [
                Text('Toggle Switch', style: AppTextStyles.bodyMedium),
                const Spacer(),
                ToggleSwitch(value: _toggle, onChanged: (v) => setState(() => _toggle = v)),
              ]),

              const SizedBox(height: 32),
              Text('Progress', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              Center(child: CircularProgressWidget(
                progress: 0.75,
                size: 120,
                center: Text('75%', style: AppTextStyles.h3),
              )),
              const SizedBox(height: 24),
              const ProgressBarWidget(progress: 0.65),
              const SizedBox(height: 12),
              ProgressBarWidget(progress: 0.4, gradient: LinearGradient(colors: [AppColors.success, AppColors.primaryBlue])),

              const SizedBox(height: 32),
              Text('Typography', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              Text('H1 Heading', style: AppTextStyles.h1),
              Text('H2 Heading', style: AppTextStyles.h2),
              Text('H3 Heading', style: AppTextStyles.h3),
              Text('Body Large', style: AppTextStyles.bodyLarge),
              Text('Body Medium', style: AppTextStyles.bodyMedium),
              Text('Caption', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),

              const SizedBox(height: 32),
              Text('Colors', style: AppTextStyles.h4),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                _ColorChip('Primary', AppColors.primaryBlue),
                _ColorChip('Cyan', AppColors.primaryCyan),
                _ColorChip('Success', AppColors.success),
                _ColorChip('Danger', AppColors.danger),
                _ColorChip('Warning', AppColors.warning),
                _ColorChip('Card BG', AppColors.cardBackground),
              ]),

              const SizedBox(height: 32),
              const SystemDecorativeLine(label: 'COMPONENT LIBRARY'),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label; final Color color;
  const _ColorChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(width: 48, height: 48, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.1)))),
      const SizedBox(height: 4),
      Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
    ]);
  }
}
