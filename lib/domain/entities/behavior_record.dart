import 'package:equatable/equatable.dart';
import '../enums/behavior_category.dart';

/// A single app usage record from the platform layer.
class AppUsageRecord extends Equatable {
  final String packageName;
  final String appName;
  final BehaviorCategory category;
  final DateTime startTime;
  final int durationSeconds;

  const AppUsageRecord({
    required this.packageName,
    required this.appName,
    required this.category,
    required this.startTime,
    required this.durationSeconds,
  });

  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toMap() => {
    'packageName': packageName,
    'appName': appName,
    'category': category.index,
    'startTime': startTime.millisecondsSinceEpoch,
    'durationSeconds': durationSeconds,
  };

  factory AppUsageRecord.fromMap(Map<dynamic, dynamic> map) => AppUsageRecord(
    packageName: map['packageName'] as String,
    appName: map['appName'] as String,
    category: BehaviorCategory.values[map['category'] as int? ?? 1],
    startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
    durationSeconds: map['durationSeconds'] as int,
  );

  @override
  List<Object?> get props => [packageName, startTime, durationSeconds];
}

/// Aggregated behavior record for analysis.
class BehaviorRecord extends Equatable {
  final DateTime timestamp;
  final int productiveSeconds;
  final int neutralSeconds;
  final int distractingSeconds;
  final int sessionCount; // How many times distracting apps opened
  final String? topDistractingApp;

  const BehaviorRecord({
    required this.timestamp,
    required this.productiveSeconds,
    required this.neutralSeconds,
    required this.distractingSeconds,
    required this.sessionCount,
    this.topDistractingApp,
  });

  int get totalSeconds => productiveSeconds + neutralSeconds + distractingSeconds;

  /// Ratio of distracting time to total time (0.0 → 1.0).
  double get distractionRatio {
    if (totalSeconds == 0) return 0;
    return distractingSeconds / totalSeconds;
  }

  /// Ratio of productive time to total time (0.0 → 1.0).
  double get productiveRatio {
    if (totalSeconds == 0) return 0;
    return productiveSeconds / totalSeconds;
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'productiveSeconds': productiveSeconds,
    'neutralSeconds': neutralSeconds,
    'distractingSeconds': distractingSeconds,
    'sessionCount': sessionCount,
    'topDistractingApp': topDistractingApp,
  };

  factory BehaviorRecord.fromMap(Map<dynamic, dynamic> map) => BehaviorRecord(
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    productiveSeconds: map['productiveSeconds'] as int? ?? 0,
    neutralSeconds: map['neutralSeconds'] as int? ?? 0,
    distractingSeconds: map['distractingSeconds'] as int? ?? 0,
    sessionCount: map['sessionCount'] as int? ?? 0,
    topDistractingApp: map['topDistractingApp'] as String?,
  );

  @override
  List<Object?> get props => [timestamp, distractingSeconds, sessionCount];
}
