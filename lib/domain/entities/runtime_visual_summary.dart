import '../contracts/runtime_contract.dart';

enum RuntimeVisualStatus {
  inactive,
  monitoring,
  focusMode,
  warning,
  blocking,
  limitedAccess,
  hardLock,
}

class RuntimeVisualSummary {
  final RuntimeVisualStatus status;
  final InterventionStage stage;
  final bool trackingActive;
  final bool focusModeActive;
  final String? targetAppPackage;
  final int remainingSeconds;

  const RuntimeVisualSummary({
    required this.status,
    required this.stage,
    required this.trackingActive,
    required this.focusModeActive,
    required this.targetAppPackage,
    required this.remainingSeconds,
  });

  factory RuntimeVisualSummary.fromSnapshot(RuntimeStateSnapshot snapshot) {
    if (!snapshot.trackingActive) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.inactive,
        stage: snapshot.stage,
        trackingActive: false,
        focusModeActive: snapshot.focusModeActive,
        targetAppPackage: snapshot.blockedApp ?? snapshot.currentApp,
        remainingSeconds: snapshot.lockRemainingSeconds,
      );
    }

    if (snapshot.stage == InterventionStage.s5) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.hardLock,
        stage: snapshot.stage,
        trackingActive: true,
        focusModeActive: snapshot.focusModeActive,
        targetAppPackage: snapshot.blockedApp,
        remainingSeconds: snapshot.lockRemainingSeconds,
      );
    }

    if (snapshot.isInLimitedAccess) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.limitedAccess,
        stage: snapshot.stage,
        trackingActive: true,
        focusModeActive: snapshot.focusModeActive,
        targetAppPackage: snapshot.limitedAccessApp ?? snapshot.currentApp,
        remainingSeconds: snapshot.limitedAccessRemainingSec,
      );
    }

    if (snapshot.stage == InterventionStage.s3 ||
        snapshot.lockRemainingSeconds > 0) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.blocking,
        stage: snapshot.stage,
        trackingActive: true,
        focusModeActive: snapshot.focusModeActive,
        targetAppPackage: snapshot.blockedApp ?? snapshot.currentApp,
        remainingSeconds: snapshot.lockRemainingSeconds,
      );
    }

    if (snapshot.stage.isWarningStage) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.warning,
        stage: snapshot.stage,
        trackingActive: true,
        focusModeActive: snapshot.focusModeActive,
        targetAppPackage: snapshot.currentApp,
        remainingSeconds: 0,
      );
    }

    if (snapshot.focusModeActive) {
      return RuntimeVisualSummary(
        status: RuntimeVisualStatus.focusMode,
        stage: snapshot.stage,
        trackingActive: true,
        focusModeActive: true,
        targetAppPackage: snapshot.currentApp,
        remainingSeconds: 0,
      );
    }

    return RuntimeVisualSummary(
      status: RuntimeVisualStatus.monitoring,
      stage: snapshot.stage,
      trackingActive: true,
      focusModeActive: snapshot.focusModeActive,
      targetAppPackage: snapshot.currentApp,
      remainingSeconds: 0,
    );
  }
}
