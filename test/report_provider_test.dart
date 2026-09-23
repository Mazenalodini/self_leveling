import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/behavior_record.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';
import 'package:self_leveling/domain/entities/report_models.dart';
import 'package:self_leveling/domain/entities/runtime_visual_summary.dart';
import 'package:self_leveling/domain/entities/user_profile.dart';
import 'package:self_leveling/providers/report_provider.dart';
import 'package:self_leveling/providers/system_provider.dart';
import 'package:self_leveling/services/behavior_service.dart';
import 'package:self_leveling/services/stats_service.dart';
import 'package:self_leveling/services/xp_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dashboard and stats providers consume canonical report service',
      () async {
    final fakeStatsService = FakeStatsService();
    final container = ProviderContainer(
      overrides: [
        statsServiceProvider.overrideWithValue(fakeStatsService),
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: FakeXpService(),
            behaviorService: FakeBehaviorService(),
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dashboard = await container.read(dashboardReportProvider.future);
    final stats = await container.read(statsOverviewProvider.future);
    final level = await container.read(levelOverviewProvider.future);

    expect(dashboard.todayHabitCompletions, 4);
    expect(stats.completionRate, 80);
    expect(level.focusXpToday, 20);
  });

  test('runtime visual provider reflects the native runtime snapshot', () {
    final container = ProviderContainer(
      overrides: [
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: FakeXpService(),
            behaviorService: FakeBehaviorService(),
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          )..state = SystemState(
              profile: UserProfile.create(displayName: 'User'),
              nativeState: const RuntimeStateSnapshot(
                trackingActive: true,
                stage: InterventionStage.s3,
                overlayVisible: true,
                lockState: LockStatePayload(
                  blockedAppPackage: 'com.example.app',
                  remainingLockSeconds: 90,
                ),
              ),
            ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final summary = container.read(runtimeVisualSummaryProvider);
    expect(summary.status, RuntimeVisualStatus.blocking);
    expect(summary.targetAppPackage, 'com.example.app');
    expect(summary.remainingSeconds, 90);
  });

  test('report providers refresh when report invalidation is triggered',
      () async {
    final fakeStatsService = CountingStatsService();
    final fakeBehaviorService = FakeBehaviorService();
    final container = ProviderContainer(
      overrides: [
        statsServiceProvider.overrideWithValue(fakeStatsService),
        behaviorServiceProvider.overrideWithValue(fakeBehaviorService),
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: FakeXpService(),
            behaviorService: fakeBehaviorService,
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(() {
      fakeBehaviorService.dispose();
      container.dispose();
    });

    final first = await container.read(dashboardReportProvider.future);
    expect(first.todayHabitCompletions, 1);

    container.read(reportRefreshVersionProvider.notifier).markDirty();
    final second = await container.read(dashboardReportProvider.future);
    expect(second.todayHabitCompletions, 2);
    expect(fakeStatsService.dashboardReads, 2);
  });

  test('usage-driven refresh invalidates dashboard reports', () async {
    final fakeStatsService = CountingStatsService();
    final fakeBehaviorService = FakeBehaviorService();
    final container = ProviderContainer(
      overrides: [
        statsServiceProvider.overrideWithValue(fakeStatsService),
        behaviorServiceProvider.overrideWithValue(fakeBehaviorService),
        systemProvider.overrideWith(
          (ref) => SystemNotifier(
            xpService: FakeXpService(),
            behaviorService: fakeBehaviorService,
            initialProfile: UserProfile.create(displayName: 'User'),
            subscribeToNativeState: false,
          ),
        ),
      ],
    );
    addTearDown(() {
      fakeBehaviorService.dispose();
      container.dispose();
    });

    await container.read(dashboardReportProvider.future);
    fakeBehaviorService.emitUsageRevision(1);
    await Future<void>.delayed(Duration.zero);

    final refreshed = await container.read(dashboardReportProvider.future);
    expect(refreshed.todayHabitCompletions, 2);
    expect(fakeStatsService.dashboardReads, 2);
  });
}

class FakeStatsService extends StatsService {
  @override
  Future<DashboardReport> getDashboardReport() async => const DashboardReport(
        todayHabitCompletions: 4,
        todayFocusMinutes: 60,
      );

  @override
  Future<StatsOverviewReport> getStatsOverview() async =>
      const StatsOverviewReport(
        todayHabitCompletions: 4,
        totalHabits: 5,
        completionRate: 80,
      );

  @override
  Future<LevelOverviewReport> getLevelOverview() async =>
      const LevelOverviewReport(
        focusXpToday: 20,
        habitXpToday: 12,
        interventionXpToday: -6,
      );
}

class CountingStatsService extends StatsService {
  int dashboardReads = 0;

  @override
  Future<DashboardReport> getDashboardReport() async {
    dashboardReads++;
    return DashboardReport(todayHabitCompletions: dashboardReads);
  }

  @override
  Future<StatsOverviewReport> getStatsOverview() async =>
      const StatsOverviewReport();

  @override
  Future<LevelOverviewReport> getLevelOverview() async =>
      const LevelOverviewReport();
}

class FakeXpService extends XPService {}

class FakeBehaviorService extends BehaviorService {
  final StreamController<int> _controller = StreamController<int>.broadcast();

  @override
  Stream<int> get onUsageDataChanged => _controller.stream;

  void emitUsageRevision(int revision) {
    _controller.add(revision);
  }

  @override
  Future<void> refreshTodayUsage({int days = 1}) async {}

  @override
  Future<BehaviorRecord?> getTodaySummary() async => null;

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
