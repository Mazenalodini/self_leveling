/// Classification of an app's behavioral impact.
///
/// The native layer (AppClassifier.kt) is the authoritative classifier and the
/// canonical runtime contract is `AppCategory`.
///
/// This enum remains as a Flutter-side analytics/UI classification type and is
/// intentionally aligned to the same numeric ordering.
enum BehaviorCategory {
  /// Apps that contribute to productivity (e.g., Notes, IDE, Books).
  productive,

  /// Neutral apps (e.g., Settings, Camera, Calculator).
  neutral,

  /// Apps that are considered distracting (e.g., TikTok, Instagram, Games).
  distracting,

  /// System-critical apps that must NEVER be blocked (launcher, keyboard, etc.).
  essential,

  /// User manually classified this app via blacklist/whitelist.
  userDefined,
}
