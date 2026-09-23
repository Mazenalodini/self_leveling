import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/report_models.dart';
import '../domain/entities/runtime_visual_summary.dart';
import '../services/stats_service.dart';
import 'system_provider.dart';

class ReportRefreshNotifier extends StateNotifier<int> {
  ReportRefreshNotifier() : super(0);

  void markDirty() => state++;
}

final statsServiceProvider = Provider<StatsService>((ref) {
  return StatsService();
});

final reportRefreshVersionProvider =
    StateNotifierProvider<ReportRefreshNotifier, int>((ref) {
  return ReportRefreshNotifier();
});

final behaviorUsageRefreshProvider = StreamProvider<int>((ref) {
  final behaviorService = ref.watch(behaviorServiceProvider);
  return behaviorService.onUsageDataChanged;
});

final runtimeHistoryRefreshSignalProvider = Provider<int>((ref) {
  final snapshot = ref.watch(nativeStateProvider);
  return Object.hash(
    snapshot.trackingActive,
    snapshot.escalationStage,
    snapshot.lockState.reentryCount,
    snapshot.lockState.hasBlockingLock,
    snapshot.lockState.hasLimitedAccessWindow,
  );
});

final dashboardReportProvider = FutureProvider<DashboardReport>((ref) {
  ref.watch(reportRefreshVersionProvider);
  ref.watch(
      behaviorUsageRefreshProvider.select((value) => value.asData?.value));
  ref.watch(runtimeHistoryRefreshSignalProvider);
  return ref.read(statsServiceProvider).getDashboardReport();
});

final statsOverviewProvider = FutureProvider<StatsOverviewReport>((ref) {
  ref.watch(reportRefreshVersionProvider);
  ref.watch(
      behaviorUsageRefreshProvider.select((value) => value.asData?.value));
  ref.watch(runtimeHistoryRefreshSignalProvider);
  return ref.read(statsServiceProvider).getStatsOverview();
});

final weeklyReviewProvider = FutureProvider<WeeklyReviewReport>((ref) {
  ref.watch(reportRefreshVersionProvider);
  ref.watch(
      behaviorUsageRefreshProvider.select((value) => value.asData?.value));
  ref.watch(runtimeHistoryRefreshSignalProvider);
  return ref.read(statsServiceProvider).getWeeklyReview();
});

final usageReportProvider =
    FutureProvider.family<UsageReport, UsagePeriod>((ref, period) {
  ref.watch(reportRefreshVersionProvider);
  ref.watch(
      behaviorUsageRefreshProvider.select((value) => value.asData?.value));
  return ref.read(statsServiceProvider).getUsageReport(period);
});

final levelOverviewProvider = FutureProvider<LevelOverviewReport>((ref) {
  ref.watch(reportRefreshVersionProvider);
  return ref.read(statsServiceProvider).getLevelOverview();
});

final runtimeVisualSummaryProvider = Provider<RuntimeVisualSummary>((ref) {
  final snapshot = ref.watch(nativeStateProvider);
  return RuntimeVisualSummary.fromSnapshot(snapshot);
});
