import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/locale_provider.dart';

/// Returns the correct [AppLocalizations] based on the current locale.
/// Usage: `final s = S.of(ref);`  then `s.appName`
class S {
  static AppLocalizations of(WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return locale.languageCode == 'ar' ? const _Arabic() : const _English();
  }

  /// For use inside State classes that don't have a WidgetRef, use BuildContext.
  static AppLocalizations fromContext(BuildContext context, WidgetRef ref) {
    return of(ref);
  }
}

/// Abstract contract for all translatable strings.
abstract class AppLocalizations {
  const AppLocalizations();

  // ── App ──
  String get appName;
  String get appVersion;
  String get appTagline;
  String get systemInterfaceActive;

  // ── Auth ──
  String get welcomeBack;
  String get continueJourney;
  String get startJourney;
  String get createAccount;
  String get createYourAccount;
  String get startTransformation;
  String get login;
  String get email;
  String get password;
  String get confirmPassword;
  String get forgotPassword;
  String get alreadyHaveAccount;
  String get emailPlaceholder;
  String get passwordPlaceholder;
  String get systemLogin;
  String get systemRegistration;

  // ── Dashboard ──
  String get systemStatus;
  String get selfControlLevel;
  String get control;
  String get level;
  String get focus;
  String get distraction;
  String get habits;
  String get systemMessage;
  String get improving;
  String get startFocusMode;
  String get activeSystem;

  // ── Habits ──
  String get habitsAndIdentity;
  String get shapeWho;
  String get yourIdentity;
  String get identityQuote;
  String get build;
  String get breakText;
  String get done;
  String get avoided;
  String get addHabit;
  String get suggestedBySystem;
  String get identitySystem;

  // ── AI ──
  String get systemAI;
  String get yourPersonalGuide;
  String get aiActive;
  String get askYourSystem;

  // ── Stats ──
  String get statistics;
  String get progressInsights;
  String get thisWeek;
  String get distracted;
  String get complete;
  String get weeklyOverview;
  String get mostUsedApps;
  String get habitProgress;
  String get aiInsight;
  String get analyticsActive;

  // ── Level ──
  String get yourLevel;
  String get growthInProgress;
  String get experiencePoints;
  String get recentChanges;
  String get achievements;
  String get levelSystem;

  // ── Settings ──
  String get settings;
  String get customizeSystem;
  String get systemSensitivity;
  String get escalationStrength;
  String get notifications;
  String get habitPriority;
  String get escalationSettings;
  String get profileSettings;
  String get helpAndSupport;
  String get logout;
  String get settingsPanel;
  String get language;
  String get selectLanguage;
  String get languageChangeNote;
  String get appManagement;
  String get usageLimits;
  String get usageDashboard;

  // ── Focus ──
  String get focusModeActive;
  String get stayFocused;
  String get withYou;
  String get endSession;
  String get sessionComplete;
  String get success;

  // ── Overlay / Lock ──
  String get focusModeActivated;
  String get tooLong;
  String get timeRemaining;
  String get resetAndRefocus;
  String get refocus;
  String get systemIntervention;
  String get accessRestricted;
  String get systemAlert;
  String get locked;
  String get lockedFor;
  String get enforcedRestriction;

  // ── Escalation / Warning Dialogs ──
  String get strongWarning;
  String get sustainedDistraction;
  String get continueWillEscalate;
  String xpPenaltyLabel(String amount);
  String get iUnderstand;
  String get distractionDetected;
  String get refocusToAvoid;
  String get behaviorLock;
  String get limitedAccessActive;
  String get fullLockActive;
  String get lockExpiredResume;

  // ── Tracking / Readiness ──
  String get trackingActive;
  String get trackingInactive;
  String get systemReady;
  String get systemNotReady;
  String get notificationsDisabled;
  String get enableNotifications;
  String get warningsWontAppear;

  // ── System Loading ──
  String get analyzing;
  String get aiProcessing;

