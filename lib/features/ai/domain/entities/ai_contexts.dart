import '../../../../domain/entities/user_profile.dart';
import '../../../../domain/entities/habit.dart';
import '../../../../domain/enums/escalation_level.dart';
import '../../../../domain/enums/behavior_category.dart';
import '../../../../domain/enums/habit_type.dart';
import '../../../../domain/entities/app_settings.dart';
import '../../../../domain/contracts/runtime_contract.dart';

/// Snapshot context consumed by the Message Generator logic
class MessageContext {
  final String currentLanguage; // 'en' or 'ar'
  final UserProfile profile;
  final EscalationLevel currentStage;
  final double distractionScore;
  final BehaviorCategory currentAppCategory;
  final int ignoredWarningCount;
  final bool focusModeActive;
  final String? contextTaskName;
  final HabitType? contextHabitType;
  final String? currentAppPackage;
  final String? currentAppName;
  final int recentInterventionCount24h;
  final int todayFocusMinutes;
  final String strictnessPreference;
  final int currentXP;
  final int selfControlScore;

  const MessageContext({
    required this.currentLanguage,
    required this.profile,
    required this.currentStage,
    this.distractionScore = 0.0,
    this.currentAppCategory = BehaviorCategory.neutral,
    this.ignoredWarningCount = 0,
    this.focusModeActive = false,
    this.contextTaskName,
    this.contextHabitType,
    this.currentAppPackage,
    this.currentAppName,
    this.recentInterventionCount24h = 0,
    this.todayFocusMinutes = 0,
    this.strictnessPreference = '',
    this.currentXP = 0,
    this.selfControlScore = 50,
  });
}

/// Snapshot context consumed by the pure Recommendation Engine
class RecommendationContext {
  final String currentLanguage; // 'en' or 'ar'
  final UserProfile profile;
  final DateTime timeOfDay;
  final List<Habit> pendingHabits;
  final EscalationLevel currentStage;
  final AppSettings? settings;
  final String? currentAppPackage;
  final String? currentAppName;
  final AppCategory appCategory;
  final int recentInterventionCount24h;
  final int todayFocusMinutes;

  const RecommendationContext({
    required this.currentLanguage,
    required this.profile,
    required this.timeOfDay,
    required this.pendingHabits,
    required this.currentStage,
    this.settings,
    this.currentAppPackage,
    this.currentAppName,
    this.appCategory = AppCategory.neutral,
    this.recentInterventionCount24h = 0,
    this.todayFocusMinutes = 0,
  });
}
