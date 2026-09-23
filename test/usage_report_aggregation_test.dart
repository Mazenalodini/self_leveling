import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/entities/report_models.dart';
import 'package:self_leveling/domain/enums/behavior_category.dart';
import 'package:self_leveling/services/stats_service.dart';

void main() {
  test('usage date-key ranges are correct for day week and month', () {
    final now = DateTime(2026, 4, 20, 15, 30);

    expect(
      StatsService.usageDateKeyRangeFor(UsagePeriod.today, now: now),
      (startDateKey: '2026-04-20', endDateKey: '2026-04-20'),
    );
    expect(
      StatsService.usageDateKeyRangeFor(UsagePeriod.week, now: now),
      (startDateKey: '2026-04-14', endDateKey: '2026-04-20'),
    );
    expect(
      StatsService.usageDateKeyRangeFor(UsagePeriod.month, now: now),
      (startDateKey: '2026-03-22', endDateKey: '2026-04-20'),
    );
  });

  test('usage report aggregates exact seconds and applies category overrides',
      () {
    final report = StatsService.buildUsageReport(
      period: UsagePeriod.week,
      rows: const [
        {
          'package_name': 'com.social.app',
          'app_name': 'Social',
          'category': 2,
          'total_duration_seconds': 3599,
          'total_launch_count': 4,
          'max_last_time_used': 1713628800,
        },
        {
          'package_name': 'com.focus.app',
          'app_name': 'Focus',
          'category': 1,
          'total_duration_seconds': 61,
          'total_launch_count': 2,
          'max_last_time_used': 1713629800,
        },
      ],
      categoryOverrides: {
        'com.focus.app': BehaviorCategory.productive.index,
      },
    );

    expect(report.totalDurationSeconds, 3660);
    expect(report.totalMinutes, 61);
    expect(report.totalApps, 2);
    expect(report.totalLaunchCount, 6);
    expect(report.topAppName, 'Social');
    expect(report.apps.first.packageName, 'com.social.app');
    expect(report.apps.last.category, BehaviorCategory.productive);
  });

  test(
      'usage report keeps launch-only rows and sorts by duration then launches',
      () {
    final report = StatsService.buildUsageReport(
      period: UsagePeriod.month,
      rows: const [
        {
          'package_name': 'com.zero.app',
          'app_name': 'Zero',
          'category': 1,
          'total_duration_seconds': 0,
          'total_launch_count': 3,
          'max_last_time_used': 1713620000,
        },
        {
          'package_name': 'com.alpha.app',
          'app_name': 'Alpha',
          'category': 1,
          'total_duration_seconds': 120,
          'total_launch_count': 1,
          'max_last_time_used': 1713630000,
        },
        {
          'package_name': 'com.beta.app',
          'app_name': 'Beta',
          'category': 1,
          'total_duration_seconds': 180,
          'total_launch_count': 2,
          'max_last_time_used': 1713640000,
        },
      ],
    );

    expect(report.totalApps, 3);
    expect(report.apps.map((app) => app.packageName), [
      'com.beta.app',
      'com.alpha.app',
      'com.zero.app',
    ]);
    expect(report.apps.last.launchCount, 3);
  });

  test('usage report enforces week and month sanity bounds', () {
    final weekReport = StatsService.buildUsageReport(
      period: UsagePeriod.week,
      rows: const [
        {
          'package_name': 'com.a',
          'app_name': 'A',
          'category': 1,
          'total_duration_seconds': 500000,
          'total_launch_count': 10,
          'max_last_time_used': 10,
        },
        {
          'package_name': 'com.b',
          'app_name': 'B',
          'category': 1,
          'total_duration_seconds': 500000,
          'total_launch_count': 12,
          'max_last_time_used': 20,
        },
      ],
    );
    final monthReport = StatsService.buildUsageReport(
      period: UsagePeriod.month,
      rows: const [
        {
          'package_name': 'com.a',
          'app_name': 'A',
          'category': 1,
          'total_duration_seconds': 2000000,
          'total_launch_count': 20,
          'max_last_time_used': 10,
        },
        {
          'package_name': 'com.b',
          'app_name': 'B',
          'category': 1,
          'total_duration_seconds': 2000000,
          'total_launch_count': 30,
          'max_last_time_used': 20,
        },
      ],
    );

    expect(
        weekReport.totalDurationSeconds, lessThanOrEqualTo(7 * 24 * 60 * 60));
    expect(
        monthReport.totalDurationSeconds, lessThanOrEqualTo(30 * 24 * 60 * 60));
    expect(weekReport.totalLaunchCount, 22);
    expect(monthReport.totalLaunchCount, 50);
  });

  test('usage max duration invariants match visible periods', () {
    expect(StatsService.usageMaxDurationFor(UsagePeriod.today), 24 * 60 * 60);
    expect(
        StatsService.usageMaxDurationFor(UsagePeriod.week), 7 * 24 * 60 * 60);
    expect(
        StatsService.usageMaxDurationFor(UsagePeriod.month), 30 * 24 * 60 * 60);
  });
}