  // ── Navigation ──
  String get home;
  String get ai;
  String get stats;

  // ── Identity & Gamification ──
  String get identityBuilder;
  String get whoDoYouWantToBe;
  String get selectIdentitiesHint;
  String get confirmIdentity;
  String get addCustomIdentity;
  String get skillTrees;
  String get addSkill;
  String get noIdentitiesFound;
  String get goBackToIdentityBuilder;
  String get dungeons;
  String get addQuest;
  String get enterDungeon;
  String get defeated;
  String get inProgress;
  String get available;

  // ── Weekly Review ──
  String get weeklyReview;
  String get focusTime;
  String get distractedTime;
  String get habitsCompleted;

  // ── Common ──
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get confirm;
  String get ok;
  String get selected;
  String get custom;
  String get today;
  String get yesterday;
  String get minutes;
  String get hours;
}

// ═══════════════════════════════════════════════════
// English
// ═══════════════════════════════════════════════════
class _English extends AppLocalizations {
  const _English();

  @override
  String get appName => 'Self Leveling';
  @override
  String get appVersion => 'v1.0.0';
  @override
  String get appTagline => 'Become the strongest version of yourself';
  @override
  String get systemInterfaceActive => 'System Interface Active';

  @override
  String get welcomeBack => 'Welcome Back';
  @override
  String get continueJourney => 'Continue your leveling journey';
  @override
  String get startJourney => 'Start Your Journey';
  @override
  String get createAccount => 'Create Account';
  @override
  String get createYourAccount => 'Create Your Account';
  @override
  String get startTransformation => 'Start your transformation journey';
  @override
  String get login => 'Login';
  @override
  String get email => 'Email';
  @override
  String get password => 'Password';
  @override
  String get confirmPassword => 'Confirm Password';
  @override
  String get forgotPassword => 'Forgot Password?';
  @override
  String get alreadyHaveAccount => 'Already have an account? ';
  @override
  String get emailPlaceholder => 'your@email.com';
  @override
  String get passwordPlaceholder => '••••••••';
  @override
  String get systemLogin => 'SYSTEM LOGIN';
  @override
  String get systemRegistration => 'SYSTEM REGISTRATION';

  @override
  String get systemStatus => 'System Status';
  @override
  String get selfControlLevel => 'SELF CONTROL LEVEL';
  @override
  String get control => 'Control';
  @override
  String get level => 'LEVEL';
  @override
  String get focus => 'Focus';
  @override
  String get distraction => 'Distraction';
  @override
  String get habits => 'Habits';
  @override
  String get systemMessage => 'SYSTEM MESSAGE';
  @override
  String get improving => 'You are improving. Stay consistent.';
  @override
  String get startFocusMode => 'Start Focus Mode';
  @override
  String get activeSystem => 'ACTIVE SYSTEM';

  @override
  String get habitsAndIdentity => 'Habits & Identity';
  @override
  String get shapeWho => 'Shape who you want to become';
  @override
  String get yourIdentity => 'YOUR IDENTITY';
  @override
  String get identityQuote =>
      '"I want to become a focused and disciplined person"';
  @override
  String get build => 'BUILD';
  @override
  String get breakText => 'BREAK';
  @override
  String get done => 'Done';
  @override
  String get avoided => 'Avoided';
  @override
  String get addHabit => 'Add Habit';
  @override
  String get suggestedBySystem => 'SUGGESTED BY YOUR SYSTEM';
  @override
  String get identitySystem => 'IDENTITY SYSTEM';

  @override
  String get systemAI => 'System AI';
  @override
  String get yourPersonalGuide => 'Your personal guide';
  @override
  String get aiActive => 'AI ACTIVE';
  @override
  String get askYourSystem => 'Ask your system...';

