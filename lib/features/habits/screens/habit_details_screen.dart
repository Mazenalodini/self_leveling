import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/habit.dart';
import '../../../domain/enums/habit_type.dart';
import '../../../providers/habit_provider.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../providers/app_init_provider.dart';

/// Habit Details — reads real data from HabitProvider.
class HabitDetailsScreen extends ConsumerStatefulWidget {
  final String habitId;
  const HabitDetailsScreen({super.key, required this.habitId});

  @override
  ConsumerState<HabitDetailsScreen> createState() => _HabitDetailsScreenState();
}

class _HabitDetailsScreenState extends ConsumerState<HabitDetailsScreen> {
  List<DateTime> _completionHistory = [];

  Future<void> _completeHabit(Habit habit) async {
    if (!habit.canCompleteNow) return;
    final result = await ref.read(habitProvider.notifier).toggleHabit(habit.id);
    if (!mounted || !result.completedNow) return;
    await _loadHistory();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          backgroundColor: AppColors.cardBackground.withOpacity(0.95),
          content: Text(
            AppStrings.habitCompletedFeedback(
              habitName: habit.name,
              isBreak: habit.isBreak,
              xpEarned: result.xpEarned,
            ),
            style: AppTextStyles.bodySmall.copyWith(color: Colors.white),
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final service = ref.read(habitServiceProvider);
    final history =
        await service.getCompletionHistory(widget.habitId, days: 30);
    if (mounted) setState(() => _completionHistory = history);
  }

  @override
  Widget build(BuildContext context) {
    final habitState = ref.watch(habitProvider);
    final habit =
        habitState.habits.where((h) => h.id == widget.habitId).firstOrNull;

    if (habit == null) {
      return Scaffold(
        body: SystemBackground(
          child: SafeArea(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline,
                    color: AppColors.textTertiary, size: 48),
                const SizedBox(height: 16),
                Text(AppStrings.habitNotFound,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary)),
                const SizedBox(height: 24),
                GlowButton(
                    text: AppStrings.goBack, onPressed: () => context.pop()),
              ]),
            ),
          ),
        ),
      );
    }

    final isPositive = habit.isBuild;
    final color = isPositive ? AppColors.success : AppColors.danger;
    final icon = isPositive ? Icons.trending_up : Icons.trending_down;
    final isLocked = habit.isCompletionLocked;

    return Scaffold(
      body: SystemBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
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
                Expanded(
                    child:
                        Text(AppStrings.habitDetails, style: AppTextStyles.h2)),
              ]).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 24),

              // Habit info card
              GlowCard(
                glowColor: color,
                glowOpacity: 0.12,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(habit.name, style: AppTextStyles.h3),
                              Text(
                                '${isPositive ? AppStrings.buildHabitText : AppStrings.breakHabitText} ${AppStrings.habitWord} • ${habit.frequency.name}',
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.textSecondary),
                              ),
                            ])),
                        // Toggle button
                        GestureDetector(
                          onTap: habit.canCompleteNow
                              ? () {
                                  unawaited(_completeHabit(habit));
                                }
                              : null,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isLocked ? color : Colors.transparent,
                              border: Border.all(
                                color:
                                    isLocked ? color : color.withOpacity(0.4),
                                width: 2,
                              ),
                            ),
                            child: isLocked
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 24)
                                : null,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Stats row — real data
                      Row(children: [
                        _StatItem(
                            label: AppStrings.streakLabel,
                            value: '${habit.currentStreak}d',
                            color: AppColors.warning),
                        const SizedBox(width: 16),
                        _StatItem(
                            label: AppStrings.bestLabel,
                            value: '${habit.longestStreak}d',
                            color: AppColors.primaryBlue),
                        const SizedBox(width: 16),
                        _StatItem(
                            label: AppStrings.totalLabel,
                            value: '${_completionHistory.length}',
                            color: AppColors.primaryCyan),
                        const SizedBox(width: 16),
                        _StatItem(
                            label: AppStrings.xpPerDayLabel,
                            value: '+${habit.xpReward}',
                            color: AppColors.success),
                      ]),
                    ]),
              ).animate().fadeIn(delay: 100.ms),

              const SizedBox(height: 24),

              // Weekly progress — real data
              GlowCard(
                backgroundOpacity: 0.4,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.thisWeekLabel, style: AppTextStyles.h4),
                      const SizedBox(height: 16),
                      Row(children: _buildWeekDays(habit)),
                    ]),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 24),

              // Reminder
              GlowCard(
                backgroundOpacity: 0.3,
                child: Row(children: [
                  const Icon(Icons.access_time,
                      color: AppColors.primaryCyan, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(AppStrings.reminderLabel,
                            style: AppTextStyles.label),
                        Text(
                          habit.reminderTime != null
                              ? habit.reminderTime!
                              : AppStrings.noReminderSet,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.textSecondary),
                        ),
                      ])),
                ]),
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 24),

              // Edit button
              Row(children: [
                Expanded(
                  child: GlowCard(
                    glowColor: AppColors.primaryBlue,
                    glowOpacity: 0.08,
                    backgroundOpacity: 0.3,
                    onTap: () => _showEditDialog(context, habit),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.edit_outlined,
                              color: AppColors.primaryBlue, size: 20),
                          const SizedBox(width: 8),
                          Text(AppStrings.editLabel,
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.primaryBlue)),
                        ]),
                  ).animate().fadeIn(delay: 350.ms),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlowCard(
                    glowColor: AppColors.danger,
                    glowOpacity: 0.08,
                    backgroundOpacity: 0.3,
                    onTap: () => _showDeleteDialog(context, habit),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_outline,
                              color: AppColors.danger, size: 20),
                          const SizedBox(width: 8),
                          Text(AppStrings.deleteLabel,
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.danger)),
                        ]),
                  ).animate().fadeIn(delay: 400.ms),
                ),
              ]),

              const SizedBox(height: 32),
              SystemDecorativeLine(label: AppStrings.habitTrackingLabel),
            ]),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildWeekDays(Habit habit) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final dayLabels = AppStrings.weekDayInitials;

    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final done = _completionHistory.any((d) =>
          d.day == day.day && d.month == day.month && d.year == day.year);
      final isToday = day.day == now.day && day.month == now.month;

      return Expanded(
          child: Column(children: [
        Text(dayLabels[i],
            style: AppTextStyles.caption.copyWith(
              color: isToday ? AppColors.primaryBlue : AppColors.textSecondary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            )),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done
                ? AppColors.success.withOpacity(0.2)
                : AppColors.cardBackground.withOpacity(0.3),
            border: Border.all(
              color: done
                  ? AppColors.success
                  : isToday
                      ? AppColors.primaryBlue.withOpacity(0.5)
                      : AppColors.primaryBlue.withOpacity(0.15),
              width: isToday ? 2 : 1,
            ),
          ),
          child: done
              ? const Icon(Icons.check, color: AppColors.success, size: 16)
              : null,
        ),
      ]));
    });
  }

  void _showEditDialog(BuildContext context, Habit habit) {
    final nameController = TextEditingController(text: habit.name);
    HabitFrequency currentFrequency = habit.frequency;

    TimeOfDay? parsedTime;
    if (habit.reminderTime != null && habit.reminderTime!.contains(':')) {
      final parts = habit.reminderTime!.split(':');
      parsedTime = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts[1]) ?? 0);
    }
    TimeOfDay? currentReminderTime = parsedTime;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (context, setStateBuilder) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          title: Text(AppStrings.editLabel, style: AppTextStyles.h4),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  style: AppTextStyles.bodySmall,
                  decoration: InputDecoration(
                    labelText: AppStrings.habitNameLabel,
                    labelStyle: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                    filled: true,
                    fillColor: AppColors.cardBackground.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.primaryBlue.withOpacity(0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppStrings.frequencyLabel,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setStateBuilder(
                            () => currentFrequency = HabitFrequency.daily),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: currentFrequency == HabitFrequency.daily
                                ? AppColors.primaryBlue.withOpacity(0.2)
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: currentFrequency == HabitFrequency.daily
                                    ? AppColors.primaryBlue
                                    : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text(AppStrings.freqDaily,
                              style: AppTextStyles.caption),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setStateBuilder(
                            () => currentFrequency = HabitFrequency.weekly),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: currentFrequency == HabitFrequency.weekly
                                ? AppColors.primaryBlue.withOpacity(0.2)
                                : AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: currentFrequency == HabitFrequency.weekly
                                    ? AppColors.primaryBlue
                                    : Colors.transparent),
                          ),
                          alignment: Alignment.center,
                          child: Text(AppStrings.freqWeekly,
                              style: AppTextStyles.caption),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(AppStrings.reminderTimeOpt,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: currentReminderTime ??
                          const TimeOfDay(hour: 9, minute: 0),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.dark().copyWith(
                            colorScheme: const ColorScheme.dark(
                              primary: AppColors.primaryBlue,
                              surface: Color(0xFF1A2135),
                            ),
                            dialogBackgroundColor: const Color(0xFF121A2B),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (picked != null) {
                      setStateBuilder(() => currentReminderTime = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.cardBackground.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: currentReminderTime != null
                              ? AppColors.primaryBlue.withOpacity(0.5)
                              : AppColors.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.access_time,
                            color: currentReminderTime != null
                                ? AppColors.primaryBlue
                                : AppColors.textTertiary,
                            size: 20),
                        const SizedBox(width: 12),
                        Text(
                          currentReminderTime != null
                              ? '${currentReminderTime!.hour.toString().padLeft(2, '0')}:${currentReminderTime!.minute.toString().padLeft(2, '0')}'
                              : AppStrings.tapToSetTime,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: currentReminderTime != null
                                ? Colors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                        if (currentReminderTime != null)
                          GestureDetector(
                            onTap: () => setStateBuilder(
                                () => currentReminderTime = null),
                            child: const Icon(Icons.close,
                                color: AppColors.textTertiary, size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.cancel,
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  String? formattedTime;
                  if (currentReminderTime != null) {
                    formattedTime =
                        '${currentReminderTime!.hour.toString().padLeft(2, '0')}:${currentReminderTime!.minute.toString().padLeft(2, '0')}';
                  }
                  await ref.read(habitProvider.notifier).updateHabit(
                        habit.id,
                        name: newName,
                        frequency: currentFrequency,
                        reminderTime: formattedTime,
                      );
                  if (formattedTime != null) {
                    await ref
                        .read(permissionManagerProvider)
                        .requestExactAlarmsPermission();
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(AppStrings.saveLabel,
                  style: TextStyle(color: AppColors.primaryBlue)),
            ),
          ],
        );
      }),
    );
  }

  void _showDeleteDialog(BuildContext context, Habit habit) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text(AppStrings.deleteConfirmTitle(habit.name),
            style: AppTextStyles.h4),
        content:
            Text(AppStrings.deleteConfirmDesc, style: AppTextStyles.bodySmall),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel,
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              ref.read(habitProvider.notifier).deleteHabit(habit.id);
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(AppStrings.deleteLabel,
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatItem(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: Column(children: [
      Text(value, style: AppTextStyles.h4.copyWith(color: color)),
      const SizedBox(height: 4),
      Text(label,
          style:
              AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
    ]));
  }
}
