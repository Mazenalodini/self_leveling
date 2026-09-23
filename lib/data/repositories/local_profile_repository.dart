import 'dart:convert';

import '../../core/database/database_helper.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/user_profile.dart';
import 'settings_repository.dart';

class LocalProfileRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;
  final SettingsRepository _settingsRepository = SettingsRepository();

  Future<UserProfile> getOrCreateCanonicalProfile() async {
    final existing = await getCanonicalProfileOrNull();
    if (existing != null) return existing;

    final profile = UserProfile.create(displayName: 'User');
    await saveCanonicalProfile(profile);
    return profile;
  }

  Future<UserProfile?> getCanonicalProfileOrNull() async {
    final row = await _db.queryFirst(
      'user_profile',
      where: 'id = ?',
      whereArgs: [UserProfile.canonicalLocalId],
    );
    if (row == null) return null;

    final settings = await _settingsRepository.getSettings();
    return _mapRowToProfile(row, settings);
  }

  Future<UserProfile?> getProfileForAccount(String accountUid) async {
    final profile = await getCanonicalProfileOrNull();
    if (profile == null) return null;
    if ((profile.accountUid ?? '').isEmpty) return null;
    return profile.accountUid == accountUid ? profile : null;
  }

  Future<void> saveCanonicalProfile(UserProfile profile) async {
    final canonical = _normalizeCanonicalProfile(profile);
    await _db.insert('user_profile', _toDbRow(canonical));
    final existingSettings = await _settingsRepository.getSettings();
    await _settingsRepository.saveSettings(
      existingSettings.copyWith(
        systemSensitivity: canonical.systemSensitivity,
        escalationStrength: canonical.escalationStrength,
        notificationsEnabled: canonical.notificationsEnabled,
      ),
    );
  }

  UserProfile _normalizeCanonicalProfile(UserProfile profile) {
    final syncUid = (profile.accountUid?.isNotEmpty ?? false)
        ? profile.accountUid
        : (profile.id != UserProfile.canonicalLocalId ? profile.id : null);
    return profile.copyWith(
      id: UserProfile.canonicalLocalId,
      accountUid: syncUid,
    );
  }

  UserProfile _mapRowToProfile(
    Map<String, dynamic> row,
    AppSettings settings,
  ) {
    final storedId = row['id'] as String? ?? UserProfile.canonicalLocalId;
    final accountUid = row['account_uid'] as String?;

    return UserProfile(
      id: storedId,
      accountUid: accountUid,
      displayName: row['display_name'] as String? ?? 'User',
      email: row['email'] as String?,
      identityStatement: row['identity_statement'] as String? ?? '',
      level: row['level'] as int? ?? 1,
      currentXP: row['current_xp'] as int? ?? 0,
      totalXPEarned: row['total_xp_earned'] as int? ?? 0,
      selfControlScore: row['self_control_score'] as int? ?? 50,
      systemSensitivity: settings.systemSensitivity,
      escalationStrength: settings.escalationStrength,
      notificationsEnabled: settings.notificationsEnabled,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      lastActiveAt: DateTime.fromMillisecondsSinceEpoch(
        row['last_active_at'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      occupation: row['occupation'] as String? ?? '',
      primaryIdentity: row['primary_identity'] as String? ?? '',
      frustrationPoints: _decodeStringList(row['frustration_points_json']),
      distractionCategories:
          _decodeStringList(row['distraction_categories_json']),
      weaknessWindow: row['weakness_window'] as String? ?? '',
      emotionalTrigger: row['emotional_trigger'] as String? ?? '',
      targetHabits: _decodeStringList(row['target_habits_json']),
      breakTarget: row['break_target'] as String? ?? '',
      installReason: row['install_reason'] as String? ?? '',
      strictnessPreference: row['strictness_preference'] as String? ?? '',
      messageStylePreference: row['message_style_preference'] as String? ?? '',
      interventionPreference: row['intervention_preference'] as String? ?? '',
      preferredHabitSize: row['preferred_habit_size'] as String? ?? '',
      openReflections: _decodeStringMap(row['open_reflections_json']),
      surveyLanguage: row['survey_language'] as String? ?? 'en',
      observedProfile: _decodeDynamicMap(row['observed_profile_json']),
      reconciliationConfidence:
          (row['reconciliation_confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }

  Map<String, dynamic> _toDbRow(UserProfile profile) {
    final accountUid = (profile.accountUid?.isNotEmpty ?? false)
        ? profile.accountUid
        : (profile.id != UserProfile.canonicalLocalId ? profile.id : null);

    return {
      'id': UserProfile.canonicalLocalId,
      'account_uid': accountUid,
      'display_name': profile.displayName,
      'identity_statement': profile.identityStatement,
      'email': profile.email ?? '',
      'level': profile.level,
      'current_xp': profile.currentXP,
      'total_xp_earned': profile.totalXPEarned,
      'self_control_score': profile.selfControlScore,
      'system_sensitivity': profile.systemSensitivity,
      'escalation_strength': profile.escalationStrength,
      'notifications_enabled': profile.notificationsEnabled ? 1 : 0,
      'occupation': profile.occupation,
      'primary_identity': profile.primaryIdentity,
      'frustration_points_json': jsonEncode(profile.frustrationPoints),
      'distraction_categories_json': jsonEncode(profile.distractionCategories),
      'weakness_window': profile.weaknessWindow,
      'emotional_trigger': profile.emotionalTrigger,
      'target_habits_json': jsonEncode(profile.targetHabits),
      'break_target': profile.breakTarget,
      'install_reason': profile.installReason,
      'strictness_preference': profile.strictnessPreference,
      'message_style_preference': profile.messageStylePreference,
      'intervention_preference': profile.interventionPreference,
      'preferred_habit_size': profile.preferredHabitSize,
      'open_reflections_json': jsonEncode(profile.openReflections),
      'survey_language': profile.surveyLanguage,
      'observed_profile_json': jsonEncode(profile.observedProfile),
      'reconciliation_confidence': profile.reconciliationConfidence,
      'created_at': profile.createdAt.millisecondsSinceEpoch,
      'last_active_at': profile.lastActiveAt.millisecondsSinceEpoch,
    };
  }

  List<String> _decodeStringList(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return const [];
    try {
      return List<String>.from(jsonDecode(raw as String));
    } catch (_) {
      return const [];
    }
  }

  Map<String, String> _decodeStringMap(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return const {};
    try {
      return Map<String, String>.from(jsonDecode(raw as String));
    } catch (_) {
      return const {};
    }
  }

  Map<String, dynamic> _decodeDynamicMap(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return const {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw as String));
    } catch (_) {
      return const {};
    }
  }
}
