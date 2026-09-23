import 'package:equatable/equatable.dart';

/// User profile entity — level, XP, identity, settings, and structured onboarding schema.
class UserProfile extends Equatable {
  static const canonicalLocalId = 'default';

  final String id;
  final String? accountUid;
  final String displayName;
  final String? email;
  final String identityStatement; // Displayed main identity
  final int level;
  final int currentXP;
  final int totalXPEarned;
  final int selfControlScore; // 0-100
  final double systemSensitivity; // 0.0-1.0 (escalation sensitivity)
  final double escalationStrength; // 0.0-1.0 (how aggressive)
  final bool notificationsEnabled;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  // ── Phase 3 Structured Onboarding Data ──
  final String occupation;
  final String primaryIdentity;
  final List<String> frustrationPoints;
  final List<String> distractionCategories;
  final String weaknessWindow;
  final String emotionalTrigger;
  final List<String> targetHabits;
  final String breakTarget;
  final String installReason;
  final String strictnessPreference;
  final String messageStylePreference;
  final String interventionPreference;
  final String preferredHabitSize;

  // Custom texts from "Other" options or open questions (Q14, Q15)
  final Map<String, String> openReflections;

  // Track onboarding language context
  final String surveyLanguage;

  // ── Placeholders for Future Phase 4 (AI / TFLite) ──
  final Map<String, dynamic> observedProfile; // Behavior-driven data
  final double reconciliationConfidence; // 0.0 - 1.0 match rate

  const UserProfile({
    required this.id,
    this.accountUid,
    required this.displayName,
    this.email,
    this.identityStatement = '',
    this.level = 1,
    this.currentXP = 0,
    this.totalXPEarned = 0,
    this.selfControlScore = 50,
    this.systemSensitivity = 0.5,
    this.escalationStrength = 0.5,
    this.notificationsEnabled = true,
    required this.createdAt,
    required this.lastActiveAt,

    // Default onboarding fields
    this.occupation = '',
    this.primaryIdentity = '',
    this.frustrationPoints = const [],
    this.distractionCategories = const [],
    this.weaknessWindow = '',
    this.emotionalTrigger = '',
    this.targetHabits = const [],
    this.breakTarget = '',
    this.installReason = '',
    this.strictnessPreference = '',
    this.messageStylePreference = '',
    this.interventionPreference = '',
    this.preferredHabitSize = '',
    this.openReflections = const {},
    this.surveyLanguage = 'en',

    // Default AI placeholders
    this.observedProfile = const {},
    this.reconciliationConfidence = 1.0,
  });

  /// XP required to reach the next level.
  int get xpForNextLevel => 100 + (level - 1) * 50;

  /// Progress toward next level (0.0 → 1.0).
  double get levelProgress => currentXP / xpForNextLevel;

  /// Whether the user has enough XP to level up.
  bool get canLevelUp => currentXP >= xpForNextLevel;

  UserProfile copyWith({
    String? id,
    String? accountUid,
    String? displayName,
    String? email,
    String? identityStatement,
    int? level,
    int? currentXP,
    int? totalXPEarned,
    int? selfControlScore,
    double? systemSensitivity,
    double? escalationStrength,
    bool? notificationsEnabled,
    DateTime? lastActiveAt,
    String? occupation,
    String? primaryIdentity,
    List<String>? frustrationPoints,
    List<String>? distractionCategories,
    String? weaknessWindow,
    String? emotionalTrigger,
    List<String>? targetHabits,
    String? breakTarget,
    String? installReason,
    String? strictnessPreference,
    String? messageStylePreference,
    String? interventionPreference,
    String? preferredHabitSize,
    Map<String, String>? openReflections,
    String? surveyLanguage,
    Map<String, dynamic>? observedProfile,
    double? reconciliationConfidence,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      accountUid: accountUid ?? this.accountUid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      identityStatement: identityStatement ?? this.identityStatement,
      level: level ?? this.level,
      currentXP: currentXP ?? this.currentXP,
      totalXPEarned: totalXPEarned ?? this.totalXPEarned,
      selfControlScore: selfControlScore ?? this.selfControlScore,
      systemSensitivity: systemSensitivity ?? this.systemSensitivity,
      escalationStrength: escalationStrength ?? this.escalationStrength,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      occupation: occupation ?? this.occupation,
      primaryIdentity: primaryIdentity ?? this.primaryIdentity,
      frustrationPoints: frustrationPoints ?? this.frustrationPoints,
      distractionCategories:
          distractionCategories ?? this.distractionCategories,
      weaknessWindow: weaknessWindow ?? this.weaknessWindow,
      emotionalTrigger: emotionalTrigger ?? this.emotionalTrigger,
      targetHabits: targetHabits ?? this.targetHabits,
      breakTarget: breakTarget ?? this.breakTarget,
      installReason: installReason ?? this.installReason,
      strictnessPreference: strictnessPreference ?? this.strictnessPreference,
      messageStylePreference:
          messageStylePreference ?? this.messageStylePreference,
      interventionPreference:
          interventionPreference ?? this.interventionPreference,
      preferredHabitSize: preferredHabitSize ?? this.preferredHabitSize,
      openReflections: openReflections ?? this.openReflections,
      surveyLanguage: surveyLanguage ?? this.surveyLanguage,
      observedProfile: observedProfile ?? this.observedProfile,
      reconciliationConfidence:
          reconciliationConfidence ?? this.reconciliationConfidence,
    );
  }

