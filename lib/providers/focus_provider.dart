import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/focus_session.dart';
import '../platform/platform_channel.dart';
import '../services/focus_service.dart';
import 'report_provider.dart';
import 'system_provider.dart';

enum FocusSessionPhase {
  idle,
  running,
  interrupted,
  completed,
}

/// Focus mode state.
class FocusState {
  final FocusSession? activeSession;
  final FocusSession? lastFinishedSession;
  final List<FocusSession> history;
  final int remainingSeconds;
  final FocusSessionPhase phase;

  const FocusState({
    this.activeSession,
    this.lastFinishedSession,
    this.history = const [],
    this.remainingSeconds = 0,
    this.phase = FocusSessionPhase.idle,
  });

  bool get isActive =>
      phase == FocusSessionPhase.running &&
      activeSession != null &&
      activeSession!.isActive;

  bool get hasCompletedSession =>
      phase == FocusSessionPhase.completed &&
      lastFinishedSession?.wasCompleted == true;

  bool get hasInterruptedSession =>
      phase == FocusSessionPhase.interrupted &&
      lastFinishedSession?.isInterrupted == true;

  FocusSession? get latestCompletedSession {
    FocusSession? latest;
    for (final session in history) {
      if (!session.wasCompleted) continue;
      if (latest == null || session.startedAt.isAfter(latest.startedAt)) {
        latest = session;
      }
    }
    return latest;
  }

  int get todaySessionCount {
    final today = DateTime.now();
    return history
        .where((s) =>
            s.wasCompleted &&
            s.startedAt.day == today.day &&
            s.startedAt.month == today.month &&
            s.startedAt.year == today.year)
        .length;
  }

  int get todayFocusMinutes {
    final today = DateTime.now();
    return history
        .where((s) =>
            s.wasCompleted &&
            s.startedAt.day == today.day &&
            s.startedAt.month == today.month &&
            s.startedAt.year == today.year)
        .fold<int>(0, (sum, s) => sum + s.durationMinutes);
  }

  FocusState copyWith({
    FocusSession? activeSession,
    bool clearActiveSession = false,
    FocusSession? lastFinishedSession,
    bool clearLastFinishedSession = false,
    List<FocusSession>? history,
    int? remainingSeconds,
    FocusSessionPhase? phase,
  }) {
    return FocusState(
      activeSession:
          clearActiveSession ? null : (activeSession ?? this.activeSession),
      lastFinishedSession: clearLastFinishedSession
          ? null
          : (lastFinishedSession ?? this.lastFinishedSession),
      history: history ?? this.history,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      phase: phase ?? this.phase,
    );
  }
}

class FocusNotifier extends StateNotifier<FocusState> {
  final Ref ref;
  final FocusService focusService;
  Timer? _timer;
  DateTime? _sessionEndsAt;
  bool _sessionTransitionInProgress = false;
  static const _uuid = Uuid();

  FocusNotifier({required this.ref, required this.focusService})
      : super(const FocusState()) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final sessions = await focusService.getTodaySessions();
    state = state.copyWith(history: sessions);
  }

  /// Start a focus session.
  void startSession({int durationMinutes = 25}) {
    if (state.isActive) return;
    _timer?.cancel();
    _sessionTransitionInProgress = false;

    final startedAt = DateTime.now();
    final session = FocusSession(
      id: _uuid.v4(),
      durationMinutes: durationMinutes,
      startedAt: startedAt,
    );
    _sessionEndsAt = startedAt.add(Duration(minutes: durationMinutes));

    state = state.copyWith(
      activeSession: session,
      remainingSeconds: durationMinutes * 60,
      phase: FocusSessionPhase.running,
      clearLastFinishedSession: true,
    );

    // Notify native core — focus mode activates a stricter policy profile
    unawaited(PlatformChannel.instance.setFocusMode(active: true));

    _syncRemainingTime();
    _timer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => _syncRemainingTime(),
    );
  }

  void _syncRemainingTime() {
    if (!state.isActive ||
        state.activeSession == null ||
        _sessionEndsAt == null) {
      _timer?.cancel();
      return;
    }

    final remainingMs =
        _sessionEndsAt!.difference(DateTime.now()).inMilliseconds;
    if (remainingMs <= 0) {
      if (state.remainingSeconds != 0) {
        state = state.copyWith(remainingSeconds: 0);
      }
      if (_sessionTransitionInProgress) return;
      _sessionTransitionInProgress = true;
      _timer?.cancel();
      unawaited(completeSession(completedAt: _sessionEndsAt));
      return;
    }

    final remaining = (remainingMs / 1000).ceil();
    if (remaining != state.remainingSeconds) {
      state = state.copyWith(remainingSeconds: remaining);
    }
  }

  /// End session early.
  Future<void> endSession() => interruptSession();

  Future<void> interruptSession() async {
    _timer?.cancel();
    _sessionEndsAt = null;
    final activeSession = state.activeSession;
    if (activeSession == null || !state.isActive) return;
    if (_sessionTransitionInProgress) return;
    _sessionTransitionInProgress = true;

    final interrupted = activeSession.copyWith(
      completedAt: DateTime.now(),
      wasCompleted: false,
      xpEarned: 0,
    );

    state = FocusState(
      activeSession: null,
      lastFinishedSession: interrupted,
      history: _mergeHistory(interrupted),
      remainingSeconds: 0,
      phase: FocusSessionPhase.interrupted,
    );
    await focusService.saveSession(interrupted);
    await PlatformChannel.instance.setFocusMode(active: false);
    ref.read(reportRefreshVersionProvider.notifier).markDirty();
    _sessionTransitionInProgress = false;
  }

  /// Complete successfully.
  Future<void> completeSession({DateTime? completedAt}) async {
    final activeSession = state.activeSession;
    if (activeSession == null || !state.isActive) return;
    _timer?.cancel();
    _sessionEndsAt = null;
    if (_sessionTransitionInProgress &&
        state.phase != FocusSessionPhase.running) {
      return;
    }
    _sessionTransitionInProgress = true;

    const xpReward = 20;
    final completed = activeSession.copyWith(
      completedAt: completedAt ?? DateTime.now(),
      wasCompleted: true,
      xpEarned: xpReward,
    );

    state = FocusState(
      activeSession: null,
      lastFinishedSession: completed,
      history: _mergeHistory(completed),
      remainingSeconds: 0,
      phase: FocusSessionPhase.completed,
    );

    await focusService.saveSession(completed);
    await PlatformChannel.instance.setFocusMode(active: false);
    // Award XP globally
    ref.read(systemProvider.notifier).awardXP(xpReward);
    await ref.read(systemProvider.notifier).refreshProfile();
    ref.read(reportRefreshVersionProvider.notifier).markDirty();
    _sessionTransitionInProgress = false;
  }

  List<FocusSession> _mergeHistory(FocusSession session) {
    final history = [
      ...state.history.where((existing) => existing.id != session.id),
      session,
    ];
    history.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return history;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final focusServiceProvider = Provider<FocusService>((ref) {
  return FocusService();
});

final focusProvider = StateNotifierProvider<FocusNotifier, FocusState>((ref) {
  return FocusNotifier(
    ref: ref,
    focusService: ref.read(focusServiceProvider),
  );
});