  @override
  String get statistics => 'Statistics';
  @override
  String get progressInsights => 'Your progress insights';
  @override
  String get thisWeek => 'This Week';
  @override
  String get distracted => 'Distracted';
  @override
  String get complete => 'Complete';
  @override
  String get weeklyOverview => 'Weekly Overview';
  @override
  String get mostUsedApps => 'Most Used Apps';
  @override
  String get habitProgress => 'Habit Progress';
  @override
  String get aiInsight => 'AI INSIGHT';
  @override
  String get analyticsActive => 'ANALYTICS ACTIVE';

  @override
  String get yourLevel => 'Your Level';
  @override
  String get growthInProgress => 'Growth in progress';
  @override
  String get experiencePoints => 'Experience Points';
  @override
  String get recentChanges => 'Recent Changes';
  @override
  String get achievements => 'Achievements';
  @override
  String get levelSystem => 'LEVEL SYSTEM';

  @override
  String get settings => 'Settings';
  @override
  String get customizeSystem => 'Customize your system';
  @override
  String get systemSensitivity => 'System Sensitivity';
  @override
  String get escalationStrength => 'Escalation Strength';
  @override
  String get notifications => 'Notifications';
  @override
  String get habitPriority => 'Habit Priority';
  @override
  String get escalationSettings => 'Escalation Settings';
  @override
  String get profileSettings => 'Profile Settings';
  @override
  String get helpAndSupport => 'Help & Support';
  @override
  String get logout => 'Logout';
  @override
  String get settingsPanel => 'SETTINGS PANEL';
  @override
  String get language => 'Language';
  @override
  String get selectLanguage => 'Select Language';
  @override
  String get languageChangeNote =>
      'Changing the language will update the entire app interface. All your data will be preserved.';
  @override
  String get appManagement => 'App Management';
  @override
  String get usageLimits => 'Usage Limits';
  @override
  String get usageDashboard => 'Usage Dashboard';

  @override
  String get focusModeActive => 'Focus Mode Active';
  @override
  String get stayFocused => 'Stay focused. Your system is ';
  @override
  String get withYou => 'with you';
  @override
  String get endSession => 'End Session';
  @override
  String get sessionComplete => 'Session Complete';
  @override
  String get success => 'SUCCESS';

  @override
  String get focusModeActivated => 'Focus Mode Activated';
  @override
  String get tooLong => 'too long';
  @override
  String get timeRemaining => 'Time Remaining';
  @override
  String get resetAndRefocus => 'reset';
  @override
  String get refocus => 'refocus';
  @override
  String get systemIntervention => 'SYSTEM INTERVENTION';
  @override
  String get accessRestricted => 'Access Restricted';
  @override
  String get systemAlert => 'System Alert';
  @override
  String get locked => 'locked';
  @override
  String get lockedFor => 'Locked For';
  @override
  String get enforcedRestriction => 'ENFORCED RESTRICTION';

  @override
  String get strongWarning => 'Reminder';
  @override
  String get sustainedDistraction => 'Sustained distraction detected.';
  @override
  String get continueWillEscalate =>
      'If you continue, the system will escalate to a temporary block.';
  @override
  String xpPenaltyLabel(String amount) => 'XP Penalty: $amount XP';
  @override
  String get iUnderstand => 'I understand';
  @override
  String get distractionDetected => 'Distraction detected';
  @override
  String get refocusToAvoid => 'Refocus to avoid escalation';
  @override
  String get behaviorLock => 'Behavior Lock';
  @override
  String get limitedAccessActive => 'Limited Re-entry Active';
  @override
  String get fullLockActive => 'Full Lockdown Active';
  @override
  String get lockExpiredResume => 'Lock expired — you may resume';

  @override
  String get trackingActive => 'Tracking Active';
  @override
  String get trackingInactive => 'Tracking Inactive';
  @override
  String get systemReady => 'System Ready';
  @override
  String get systemNotReady => 'System Not Ready';
  @override
  String get notificationsDisabled => 'Notifications disabled';
  @override
  String get enableNotifications => 'Enable';
  @override
  String get warningsWontAppear => 'Warnings won\'t appear';

