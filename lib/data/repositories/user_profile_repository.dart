import 'dart:convert';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user_profile.dart';
import 'auth_repository.dart';
import 'local_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  final authRepo = ref.read(authRepositoryProvider);
  return UserProfileRepository(authRepo);
});

/// Handles saving and retrieving the UserProfile.
/// Implements a Single-Account Local-First + Cloud Sync architecture.
class UserProfileRepository {
  final AuthRepository? _authRepo;
  final LocalProfileRepository _localProfileRepository =
      LocalProfileRepository();
  late final FirebaseFirestore _firestore;

  UserProfileRepository(this._authRepo) {
    _firestore = FirebaseFirestore.instance;
  }

  /// Prefix for all local user profile storage keys
  String _localKey(String uid) => 'local_profile_$uid';

  Future<UserProfile> getLocalCanonicalProfile() async {
    return _localProfileRepository.getOrCreateCanonicalProfile();
  }

  Future<void> saveLocalProfile(UserProfile profile) async {
    final canonical = _normalizeLocalProfile(profile);
    await _localProfileRepository.saveCanonicalProfile(canonical);
    await _writeLegacyCache(canonical);
  }

  /// Startup/readiness lookup.
  ///
  /// This intentionally stays local-first and does not hit Firestore. Boot flow
  /// must not block on cloud fetches when deciding whether the app should route
  /// to onboarding/setup/dashboard.
  Future<UserProfile?> getBootstrapProfile(String uid) async {
    final localCanonical =
        await _localProfileRepository.getProfileForAccount(uid);
    if (localCanonical != null) {
      return localCanonical;
    }

    final legacyLocal = await _readLegacyCache(uid);
    if (legacyLocal == null) return null;

    final canonical = _normalizeLocalProfile(legacyLocal, explicitUid: uid);
    await _localProfileRepository.saveCanonicalProfile(canonical);
    await _writeLegacyCache(canonical);
    return canonical;
  }

  /// Fetch the profile for the given UID using Local-First strategy.
  Future<UserProfile?> getProfile(String uid) async {
    final bootstrapProfile = await getBootstrapProfile(uid);
    if (bootstrapProfile != null) return bootstrapProfile;

    try {
      final doc = await _firestore
          .collection('users')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      if (doc.exists && doc.data() != null) {
        final cloudProfile = UserProfile.fromMap(doc.data()!);
        final canonical =
            _normalizeLocalProfile(cloudProfile, explicitUid: uid);
        await _localProfileRepository.saveCanonicalProfile(canonical);
        await _writeLegacyCache(canonical);
        return canonical;
      }
    } catch (e) {
      log("Cloud sync fallback error for profile fetch: $e");
    }

    return null;
  }

  /// Save or update the profile using Local-First sync rules.
  Future<void> saveProfile(UserProfile profile) async {
    final canonical = _normalizeLocalProfile(profile);
    await _localProfileRepository.saveCanonicalProfile(canonical);
    await _writeLegacyCache(canonical);

    final syncUid = canonical.accountUid;
    if (syncUid == null || syncUid.isEmpty) return;

    try {
      final syncProfile = canonical.copyWith(id: syncUid, accountUid: syncUid);
      await _firestore.collection('users').doc(syncUid).set(
            syncProfile.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      log("Cloud sync pending or failed for profile save: $e");
    }
  }

  UserProfile _normalizeLocalProfile(
    UserProfile profile, {
    String? explicitUid,
  }) {
    final fallbackUid = explicitUid ??
        profile.accountUid ??
        (profile.id != UserProfile.canonicalLocalId ? profile.id : null) ??
        _authRepo?.currentUser?.uid;

    return profile.copyWith(
      id: UserProfile.canonicalLocalId,
      accountUid: fallbackUid,
    );
  }

  Future<UserProfile?> _readLegacyCache(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final localStr = prefs.getString(_localKey(uid));
    if (localStr == null || localStr.isEmpty) return null;

    try {
      return UserProfile.fromMap(jsonDecode(localStr));
    } catch (e) {
      log("Local profile parse error for $uid: $e");
      return null;
    }
  }

  Future<void> _writeLegacyCache(UserProfile canonical) async {
    final syncUid = canonical.accountUid;
    if (syncUid == null || syncUid.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final cacheProfile = canonical.copyWith(id: syncUid, accountUid: syncUid);
    await prefs.setString(_localKey(syncUid), jsonEncode(cacheProfile.toMap()));
  }
}
