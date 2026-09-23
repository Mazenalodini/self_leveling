import '../data/repositories/local_profile_repository.dart';
import '../data/repositories/progression_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../domain/entities/user_profile.dart';

/// Service for XP, level management, and profile operations with SQLite.
class XPService {
  LocalProfileRepository? _localProfileRepository;
  UserProfileRepository? _userProfileRepository;
  SettingsRepository? _settingsRepository;
  ProgressionRepository? _progressionRepository;

  XPService({
    LocalProfileRepository? localProfileRepository,
    UserProfileRepository? userProfileRepository,
    SettingsRepository? settingsRepository,
    ProgressionRepository? progressionRepository,
  })  : _localProfileRepository = localProfileRepository,
        _userProfileRepository = userProfileRepository,
        _settingsRepository = settingsRepository,
        _progressionRepository = progressionRepository;

  LocalProfileRepository get _localProfiles =>
      _localProfileRepository ??= LocalProfileRepository();

  UserProfileRepository get _userProfiles =>
      _userProfileRepository ??= UserProfileRepository(null);

  SettingsRepository get _settings =>
      _settingsRepository ??= SettingsRepository();

  ProgressionRepository get _progression =>
      _progressionRepository ??= ProgressionRepository();

  Future<void> init() async {
    // DB is lazy-initialized
  }

  /// Get or create the user profile.
  Future<UserProfile> getProfile() async {
    return _progression.getProjectedProfile();
  }

  /// Award XP and handle level-up.
  Future<UserProfile> awardXP(int amount) async {
    return _progression.awardXP(amount);
  }

  /// Apply XP penalty.
  Future<UserProfile> penalizeXP(int amount) async {
    return _progression.penalizeXP(amount);
  }

  /// Update self-control score (smoothed).
  Future<UserProfile> updateSelfControlScore(int newScore) async {
    return _progression.updateSelfControlScore(newScore);
  }

  /// Update display name.
  Future<UserProfile> updateDisplayName(String name) async {
    var profile = await getProfile();
    profile = profile.copyWith(
      displayName: name,
      lastActiveAt: DateTime.now(),
    );
    await _userProfiles.saveLocalProfile(profile);
    return _userProfiles.getLocalCanonicalProfile();
  }

  /// Update identity statement.
  Future<UserProfile> updateIdentity(String identity) async {
    var profile = await getProfile();
    profile = profile.copyWith(
      identityStatement: identity,
      lastActiveAt: DateTime.now(),
    );
    await _userProfiles.saveLocalProfile(profile);
    return _userProfiles.getLocalCanonicalProfile();
  }

  /// Update system sensitivity.
  Future<UserProfile> updateSensitivity(double value) async {
    final current = await _settings.getSettings();
    await _settings.saveSettings(
      current.copyWith(systemSensitivity: value.clamp(0.0, 1.0)),
    );
    return _localProfiles.getOrCreateCanonicalProfile();
  }

  /// Update escalation strength.
  Future<UserProfile> updateEscalationStrength(double value) async {
    final current = await _settings.getSettings();
    await _settings.saveSettings(
      current.copyWith(escalationStrength: value.clamp(0.0, 1.0)),
    );
    return _localProfiles.getOrCreateCanonicalProfile();
  }

  /// Update notifications enabled.
  Future<UserProfile> updateNotifications(bool enabled) async {
    final current = await _settings.getSettings();
    await _settings.saveSettings(
      current.copyWith(notificationsEnabled: enabled),
    );
    return _localProfiles.getOrCreateCanonicalProfile();
  }

  int _xpRequired(int level) => 100 + (level - 1) * 50;
  int xpForLevel(int level) => _xpRequired(level);
}