  @override
  String get analyzing => 'Analyzing';
  @override
  String get aiProcessing => 'AI PROCESSING';

  @override
  String get home => 'Home';
  @override
  String get ai => 'AI';
  @override
  String get stats => 'Stats';

  @override
  String get identityBuilder => 'Identity Builder';
  @override
  String get whoDoYouWantToBe => 'Who do you want to be?';
  @override
  String get selectIdentitiesHint => 'Select 2-3 identities for your journey';
  @override
  String get confirmIdentity => 'Confirm Identity';
  @override
  String get addCustomIdentity => 'Custom Identity';
  @override
  String get skillTrees => 'Skill Trees';
  @override
  String get addSkill => 'Add Skill';
  @override
  String get noIdentitiesFound => 'No Identities Found';
  @override
  String get goBackToIdentityBuilder =>
      'Go back to Identity Builder to pick your path.';
  @override
  String get dungeons => 'Dungeons';
  @override
  String get addQuest => 'Add Quest';
  @override
  String get enterDungeon => 'Enter Dungeon';
  @override
  String get defeated => 'DEFEATED';
  @override
  String get inProgress => 'IN PROGRESS';
  @override
  String get available => 'AVAILABLE';

  @override
  String get weeklyReview => 'Weekly Review';
  @override
  String get focusTime => 'Focus Time';
  @override
  String get distractedTime => 'Distracted Time';
  @override
  String get habitsCompleted => 'Habits Completed';

  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get confirm => 'Confirm';
  @override
  String get ok => 'OK';
  @override
  String get selected => 'Selected';
  @override
  String get custom => 'Custom';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String get minutes => 'min';
  @override
  String get hours => 'hr';
}

// ═══════════════════════════════════════════════════
// Arabic
// ═══════════════════════════════════════════════════
class _Arabic extends AppLocalizations {
  const _Arabic();

  @override
  String get appName => 'Self Leveling';
  @override
  String get appVersion => 'v1.0.0';
  @override
  String get appTagline => 'كن أقوى نسخة من نفسك';
  @override
  String get systemInterfaceActive => 'واجهة النظام نشطة';

  @override
  String get welcomeBack => 'مرحباً بعودتك';
  @override
  String get continueJourney => 'أكمل رحلة تطويرك';
  @override
  String get startJourney => 'ابدأ رحلتك';
  @override
  String get createAccount => 'إنشاء حساب';
  @override
  String get createYourAccount => 'أنشئ حسابك';
  @override
  String get startTransformation => 'ابدأ رحلة التحول الخاصة بك';
  @override
  String get login => 'تسجيل الدخول';
  @override
  String get email => 'البريد الإلكتروني';
  @override
  String get password => 'كلمة المرور';
  @override
  String get confirmPassword => 'تأكيد كلمة المرور';
  @override
  String get forgotPassword => 'نسيت كلمة المرور؟';
  @override
  String get alreadyHaveAccount => 'لديك حساب بالفعل؟ ';
  @override
  String get emailPlaceholder => 'your@email.com';
  @override
  String get passwordPlaceholder => '••••••••';
  @override
  String get systemLogin => 'تسجيل دخول النظام';
  @override
  String get systemRegistration => 'تسجيل النظام';

  @override
  String get systemStatus => 'حالة النظام';
  @override
  String get selfControlLevel => 'مستوى التحكم الذاتي';
  @override
  String get control => 'التحكم';
  @override
  String get level => 'المستوى';
  @override
  String get focus => 'التركيز';
  @override
  String get distraction => 'التشتت';
  @override
  String get habits => 'العادات';
  @override
  String get systemMessage => 'رسالة النظام';
  @override
  String get improving => 'أنت تتحسن. استمر بالثبات.';
  @override
  String get startFocusMode => 'ابدأ وضع التركيز';
  @override
  String get activeSystem => 'نظام نشط';

