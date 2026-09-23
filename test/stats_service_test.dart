import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/behavior_record.dart';
import 'package:self_leveling/domain/entities/runtime_visual_summary.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';
import 'package:self_leveling/services/stats_service.dart';

void main() {
  test('dashboard report derives canonical daily metrics', () {
    final report = StatsService.buildDashboardReport(
      behavior: BehaviorRecord(
        timestamp: testDate,
        productiveSeconds: 3600,
        neutralSeconds: 1200,
        distractingSeconds: 5400,
        sessionCount: 4,
        topDistractingApp: 'Instagram',
      ),
      habitsCompleted: 3,
      focusMinutes: 45,
      escalationCount: 2,
      maxStage: 3,
    );

    expect(report.todayHabitCompletions, 3);
    expect(report.todayFocusMinutes, 45);
    expect(report.todayDistractionHours, 1.5);
    expect(report.todayEscalationCount, 2);
    expect(report.todayMaxStage, 3);
    expect(report.topDistractingApp, 'Instagram');
  });

  test('stats overview calculates completion rate from canonical counts', () {
    final overview = StatsService.buildStatsOverview(
      behavior: BehaviorRecord(
        timestamp: testDate,
        productiveSeconds: 1800,
        neutralSeconds: 1200,
        distractingSeconds: 1800,
        sessionCount: 2,
      ),
      habitsCompleted: 2,
      totalHabits: 4,
      focusMinutes: 30,
      focusSessions: 2,
      escalationCount: 1,
      maxStage: 2,
    );

    expect(overview.completionRate, 50);
    expect(overview.todayFocusMinutes, 30);
    expect(overview.todayFocusSessions, 2);
    expect(overview.todayDistractionHours, 0.5);
    expect(overview.todayEscalationCount, 1);
    expect(overview.todayMaxStage, 2);
  });

  test('productive change percent handles zero previous week', () {
    final change = StatsService.calculateProductiveChangePercent(
      currentWeekHours: 4,
      previousWeekHours: 0,
    );
    expect(change, 100);
  });

  test('runtime visualization maps native snapshot to lock state correctly',
      () {
    final summary = RuntimeVisualSummary.fromSnapshot(
      RuntimeStateSnapshot(
        trackingActive: true,
        stage: InterventionStage.s4,
        focusModeActive: false,
        lockState: const LockStatePayload(
          isLimitedAccess: true,
          limitedAccessRemainingSeconds: 120,
          limitedAccessAppPackage: 'com.example.app',
        ),
      ),
    );

    expect(summary.status, RuntimeVisualStatus.limitedAccess);
    expect(summary.targetAppPackage, 'com.example.app');
    expect(summary.remainingSeconds, 120);
  });
}

final testDate = DateTime(2026, 1, 1);
