import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/domain/contracts/runtime_contract.dart';

void main() {
  test('runtime snapshot parses canonical native payload', () {
    final snapshot = RuntimeStateSnapshot.fromMap({
      'contractVersion': kRuntimeContractVersion,
      'trackingActive': true,
      'stage': InterventionStage.s4.code,
      'currentAppPackage': 'com.example.app',
      'overlayVisible': false,
      'riskScore': 0.82,
      'focusModeActive': true,
      'lockState': {
        'blockedAppPackage': null,
        'remainingLockSeconds': 0,
        'reentryCount': 3,
        'isLimitedAccess': true,
        'limitedAccessRemainingSeconds': 120,
        'limitedAccessAppPackage': 'com.example.app',
      },
      'lastUpdatedAt': 123456,
    });

    expect(snapshot.contractVersion, kRuntimeContractVersion);
    expect(snapshot.trackingActive, isTrue);
    expect(snapshot.stage, InterventionStage.s4);
    expect(snapshot.currentAppPackage, 'com.example.app');
    expect(snapshot.overlayVisible, isFalse);
    expect(snapshot.riskScore, 0.82);
    expect(snapshot.focusModeActive, isTrue);
    expect(snapshot.lockState.hasLimitedAccessWindow, isTrue);
    expect(snapshot.lockState.reentryCount, 3);
    expect(snapshot.lastUpdatedAt, 123456);
  });

  test('runtime readiness snapshot parses typed readiness payload', () {
    final readiness = RuntimeReadinessSnapshot.fromMap({
      'contractVersion': kRuntimeContractVersion,
      'usageStatsGranted': true,
      'overlayGranted': true,
      'accessibilityGranted': false,
      'notificationGranted': false,
      'activationRequested': true,
      'engineRunning': true,
    });

    expect(readiness.usageStatsGranted, isTrue);
    expect(readiness.overlayGranted, isTrue);
    expect(readiness.accessibilityGranted, isFalse);
    expect(readiness.notificationGranted, isFalse);
    expect(readiness.activationRequested, isTrue);
    expect(readiness.engineRunning, isTrue);
    expect(readiness.allRequiredGranted, isFalse);
    expect(readiness.liveDetectionAvailable, isFalse);
  });

  test('intervention event round-trips through map contract', () {
    final event = InterventionEvent(
      stage: InterventionStage.s3,
      packageName: 'com.example.app',
      reason: 'Escalated after repeated distraction',
      riskScore: 0.71,
      reentryCount: 2,
      timestamp: 789,
    );

    final roundTrip = InterventionEvent.fromMap(event.toMap());

    expect(roundTrip.contractVersion, kRuntimeContractVersion);
    expect(roundTrip.stage, InterventionStage.s3);
    expect(roundTrip.packageName, 'com.example.app');
    expect(roundTrip.reason, 'Escalated after repeated distraction');
    expect(roundTrip.riskScore, 0.71);
    expect(roundTrip.reentryCount, 2);
    expect(roundTrip.timestamp, 789);
  });
}