  @override
  String get habitsAndIdentity => 'العادات والهوية';
  @override
  String get shapeWho => 'شكّل من تريد أن تصبح';
  @override
  String get yourIdentity => 'هويتك';
  @override
  String get identityQuote => '"أريد أن أصبح شخصاً مركزاً ومنضبطاً"';
  @override
  String get build => 'بناء';
  @override
  String get breakText => 'كسر';
  @override
  String get done => 'تم';
  @override
  String get avoided => 'تم التجنب';
  @override
  String get addHabit => 'إضافة عادة';
  @override
  String get suggestedBySystem => 'مقترح من نظامك';
  @override
  String get identitySystem => 'نظام الهوية';

  @override
  String get systemAI => 'ذكاء النظام';
  @override
  String get yourPersonalGuide => 'مرشدك الشخصي';
  @override
  String get aiActive => 'الذكاء نشط';
  @override
  String get askYourSystem => 'اسأل نظامك...';

  @override
  String get statistics => 'الإحصائيات';
  @override
  String get progressInsights => 'رؤى تقدمك';
  @override
  String get thisWeek => 'هذا الأسبوع';
  @override
  String get distracted => 'تشتت';
  @override
  String get complete => 'مكتمل';
  @override
  String get weeklyOverview => 'نظرة أسبوعية';
  @override
  String get mostUsedApps => 'أكثر التطبيقات استخداماً';
  @override
  String get habitProgress => 'تقدم العادات';
  @override
  String get aiInsight => 'رؤية الذكاء';
  @override
  String get analyticsActive => 'التحليلات نشطة';

  @override
  String get yourLevel => 'مستواك';
  @override
  String get growthInProgress => 'النمو قيد التقدم';
  @override
  String get experiencePoints => 'نقاط الخبرة';
  @override
  String get recentChanges => 'التغييرات الأخيرة';
  @override
  String get achievements => 'الإنجازات';
  @override
  String get levelSystem => 'نظام المستويات';

  @override
  String get settings => 'الإعدادات';
  @override
  String get customizeSystem => 'خصّص نظامك';
  @override
  String get systemSensitivity => 'حساسية النظام';
  @override
  String get escalationStrength => 'قوة التصعيد';
  @override
  String get notifications => 'الإشعارات';
  @override
  String get habitPriority => 'أولويات العادات';
  @override
  String get escalationSettings => 'إعدادات التصعيد';
  @override
  String get profileSettings => 'إعدادات الملف الشخصي';
  @override
  String get helpAndSupport => 'المساعدة والدعم';
  @override
  String get logout => 'تسجيل الخروج';
  @override
  String get settingsPanel => 'لوحة الإعدادات';
  @override
  String get language => 'اللغة';
  @override
  String get selectLanguage => 'اختر اللغة';
  @override
  String get languageChangeNote =>
      'تغيير اللغة سيحدث واجهة التطبيق بالكامل. جميع بياناتك ستبقى محفوظة.';
  @override
  String get appManagement => 'إدارة التطبيقات';
  @override
  String get usageLimits => 'حدود الاستخدام';
  @override
  String get usageDashboard => 'لوحة الاستخدام';

  @override
  String get focusModeActive => 'وضع التركيز نشط';
  @override
  String get stayFocused => 'ابقَ مركزاً. نظامك ';
  @override
  String get withYou => 'معك';
  @override
  String get endSession => 'إنهاء الجلسة';
  @override
  String get sessionComplete => 'اكتملت الجلسة';
  @override
  String get success => 'نجاح';

  @override
  String get focusModeActivated => 'تم تفعيل وضع التركيز';
  @override
  String get tooLong => 'طويل جداً';
  @override
  String get timeRemaining => 'الوقت المتبقي';
  @override
  String get resetAndRefocus => 'إعادة ضبط';
  @override
  String get refocus => 'إعادة التركيز';
  @override
  String get systemIntervention => 'تدخل النظام';
  @override
  String get accessRestricted => 'الوصول مقيد';
  @override
  String get systemAlert => 'تنبيه النظام';
  @override
  String get locked => 'مقفل';
  @override
  String get lockedFor => 'مقفل لمدة';
  @override
  String get enforcedRestriction => 'تقييد إجباري';

