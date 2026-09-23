import 'package:equatable/equatable.dart';

import '../contracts/runtime_contract.dart';

abstract final class CanonicalSettingKeys {
  static const warningDelay = 'warning_delay';
  static const overlayDuration = 'overlay_duration';
  static const hardLockDuration = 'hard_lock_duration';

  const CanonicalSettingKeys._();
}

class AppSettings extends Equatable {
  final double systemSensitivity;
  final double escalationStrength;
  final bool notificationsEnabled;
  final double warningDelayMinutes;
  final double overlayDurationMinutes;
  final double hardLockDurationMinutes;

  const AppSettings({
    this.systemSensitivity = 0.5,
    this.escalationStrength = 0.5,
    this.notificationsEnabled = true,
    this.warningDelayMinutes = 3,
    this.overlayDurationMinutes = 10,
    this.hardLockDurationMinutes = 45,
  });

  factory AppSettings.fromStorage({
    required Map<String, String> keyValues,
    Map<String, dynamic>? legacyProfileRow,
  }) {
    double? parseDouble(String key) => double.tryParse(keyValues[key] ?? '');
    bool? parseBool(String key) {
      final raw = keyValues[key];
      if (raw == null) return null;
      return raw == '1' || raw.toLowerCase() == 'true';
    }

    final legacySensitivity =
        (legacyProfileRow?[RuntimeSettingKeys.systemSensitivity] as num?)
            ?.toDouble();
    final legacyStrength =
        (legacyProfileRow?[RuntimeSettingKeys.escalationStrength] as num?)
            ?.toDouble();
    final legacyNotificationsRaw =
        legacyProfileRow?[RuntimeSettingKeys.notificationsEnabled];
    final legacyNotifications = legacyNotificationsRaw == null
        ? null
        : (legacyNotificationsRaw as int?) == 1;

    return AppSettings(
      systemSensitivity: (parseDouble(RuntimeSettingKeys.systemSensitivity) ??
              legacySensitivity ??
              0.5)
          .clamp(0.0, 1.0),
      escalationStrength: (parseDouble(RuntimeSettingKeys.escalationStrength) ??
              legacyStrength ??
              0.5)
          .clamp(0.0, 1.0),
      notificationsEnabled:
          parseBool(RuntimeSettingKeys.notificationsEnabled) ??
              legacyNotifications ??
              true,
      warningDelayMinutes:
          (parseDouble(CanonicalSettingKeys.warningDelay) ?? 3).clamp(2, 15),
      overlayDurationMinutes:
          (parseDouble(CanonicalSettingKeys.overlayDuration) ?? 10)
              .clamp(8, 30),
      hardLockDurationMinutes:
          (parseDouble(CanonicalSettingKeys.hardLockDuration) ?? 45)
              .clamp(30, 120),
    );
  }

  Map<String, String> toStorageMap() => {
        RuntimeSettingKeys.systemSensitivity: systemSensitivity.toString(),
        RuntimeSettingKeys.escalationStrength: escalationStrength.toString(),
        RuntimeSettingKeys.notificationsEnabled:
            notificationsEnabled ? '1' : '0',
        CanonicalSettingKeys.warningDelay: warningDelayMinutes.toString(),
        CanonicalSettingKeys.overlayDuration: overlayDurationMinutes.toString(),
        CanonicalSettingKeys.hardLockDuration:
            hardLockDurationMinutes.toString(),
      };

  AppSettings copyWith({
    double? systemSensitivity,
    double? escalationStrength,
    bool? notificationsEnabled,
    double? warningDelayMinutes,
    double? overlayDurationMinutes,
    double? hardLockDurationMinutes,
  }) {
    return AppSettings(
      systemSensitivity: systemSensitivity ?? this.systemSensitivity,
      escalationStrength: escalationStrength ?? this.escalationStrength,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      warningDelayMinutes: warningDelayMinutes ?? this.warningDelayMinutes,
      overlayDurationMinutes:
          overlayDurationMinutes ?? this.overlayDurationMinutes,
      hardLockDurationMinutes:
          hardLockDurationMinutes ?? this.hardLockDurationMinutes,
    );
  }

  @override
  List<Object?> get props => [
        systemSensitivity,
        escalationStrength,
        notificationsEnabled,
        warningDelayMinutes,
        overlayDurationMinutes,
        hardLockDurationMinutes,
      ];
}