  /// Serialize to JSON-compatible map for Hive / Firestore storage.
  Map<String, dynamic> toMap() => {
        'id': id,
        'accountUid': accountUid,
        'displayName': displayName,
        'email': email,
        'identityStatement': identityStatement,
        'level': level,
        'currentXP': currentXP,
        'totalXPEarned': totalXPEarned,
        'selfControlScore': selfControlScore,
        'systemSensitivity': systemSensitivity,
        'escalationStrength': escalationStrength,
        'notificationsEnabled': notificationsEnabled,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'lastActiveAt': lastActiveAt.millisecondsSinceEpoch,

        // Phase 3 fields
        'occupation': occupation,
        'primaryIdentity': primaryIdentity,
        'frustrationPoints': frustrationPoints,
        'distractionCategories': distractionCategories,
        'weaknessWindow': weaknessWindow,
        'emotionalTrigger': emotionalTrigger,
        'targetHabits': targetHabits,
        'breakTarget': breakTarget,
        'installReason': installReason,
        'strictnessPreference': strictnessPreference,
        'messageStylePreference': messageStylePreference,
        'interventionPreference': interventionPreference,
        'preferredHabitSize': preferredHabitSize,
        'openReflections': openReflections,
        'surveyLanguage': surveyLanguage,

        // AI Placeholders
        'observedProfile': observedProfile,
        'reconciliationConfidence': reconciliationConfidence,
      };

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) => UserProfile(
        id: map['id'] as String,
        accountUid: map['accountUid'] as String?,
        displayName: map['displayName'] as String,
        email: map['email'] as String?,
        identityStatement: map['identityStatement'] as String? ?? '',
        level: map['level'] as int? ?? 1,
        currentXP: map['currentXP'] as int? ?? 0,
        totalXPEarned: map['totalXPEarned'] as int? ?? 0,
        selfControlScore: map['selfControlScore'] as int? ?? 50,
        systemSensitivity:
            (map['systemSensitivity'] as num?)?.toDouble() ?? 0.5,
        escalationStrength:
            (map['escalationStrength'] as num?)?.toDouble() ?? 0.5,
        notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt'] as int),
        lastActiveAt:
            DateTime.fromMillisecondsSinceEpoch(map['lastActiveAt'] as int),

        // Phase 3 fields extraction
        occupation: map['occupation'] as String? ?? '',
        primaryIdentity: map['primaryIdentity'] as String? ?? '',
        frustrationPoints: List<String>.from(map['frustrationPoints'] ?? []),
        distractionCategories:
            List<String>.from(map['distractionCategories'] ?? []),
        weaknessWindow: map['weaknessWindow'] as String? ?? '',
        emotionalTrigger: map['emotionalTrigger'] as String? ?? '',
        targetHabits: List<String>.from(map['targetHabits'] ?? []),
        breakTarget: map['breakTarget'] as String? ?? '',
        installReason: map['installReason'] as String? ?? '',
        strictnessPreference: map['strictnessPreference'] as String? ?? '',
        messageStylePreference: map['messageStylePreference'] as String? ?? '',
        interventionPreference: map['interventionPreference'] as String? ?? '',
        preferredHabitSize: map['preferredHabitSize'] as String? ?? '',
        openReflections: Map<String, String>.from(map['openReflections'] ?? {}),
        surveyLanguage: map['surveyLanguage'] as String? ?? 'en',

        observedProfile:
            Map<String, dynamic>.from(map['observedProfile'] ?? {}),
        reconciliationConfidence:
            (map['reconciliationConfidence'] as num?)?.toDouble() ?? 1.0,
      );

  /// Create a new default profile.
  factory UserProfile.create({
    String id = canonicalLocalId,
    String? accountUid,
    required String displayName,
    String? email,
  }) {
    final now = DateTime.now();
    return UserProfile(
      id: id,
      accountUid: accountUid,
      displayName: displayName,
      email: email,
      createdAt: now,
      lastActiveAt: now,
    );
  }

  @override
  List<Object?> get props => [
        id,
        accountUid,
        level,
        currentXP,
        selfControlScore,
        occupation,
        primaryIdentity,
        frustrationPoints,
        distractionCategories,
        weaknessWindow,
        targetHabits,
        breakTarget,
        installReason,
        interventionPreference,
      ];
}