  @override
  String get strongWarning => 'تذكير';
  @override
  String get sustainedDistraction => 'تم اكتشاف تشتت مستمر.';
  @override
  String get continueWillEscalate =>
      'إذا استمررت، سيتصاعد النظام إلى حظر مؤقت.';
  @override
  String xpPenaltyLabel(String amount) => 'عقوبة XP: $amount نقطة';
  @override
  String get iUnderstand => 'فهمت';
  @override
  String get distractionDetected => 'تم اكتشاف تشتت';
  @override
  String get refocusToAvoid => 'أعد التركيز لتجنب التصعيد';
  @override
  String get behaviorLock => 'قفل سلوكي';
  @override
  String get limitedAccessActive => 'نافذة إعادة الدخول المحدودة نشطة';
  @override
  String get fullLockActive => 'الإغلاق الكامل نشط';
  @override
  String get lockExpiredResume => 'انتهى القفل — يمكنك المتابعة';

  @override
  String get trackingActive => 'التتبع نشط';
  @override
  String get trackingInactive => 'التتبع غير نشط';
  @override
  String get systemReady => 'النظام جاهز';
  @override
  String get systemNotReady => 'النظام غير جاهز';
  @override
  String get notificationsDisabled => 'الإشعارات معطلة';
  @override
  String get enableNotifications => 'تفعيل';
  @override
  String get warningsWontAppear => 'التحذيرات لن تظهر';

  @override
  String get analyzing => 'جاري التحليل';
  @override
  String get aiProcessing => 'معالجة الذكاء';

  @override
  String get home => 'الرئيسية';
  @override
  String get ai => 'الذكاء';
  @override
  String get stats => 'الإحصائيات';

  @override
  String get identityBuilder => 'بناء الهوية';
  @override
  String get whoDoYouWantToBe => 'من تريد أن تكون؟';
  @override
  String get selectIdentitiesHint => 'اختر ٢-٣ هويات لرحلتك';
  @override
  String get confirmIdentity => 'تأكيد الهوية';
  @override
  String get addCustomIdentity => 'هوية مخصصة';
  @override
  String get skillTrees => 'شجرة المهارات';
  @override
  String get addSkill => 'إضافة مهارة';
  @override
  String get noIdentitiesFound => 'لم يتم العثور على هويات';
  @override
  String get goBackToIdentityBuilder => 'عد إلى بناء الهوية لاختيار مسارك.';
  @override
  String get dungeons => 'التحديات';
  @override
  String get addQuest => 'إضافة مهمة';
  @override
  String get enterDungeon => 'دخول التحدي';
  @override
  String get defeated => 'تم الإنجاز';
  @override
  String get inProgress => 'قيد التقدم';
  @override
  String get available => 'متاح';

  @override
  String get weeklyReview => 'المراجعة الأسبوعية';
  @override
  String get focusTime => 'وقت التركيز';
  @override
  String get distractedTime => 'وقت التشتت';
  @override
  String get habitsCompleted => 'العادات المكتملة';

  @override
  String get cancel => 'إلغاء';
  @override
  String get save => 'حفظ';
  @override
  String get delete => 'حذف';
  @override
  String get edit => 'تعديل';
  @override
  String get confirm => 'تأكيد';
  @override
  String get ok => 'حسناً';
  @override
  String get selected => 'محدد';
  @override
  String get custom => 'مخصص';
  @override
  String get today => 'اليوم';
  @override
  String get yesterday => 'أمس';
  @override
  String get minutes => 'دقيقة';
  @override
  String get hours => 'ساعة';
}
