import '../enums/behavior_category.dart';

enum UsagePeriod { today, week, month }

class DashboardReport {
  final int todayHabitCompletions;
  final int todayFocusMinutes;
  final double todayDistractionHours;
  final int todayEscalationCount;
  final int todayMaxStage;
  final String? topDistractingApp;

  const DashboardReport({
    this.todayHabitCompletions = 0,
    this.todayFocusMinutes = 0,
    this.todayDistractionHours = 0,
    this.todayEscalationCount = 0,
    this.todayMaxStage = 0,
    this.topDistractingApp,
  });
}

class StatsOverviewReport {
  final int todayHabitCompletions;
  final int totalHabits;
  final int completionRate;
  final int todayFocusMinutes;
  final int todayFocusSessions;
  final double todayDistractionHours;
  final int todayEscalationCount;
  final int todayMaxStage;
  final String? topDistractingApp;

  const StatsOverviewReport({
    this.todayHabitCompletions = 0,
    this.totalHabits = 0,
    this.completionRate = 0,
    this.todayFocusMinutes = 0,
    this.todayFocusSessions = 0,
    this.todayDistractionHours = 0,
    this.todayEscalationCount = 0,
    this.todayMaxStage = 0,
    this.topDistractingApp,
  });
}

class WeeklyReviewReport {
  final List<String> days;
  final List<double> focusHours;
  final List<double> distractHours;
  final int totalHabitsCompleted;
  final int totalFocusSessions;
  final int weeklyXpEarned;
  final int weeklyEscalationCount;
  final int weeklyMaxStage;
  final double productiveChangePercent;
  final String? topDistractingApp;

  const WeeklyReviewReport({
    required this.days,
    required this.focusHours,
    required this.distractHours,
    required this.totalHabitsCompleted,
    required this.totalFocusSessions,
    required this.weeklyXpEarned,
    required this.weeklyEscalationCount,
    required this.weeklyMaxStage,
    required this.productiveChangePercent,
    this.topDistractingApp,
  });
}

class UsageAppSummary {
  final String packageName;
  final String appName;
  final BehaviorCategory category;
  final int durationSeconds;
  final int launchCount;
  final int lastTimeUsed;

  const UsageAppSummary({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.durationSeconds,
    this.launchCount = 0,
    this.lastTimeUsed = 0,
  });

  Duration get duration => Duration(seconds: durationSeconds);
}

class UsageReport {
  final UsagePeriod period;
  final int totalDurationSeconds;
  final int totalLaunchCount;
  final List<UsageAppSummary> apps;

  const UsageReport({
    required this.period,
    required this.totalDurationSeconds,
    this.totalLaunchCount = 0,
    required this.apps,
  });

  Duration get totalDuration => Duration(seconds: totalDurationSeconds);
  int get totalMinutes => totalDuration.inMinutes;
  int get totalApps => apps.length;

  String? get topAppName => apps.isEmpty ? null : apps.first.appName;
}

class LevelOverviewReport {
  final int focusXpToday;
  final int habitXpToday;
  final int interventionXpToday;
  final int recentLevelUps;

  const LevelOverviewReport({
    this.focusXpToday = 0,
    this.habitXpToday = 0,
    this.interventionXpToday = 0,
    this.recentLevelUps = 0,
  });
}
