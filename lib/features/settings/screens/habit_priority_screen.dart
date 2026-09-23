import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../providers/habit_provider.dart';
import '../../../domain/entities/habit.dart';


/// Habit Priority Screen — ترتيب أولوية العادات
class HabitPriorityScreen extends ConsumerStatefulWidget {
  const HabitPriorityScreen({super.key});

  @override
  ConsumerState<HabitPriorityScreen> createState() => _HabitPriorityScreenState();
}

class _HabitPriorityScreenState extends ConsumerState<HabitPriorityScreen> {
  List<Habit> _localHabits = [];

  @override
  void initState() {
    super.initState();
    // Initialize with current state
    Future.microtask(() {
      setState(() {
        _localHabits = List.from(ref.read(habitProvider).habits);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep local habits in sync if count changes
    ref.listen(habitProvider, (previous, next) {
      if (previous?.habits.length != next.habits.length) {
        setState(() {
          _localHabits = List.from(next.habits);
        });
      }
    });

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
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
                      Text(AppStrings.habitPriority, style: AppTextStyles.h2),
                      Row(children: [
                        Container(width: 32, height: 1,
                            color: AppColors.primaryBlue),
                        const SizedBox(width: 8),
                        const Icon(Icons.sort,
                            color: AppColors.primaryBlue, size: 12),
                      ]),
                    ],
                  ),
                ]).animate().fadeIn().slideY(begin: -0.2),
              ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                AppStrings.dragToReorder,
                style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary),
              ),
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 16),

            // Reorderable list
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    child: child,
                  );
                },
                itemCount: _localHabits.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _localHabits.removeAt(oldIndex);
                    _localHabits.insert(newIndex, item);
                  });
                  // Persist sorting
                  ref.read(habitProvider.notifier).updateHabitsOrder(
                        _localHabits.map((h) => h.id).toList(),
                      );
                },
                itemBuilder: (context, index) {
                  final habit = _localHabits[index];
                  final isBuild = habit.isBuild;
                  final color = isBuild ? AppColors.primaryBlue : AppColors.danger;
                  final icon = isBuild ? Icons.trending_up : Icons.block;

                  return Container(
                    key: ValueKey(habit.id),
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: color.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        // Priority number
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: color.withOpacity(0.15),
                            border: Border.all(color: color.withOpacity(0.4)),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: AppTextStyles.caption.copyWith(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            habit.name,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Icon(Icons.drag_handle,
                            color: AppColors.textTertiary, size: 20),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
