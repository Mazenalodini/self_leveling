import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/input_field.dart';
import '../../../domain/enums/habit_type.dart';
import '../../../providers/habit_provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../providers/app_init_provider.dart';

class AddHabitScreen extends ConsumerStatefulWidget {
  const AddHabitScreen({super.key});

  @override
  ConsumerState<AddHabitScreen> createState() => _AddHabitScreenState();
}

class _AddHabitScreenState extends ConsumerState<AddHabitScreen> {
  final _nameController = TextEditingController();
  String _type = 'build';
  String _frequency = 'daily';
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime ?? const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: Color(0xFF1A2135),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF121A2B),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _reminderTime = picked);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _nameController.text.trim().isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SystemBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardBackground.withOpacity(0.5),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.primaryBlue, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.addHabit, style: AppTextStyles.h2),
                      Row(children: [
                        Container(width: 32, height: 1,
                            color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        const Icon(Icons.add,
                            color: AppColors.primaryBlue, size: 12),
                      ]),
                    ],
                  ),
                ]).animate().fadeIn().slideY(begin: -0.2),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Row(children: [
                        const Icon(Icons.track_changes,
                            color: AppColors.primaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Text(AppStrings.habitNameLabel,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 8),
                      InputField(
                        placeholder: AppStrings.habitNameHint,
                        controller: _nameController,
                      ),

                      const SizedBox(height: 24),

                      // Type
                      Text(AppStrings.habitTypeLabel,
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary)),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _TypeCard(
                            label: AppStrings.buildHabitLabel,
                            subtitle: AppStrings.buildHabitSub,
                            icon: Icons.trending_up,
                            color: AppColors.success,
                            selected: _type == 'build',
                            onTap: () => setState(() => _type = 'build'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TypeCard(
                            label: AppStrings.breakHabitLabel,
                            subtitle: AppStrings.breakHabitSub,
                            icon: Icons.trending_down,
                            color: AppColors.danger,
                            selected: _type == 'break',
                            onTap: () => setState(() => _type = 'break'),
                          ),
                        ),
                      ]).animate().fadeIn(delay: 300.ms),

                      const SizedBox(height: 24),

                      // Frequency
                      Row(children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Text(AppStrings.frequencyLabel,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: _FreqButton(
                            label: AppStrings.freqDaily,
                            selected: _frequency == 'daily',
                            onTap: () =>
                                setState(() => _frequency = 'daily'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _FreqButton(
                            label: AppStrings.freqWeekly,
                            selected: _frequency == 'weekly',
                            onTap: () =>
                                setState(() => _frequency = 'weekly'),
                          ),
                        ),
                      ]).animate().fadeIn(delay: 400.ms),

                      const SizedBox(height: 24),

                      // Reminder Time — with TimePicker
                      Row(children: [
                        const Icon(Icons.schedule,
                            color: AppColors.primaryBlue, size: 16),
                        const SizedBox(width: 8),
                        Text(AppStrings.reminderTimeOpt,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickTime,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _reminderTime != null
                                  ? AppColors.primaryBlue.withOpacity(0.5)
                                  : AppColors.primaryBlue.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: _reminderTime != null
                                    ? AppColors.primaryBlue
                                    : AppColors.textTertiary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _reminderTime != null
                                    ? _formatTime(_reminderTime!)
                                    : AppStrings.tapToSetTime,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: _reminderTime != null
                                      ? Colors.white
                                      : AppColors.textTertiary,
                                ),
                              ),
                              const Spacer(),
                              if (_reminderTime != null)
                                GestureDetector(
                                  onTap: () =>
                                      setState(() => _reminderTime = null),
                                  child: const Icon(Icons.close,
                                      color: AppColors.textTertiary,
                                      size: 18),
                                ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 500.ms),

                      // Save button inside scroll area
                      const SizedBox(height: 24),
                      GlowButton(
                        text: AppStrings.saveHabitBtn,
                        icon: Icons.check_circle,
                        enabled: canSave,
                        onPressed: canSave
                            ? () async {
                                await ref
                                    .read(habitProvider.notifier)
                                    .addHabit(
                                      name: _nameController.text.trim(),
                                      type: _type == 'build'
                                          ? HabitType.build
                                          : HabitType.breakHabit,
                                      frequency: _frequency == 'daily'
                                          ? HabitFrequency.daily
                                          : HabitFrequency.weekly,
                                      reminderTime: _reminderTime != null
                                          ? _formatTime(_reminderTime!)
                                          : null,
                                    );
                                if (_reminderTime != null) {
                                  await ref.read(permissionManagerProvider).requestExactAlarmsPermission();
                                }
                                if (context.mounted) context.pop();
                              }
                            : null,
                      ).animate().fadeIn(delay: 600.ms),

                      // Space for bottom navbar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlowCard(
        glowColor: selected ? color : AppColors.primaryBlue,
        glowOpacity: selected ? 0.3 : 0.1,
        borderRadius: 16,
        borderOpacity: selected ? 0.5 : 0.2,
        backgroundOpacity: selected ? 0.4 : 0.3,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withOpacity(selected ? 0.2 : 0.1),
              ),
              child: Icon(icon,
                  color: selected ? color : AppColors.textSecondary,
                  size: 22),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.textSecondary,
                )),
            const SizedBox(height: 2),
            Text(subtitle,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                )),
          ],
        ),
      ),
    );
  }
}

class _FreqButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FreqButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withOpacity(0.1)
              : AppColors.cardBackground.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primaryBlue
                  .withOpacity(selected ? 0.5 : 0.2)),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: 8)
                ]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: AppTextStyles.bodySmall.copyWith(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              )),
        ),
      ),
    );
  }
}
