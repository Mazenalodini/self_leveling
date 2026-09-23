import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/services/behavior_service.dart';

void main() {
  test('refreshTodayUsage emits a revision when native usage snapshot changed',
      () async {
    final requestedDays = <int>[];
    final service = BehaviorService(
      usageSnapshotRefresher: (days) async {
        requestedDays.add(days);
        return true;
      },
    );
    addTearDown(service.dispose);

    final revisions = <int>[];
    final sub = service.onUsageDataChanged.listen(revisions.add);
    addTearDown(sub.cancel);

    await service.refreshTodayUsage(days: 7);
    await Future<void>.delayed(Duration.zero);

    expect(requestedDays, [7]);
    expect(revisions, [1]);
  });

  test('refreshTodayUsage stays quiet when native usage snapshot is unchanged',
      () async {
    final service = BehaviorService(
      usageSnapshotRefresher: (_) async => false,
    );
    addTearDown(service.dispose);

    final revisions = <int>[];
    final sub = service.onUsageDataChanged.listen(revisions.add);
    addTearDown(sub.cancel);

    await service.refreshTodayUsage(days: 30);
    await Future<void>.delayed(Duration.zero);

    expect(revisions, isEmpty);
  });

  test(
      'repeated mixed day week month refreshes do not emit duplicates when unchanged',
      () async {
    final requestedDays = <int>[];
    final service = BehaviorService(
      usageSnapshotRefresher: (days) async {
        requestedDays.add(days);
        return requestedDays.length == 1;
      },
    );
    addTearDown(service.dispose);

    final revisions = <int>[];
    final sub = service.onUsageDataChanged.listen(revisions.add);
    addTearDown(sub.cancel);

    await service.refreshTodayUsage(days: 1);
    await service.refreshTodayUsage(days: 7);
    await service.refreshTodayUsage(days: 30);
    await Future<void>.delayed(Duration.zero);

    expect(requestedDays, [1, 7, 30]);
    expect(revisions, [1]);
  });
}
