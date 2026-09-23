import 'package:shared_preferences/shared_preferences.dart';

/// Centralized UI strings for the Self Leveling system.
/// All strings are dynamically resolved based on the current locale.
/// User-generated content (habits, skills, etc.) is NOT translated.
class AppStrings {
  AppStrings._();

  static String _lang = 'en';

  /// Call once at startup and whenever locale changes.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _lang = prefs.getString('app_locale') ?? 'en';
  }

  /// Update the current language at runtime (called by locale_provider).
  static void setLang(String code) {
    _lang = code;
  }

  static bool get isArabic => _lang == 'ar';

  // ── App ──
  static String get appName => 'Self Leveling';
  static String get appVersion => 'v1.0.0';
  static String get appTagline => isArabic
      ? 'كن أقوى نسخة من نفسك'
      : 'Become the strongest version of yourself';
  static String get systemInterfaceActive =>
      isArabic ? 'واجهة النظام نشطة' : 'System Interface Active';

  // ── Auth ──
  static String get welcomeBack => isArabic ? 'مرحباً بعودتك' : 'Welcome Back';
  static String get continueJourney =>
      isArabic ? 'أكمل رحلة تطويرك' : 'Continue your leveling journey';
  static String get startJourney =>
      isArabic ? 'ابدأ رحلتك' : 'Start Your Journey';
  static String get createAccount => isArabic ? 'إنشاء حساب' : 'Create Account';
  static String get createYourAccount =>
      isArabic ? 'أنشئ حسابك' : 'Create Your Account';
  static String get startTransformation => isArabic
      ? 'ابدأ رحلة التحول الخاصة بك'
      : 'Start your transformation journey';
  static String get login => isArabic ? 'تسجيل الدخول' : 'Login';
  static String get email => isArabic ? 'البريد الإلكتروني' : 'Email';
  static String get password => isArabic ? 'كلمة المرور' : 'Password';
  static String get confirmPassword =>
      isArabic ? 'تأكيد كلمة المرور' : 'Confirm Password';
  static String get forgotPassword =>
      isArabic ? 'نسيت كلمة المرور؟' : 'Forgot Password?';
  static String get alreadyHaveAccount =>
      isArabic ? 'لديك حساب بالفعل؟ ' : 'Already have an account? ';
  static String get emailPlaceholder => 'your@email.com';
  static String get passwordPlaceholder => '••••••••';
  static String get systemLogin =>
      isArabic ? 'تسجيل دخول النظام' : 'SYSTEM LOGIN';
  static String get systemRegistration =>
      isArabic ? 'تسجيل النظام' : 'SYSTEM REGISTRATION';
  static String get back => isArabic ? 'تراجع' : 'Back';
  static String get or => isArabic ? 'أو' : 'or';
  static String get continueWithGoogle =>
      isArabic ? 'المتابعة عبر جوجل' : 'Continue with Google';
  static String get continueWithApple =>
      isArabic ? 'المتابعة عبر آبل' : 'Continue with Apple';
  static String get signUpMsg => isArabic ? 'سجل حسابك' : 'Sign Up';

  // ── Onboarding ──
  static String stepOf(int step, int total) =>
      isArabic ? 'خطوة $step من $total' : 'Step $step of $total';
  static String get typeYourAnswer =>
      isArabic ? 'اكتب إجابتك...' : 'Type your answer...';
  static String get next => isArabic ? 'التالي' : 'Next';
  static String get completeBtn => isArabic ? 'إكمال' : 'Complete';
  static String get biggestStruggle =>
      isArabic ? 'ما هو أكبر تحدي لك؟' : 'What is your biggest struggle?';
  static String get biggestStruggleSub => isArabic
      ? 'كن صريحاً... النظام يتطلب الحقيقة'
      : 'Be honest... the system needs truth';
  static String get habitToBuild => isArabic
      ? 'ما هي العادة التي تود بناءها؟'
      : 'What habit do you want to build?';
  static String get habitToBuildSub =>
      isArabic ? 'ابدأ بعادة واحدة' : 'Start with one habit';
  static String get hoursWasted => isArabic
      ? 'كم ساعة تضيعها يومياً؟'
      : 'How many hours do you waste daily?';
  static String get hoursWastedSub => isArabic
      ? 'تحدث بصدق عن أوقات التشتت'
      : 'Be honest about distraction time';
  static String get desiredIdentity =>
      isArabic ? 'ما هي الهوية التي تريدها؟' : 'What identity do you want?';
  static String get desiredIdentitySub =>
      isArabic ? 'من تريد أن تصبح؟' : 'Who do you want to become?';

  // ── Setup / Permissions ──
  static String get usageAnalytics =>
      isArabic ? 'تحليلات الاستخدام' : 'Usage Analytics';
  static String get permissionGranted =>
      isArabic ? 'مُنحت الصلاحية ✓' : 'Permission granted ✓';
  static String get usagePermissionDesc => isArabic
      ? 'مطلوب لمراقبة التطبيقات المشتتة وتتبع تطورك.'
      : 'Needed to monitor which apps are distracting you and track improvement.';
  static String get whyIsThisNeeded =>
      isArabic ? 'لماذا هذا مطلوب؟' : 'Why is this needed?';
  static String get usagePermissionReason => isArabic
      ? 'يحتاج النظام لصلاحية الاستخدام لحساب مستوى التحكم وبدء التدخلات الضرورية عند شرودك.'
      : 'The system requires usage access to calculate your control level and trigger necessary interventions when you stray.';
  static String get openSettings =>
      isArabic ? 'فتح الإعدادات' : 'Open Settings';
  static String get iveGrantedPermission =>
      isArabic ? 'لقد منحت الصلاحية' : 'I\'ve granted permission';
  static String get continueBtn => isArabic ? 'متابعة' : 'Continue';
  static String get skipForNow => isArabic ? 'تخطي حالياً' : 'Skip for now';
  static String get skipOptional =>
      isArabic ? 'تخطي (اختياري)' : 'Skip (optional)';
  static String get displayOverlay =>
      isArabic ? 'عرض فوق التطبيقات' : 'Display Overlay';
  static String get overlayPermissionDesc => isArabic
      ? 'يسمح للنظام بعرض قفل التركيز عند تفعيل نظام التصعيد.'
      : 'Allows the system to show focus lock screens when escalation is triggered.';
  static String get overlayPermissionReason => isArabic
      ? 'حينما تصل التشتتات لمستوى عالي (S3+)، يعرض النظام شاشة حجب. هذا اختياري ولكنه موصى به.'
      : 'When distraction levels are critical (S3+), the system will display a blocking overlay. This is optional but recommended for full intervention.';
  static String get liveDetectionPermission =>
      isArabic ? 'الكشف المباشر' : 'Live Detection';
  static String get accessibilityPermissionDesc => isArabic
      ? 'يساعد النظام على معرفة التطبيق الأمامي فورًا لتسريع إظهار وإخفاء طبقة الحجب.'
      : 'Helps the system detect the foreground app instantly so blocking overlays can appear and disappear faster.';
  static String get accessibilityPermissionReason => isArabic
      ? 'هذه الصلاحية تُستخدم فقط لاكتشاف تغيّر التطبيق الأمامي أو النافذة الحالية بسرعة. لا تُستخدم لقراءة محتوى الشاشة أو تحليل النصوص.'
      : 'This permission is used only for fast foreground-window detection. It is not used to read screen content or scrape text.';
  static String get liveDetectionRecommended => isArabic
      ? 'تفعيل الكشف المباشر موصى به'
      : 'Live detection is recommended';
  static String get enableLiveDetection =>
      isArabic ? 'تفعيل الكشف المباشر' : 'Enable Live Detection';
  static String get recommendedLabel => isArabic ? 'موصى به' : 'Recommended';

  static String get permissionRequired =>
      isArabic ? 'الصلاحيات الإلزامية' : 'Permission Required';
  static String get systemNeedsAccess => isArabic
      ? 'يحتاج النظام لصلاحيات لمراقبة السلوك.'
      : 'The system needs access to monitor your behavior';
  static String get usageAccess =>
      isArabic ? 'صلاحية الاستخدام' : 'Usage Access';
  static String get monitorAppUsage => isArabic
      ? 'مراقبة أنماط استخدام التطبيقات'
      : 'Monitor app usage patterns';
  static String get displaySystemInterventions =>
      isArabic ? 'عرض تدخلات النظام' : 'Display system interventions';
  static String get notificationAccess =>
      isArabic ? 'صلاحية الإشعارات' : 'Notification Access';
  static String get sendBehavioralAlerts =>
      isArabic ? 'إرسال تنبيهات السلوك' : 'Send behavioral alerts';
  static String get grantPermissions =>
      isArabic ? 'منح الصلاحيات' : 'Grant Permissions';
  static String get systemAccess => isArabic ? 'وصول النظام' : 'SYSTEM ACCESS';

  // ── Dashboard ──
  static String get systemStatus => isArabic ? 'حالة النظام' : 'System Status';
  static String get selfControlLevel =>
      isArabic ? 'مستوى التحكم الذاتي' : 'SELF CONTROL LEVEL';
  static String get control => isArabic ? 'التحكم' : 'Control';
  static String get level => isArabic ? 'المستوى' : 'LEVEL';
  static String get focus => isArabic ? 'التركيز' : 'Focus';
  static String get distraction => isArabic ? 'التشتت' : 'Distraction';
  static String get habits => isArabic ? 'العادات' : 'Habits';
  static String get systemMessage =>
      isArabic ? 'رسالة النظام' : 'SYSTEM MESSAGE';
  static String get improving => isArabic
      ? 'أنت تتحسن. استمر بالثبات.'
      : 'You are improving. Stay consistent.';
  static String get startFocusMode =>
      isArabic ? 'ابدأ وضع التركيز' : 'Start Focus Mode';
  static String get weaknesses => isArabic ? 'نقاط الضعف:' : 'Weaknesses:';
  static String get duration => isArabic ? 'المدة:' : 'Duration:';
  static String get activeSystem => isArabic ? 'نظام نشط' : 'ACTIVE SYSTEM';

  // ── Profile ──
  static String get profileSaved =>
      isArabic ? 'تم حفظ الملف الشخصي بنجاح ✓' : 'Profile saved successfully ✓';
  static String get displayName => isArabic ? 'الاسم المعروض' : 'Display Name';
  static String get enterYourName => isArabic ? 'أدخل اسمك' : 'Enter your name';
  static String get identityStatement =>
      isArabic ? 'بيان الهوية' : 'Identity Statement';
  static String get iWantToBecome =>
      isArabic ? 'أريد أن أصبح...' : 'I want to become...';
  static String get saveChanges => isArabic ? 'حفظ التغييرات' : 'Save Changes';
  static String get totalXP => isArabic ? 'إجمالي نقاط الخبرة' : 'Total XP';
  static String get currentXP =>
      isArabic ? 'نقاط الخبرة الحالية' : 'Current XP';
  static String get activeHabits =>
      isArabic ? 'العادات النشطة' : 'Active Habits';
  static String get selfControl => isArabic ? 'التحكم الذاتي' : 'Self-Control';
  static String get profileSystem =>
      isArabic ? 'نظام الملف الشخصي' : 'PROFILE SYSTEM';

  static String get toLevel => isArabic ? 'للوصول للمستوى' : 'to Level';
  static String get keepLevelingUp =>
      isArabic ? 'استمر في التطور' : 'Keep leveling up';
  static String get everySmallStep => isArabic
      ? 'كل خطوة تسهم في تطويرك'
      : 'Every small step counts toward your evolution';

  static String get habit => isArabic ? 'عادة' : 'Habit';
  static String get addSkill => isArabic ? 'إضافة مهارة' : 'Add Skill';
  static String get addCustomSkillTo =>
      isArabic ? 'إضافة مهارة مخصصة إلى' : 'Add Custom Skill to';
  static String get skillName => isArabic ? 'اسم المهارة' : 'Skill Name';
  static String get customSkill => isArabic ? 'مهارة مخصصة' : 'Custom Skill';
  static String get requiresUnknown =>
      isArabic ? 'يتطلب: ؟؟؟' : 'Requires: ???';
  static String levelProgress(int lvl, int maxLvl) =>
      isArabic ? 'مستوى $lvl/$maxLvl' : 'Lv.$lvl/$maxLvl';
  static String levelText(int lvl) => isArabic ? 'مستوى $lvl' : 'Level $lvl';
  static String get noIdentitiesFound =>
      isArabic ? 'لم يتم العثور على هويات' : 'No Identities Found';
  static String get goBackToIdentityBuilder => isArabic
      ? 'عد إلى بناء الهوية لاختيار مسارك.'
      : 'Go back to Identity Builder to pick your path.';
  static String get dungeons => isArabic ? 'التحديات' : 'Dungeons';
  static String get addQuest => isArabic ? 'إضافة مهمة' : 'Add Quest';
  static String get addCustomDungeonQuest =>
      isArabic ? 'إضافة تحدي مخصص' : 'Add Custom Dungeon Quest';
  static String get enterDungeon => isArabic ? 'دخول التحدي' : 'Enter Dungeon';
  static String get defeated => isArabic ? 'تم الإنجاز' : 'DEFEATED';
  static String get inProgress => isArabic ? 'قيد التقدم' : 'IN PROGRESS';
  static String get available => isArabic ? 'متاح' : 'AVAILABLE';
  static String get questName => isArabic ? 'اسم المهمة' : 'Quest Name';
  static String get bossQuestName =>
      isArabic ? 'اسم الزعيم/المهمة' : 'Boss/Quest Name';
  static String get description => isArabic ? 'الوصف' : 'Description';

  // ── Habits & Identity ──
  static String get identityBuilder =>
      isArabic ? 'بناء الهوية' : 'Identity Builder';
  static String get identityName => isArabic ? 'اسم الهوية' : 'Identity Name';
  static String get subtitle => isArabic ? 'الوصف الفرعي' : 'Subtitle';
  static String get whoDoYouWantToBe =>
      isArabic ? 'من تريد أن تكون؟' : 'Who do you want to be?';
  static String get selectIdentitiesHint => isArabic
      ? 'اختر ٢-٣ هويات لرحلتك'
      : 'Select 2-3 identities for your journey';
  static String get addCustomIdentity =>
      isArabic ? 'هوية مخصصة' : 'Add Custom Identity';
  static String get skillTrees => isArabic ? 'شجرة المهارات' : 'Skill Trees';

  static String selectedCount(int curr, int max) =>
      isArabic ? 'تم تحديد $curr/$max' : '$curr/$max selected';
  static String get confirmIdentity =>
      isArabic ? 'تأكيد الهوية' : 'Confirm Identity';
  static String get customIdentity =>
      isArabic ? 'هوية مخصصة' : 'Custom Identity';
  static String get selectedLabel => isArabic ? 'محدد' : 'Selected';

  static String get baseIdDeveloperSub =>
      isArabic ? 'أنا شخص يبني مشاريع' : 'I build projects';
  static String get baseIdDisciplinedName => isArabic ? 'منضبط' : 'Disciplined';
  static String get baseIdDisciplinedSub =>
      isArabic ? 'أنا شخص منضبط ومنتج' : 'I am disciplined and productive';
  static String get baseIdSpiritualName => isArabic ? 'روحاني' : 'Spiritual';
  static String get baseIdSpiritualSub =>
      isArabic ? 'أنا شخص ملتزم روحانياً' : 'I am spiritually committed';
  static String get baseIdCreatorName => isArabic ? 'مبدع' : 'Creator';
  static String get baseIdCreatorSub =>
      isArabic ? 'أنا شخص مبدع ومبتكر' : 'I am creative and innovative';
  // Skills mapping
  static List<String> get baseIdReaderSkills => isArabic
      ? ['القراءة السريعة', 'تدوين الملاحظات', 'التلخيص']
      : ['Speed Reading', 'Note Taking', 'Summarizing'];
  static List<String> get baseIdAthleteSkills => isArabic
      ? ['الإطالة', 'وزن الجسم', 'التمارين المتقطعة']
      : ['Stretching', 'Bodyweight', 'HIIT'];
  static List<String> get baseIdDeveloperSkills => isArabic
      ? ['جلسات التركيز', 'حل المشكلات', 'مراجعة الكود']
      : ['Focus Sessions', 'Problem Solving', 'Code Review'];
  static List<String> get baseIdDisciplinedSkills => isArabic
      ? ['التحكم الذاتي', 'إدارة الوقت', 'العمل العميق']
      : ['Self Control', 'Time Management', 'Deep Work'];
  static List<String> get baseIdSpiritualSkills => isArabic
      ? ['الروتين الصباحي', 'التأمل', 'الامتنان']
      : ['Morning Routine', 'Mindfulness', 'Gratitude'];
  static List<String> get baseIdCreatorSkills => isArabic
      ? ['توليد الأفكار', 'التنفيذ', 'المشاركة']
      : ['Ideation', 'Execution', 'Sharing'];

  // Base Identities
  static String get baseIdReaderName => isArabic ? 'قارئ' : 'Reader';
  static String get baseIdReaderSub =>
      isArabic ? 'أنا شخص يقرأ يومياً' : 'I read daily';
  static String get baseIdAthleteName => isArabic ? 'رياضي' : 'Athlete';
  static String get baseIdAthleteSub =>
      isArabic ? 'أنا شخص يمارس الرياضة' : 'I exercise regularly';
  static String get baseIdDeveloperName => isArabic ? 'مطور' : 'Developer';

  static String get habitsAndIdentity =>
      isArabic ? 'العادات والهوية' : 'Habits & Identity';
  static String get shapeWho =>
      isArabic ? 'شكّل من تريد أن تصبح' : 'Shape who you want to become';
  static String get yourIdentity => isArabic ? 'هويتك' : 'YOUR IDENTITY';
  static String get identityQuote => isArabic
      ? '"أريد أن أصبح شخصاً مركزاً ومنضبطاً"'
      : '"I want to become a focused and disciplined person"';
  static String get build => isArabic ? 'بناء' : 'BUILD';
  static String get breakText => isArabic ? 'كسر' : 'BREAK';
  static String get done => isArabic ? 'تم' : 'Done';
  static String get avoided => isArabic ? 'تم التجنب' : 'Avoided';
  static String get addHabit => isArabic ? 'إضافة عادة' : 'Add Habit';
  static String get suggestedBySystem =>
      isArabic ? 'مقترح من نظامك' : 'SUGGESTED BY YOUR SYSTEM';
  static String get identitySystem =>
      isArabic ? 'نظام الهوية' : 'IDENTITY SYSTEM';

  // ── AI ──
  static String get systemAI => isArabic ? 'ذكاء النظام' : 'System AI';
  static String get yourPersonalGuide =>
      isArabic ? 'مرشدك الشخصي' : 'Your personal guide';
  static String get aiActive => isArabic ? 'الذكاء نشط' : 'AI ACTIVE';
  static String get askYourSystem =>
      isArabic ? 'اسأل نظامك...' : 'Ask your system...';

  // ── Stats ──
  static String get weeklyReview =>
      isArabic ? 'المراجعة الأسبوعية' : 'Weekly Review';
  static String get dailyBreakdown =>
      isArabic ? 'التفصيل اليومي' : 'Daily Breakdown';
  static String get achievementsThisWeek =>
      isArabic ? 'إنجازات هذا الأسبوع' : 'Achievements This Week';
  static String get aiInsights =>
      isArabic ? 'رؤى الذكاء الاصطناعي' : 'AI Insights';
  static String get systemAnalysis =>
      isArabic ? 'تحليل النظام' : 'System Analysis';
  static String get nextWeekPlan =>
      isArabic ? 'خطة الأسبوع القادم' : 'Next Week Plan';

  static String weekNum(int n) => isArabic ? 'الأسبوع $n' : 'Week $n';
  static String get focusTime => isArabic ? 'وقت التركيز' : 'Focus Time';
  static String get weekly => isArabic ? 'أسبوعياً' : 'Weekly';
  static String get growing => isArabic ? 'ينمو' : 'Growing';
  static String get habitsDone => isArabic ? 'العادات المنجزة' : 'Habits Done';
  static String get xpEarned => isArabic ? 'الخبرة المكتسبة' : 'XP Earned';
  static String get adoptThisPlan =>
      isArabic ? 'اعتماد هذه الخطة' : 'Adopt This Plan';

  static String get focusToday => isArabic ? 'تركيز اليوم' : 'Focus today';
  static String get systemOverview =>
      isArabic ? 'نظرة عامة على النظام' : 'System Overview';
  static String get totalXpEarned =>
      isArabic ? 'إجمالي الخبرة' : 'Total XP Earned';
  static String get currentXp => isArabic ? 'الخبرة الحالية' : 'Current XP';
  static String get distractionScore =>
      isArabic ? 'مستوى التشتت' : 'Distraction Score';
  static String get escalationToday =>
      isArabic ? 'تصعيدات اليوم' : 'Escalation Today';
  static String get focusSessions =>
      isArabic ? 'جلسات التركيز' : 'Focus Sessions';
  static String get noHabitsYetAdd => isArabic
      ? 'لا توجد عادات بعد. أضف عادات لرؤية التقدم.'
      : 'No habits yet. Add habits to see progress.';
  static String get pending => isArabic ? 'قيد الانتظار' : 'Pending';

  static String get insightAllDone => isArabic
      ? 'تم إنجاز كل العادات! انضباطك ممتاز.'
      : 'All habits completed today! Your discipline is outstanding.';
  static String get insightHighDistraction => isArabic
      ? 'مستويات تشتت عالية. قلل استخدامك للهاتف.'
      : 'High distraction levels detected. Consider limiting phone usage.';
  static String get insightLowControl => isArabic
      ? 'تحكمك ضعيف. جرب جلسة تركيز لاستعادة قوتك.'
      : 'Self-control is low. Try a focus session to regain momentum.';
  static String get insightUncompleted => isArabic
      ? 'لا تزال هناك عادات لم تنجزها. استمر!'
      : 'You still have uncompleted habits today. Push through!';
  static String get insightProgress => isArabic
      ? 'أنت تتقدم جيداً. حافظ على استمراريتك.'
      : 'You are making progress. Keep building consistency.';

  // Dungeon Specifics
  static String dungeonsDefeatedCount(int count) =>
      isArabic ? 'تم هزيمة $count' : '$count Defeated';
  static String dayProgress(int num, int total) =>
      isArabic ? 'اليوم $num/$total' : 'Day $num/$total';
  static String dailyLimitLabel(int min) =>
      isArabic ? '$min دقيقة/يوم' : '${min}m/day';
  static String enterDungeonReward(int xp) =>
      isArabic ? 'دخول الزنزانة (+$xp خبرة)' : 'Enter Dungeon (+$xp XP)';
  static String defeatedReward(int xp) =>
      isArabic ? 'مهزوم! كسبت +$xp خبرة' : 'Defeated! +$xp XP earned';
  static String get statusInProgress => isArabic ? 'قيد التقدم' : 'IN PROGRESS';
  static String get statusAvailable => isArabic ? 'متاح' : 'AVAILABLE';
  static String get statusDefeated => isArabic ? 'مهزوم' : 'DEFEATED';

  // Base Dungeons
  static String get baseDungeon1Name =>
      isArabic ? 'التمرير اللانهائي' : 'Infinite Scroll';
  static String get baseDungeon1Boss =>
      isArabic ? 'مزاحم الوقت' : 'The Doom Scroller';
  static String get baseDungeon1Desc => isArabic
      ? 'تجنب التمرير اللانهائي في السوشال ميديا'
      : 'Avoid infinite scrolling on social media';
  static List<String> get baseDungeon1Weak => isArabic
      ? ['مثيرات الصباح', 'قبل النوم', 'الملل']
      : ['Morning trigger', 'Before sleep', 'Boredom'];

  static String get baseDungeon2Name =>
      isArabic ? 'التسويف' : 'Procrastination';
  static String get baseDungeon2Boss => isArabic ? 'المؤجل' : 'The Delayer';
  static String get baseDungeon2Desc =>
      isArabic ? 'ابدأ فوراً بدون تأجيل' : 'Start immediately without delay';
  static List<String> get baseDungeon2Weak => isArabic
      ? ['المهام الكبيرة', 'غياب الخطة', 'الخوف من الفشل']
      : ['Big tasks', 'Lack of plan', 'Fear of failure'];

  static String get baseDungeon3Name =>
      isArabic ? 'هاتف آخر الليل' : 'Late Night Phone';
  static String get baseDungeon3Boss =>
      isArabic ? 'سارق الليل' : 'The Night Thief';
  static String get baseDungeon3Desc =>
      isArabic ? 'لا هاتف بعد 10 مساءً' : 'No phone after 10 PM';
  static List<String> get baseDungeon3Weak => isArabic
      ? ['الخوف من التفويت', 'الإشعارات', 'لا يوجد روتين']
      : ['FOMO', 'Notifications', 'No routine'];

  // Add Habit Specifics
  static String get habitNameHint =>
      isArabic ? 'مثال: التأمل الصباحي' : 'e.g. Morning Meditation';
  static String get habitTypeLabel => isArabic ? 'نوع العادة' : 'Habit Type';
  static String get buildHabitLabel => isArabic ? 'بناء' : 'Build';
  static String get buildHabitSub =>
      isArabic ? 'عادة إيجابية' : 'Positive habit';
  static String get breakHabitLabel => isArabic ? 'تخلص من' : 'Break';
  static String get breakHabitSub => isArabic ? 'عادة سلبية' : 'Negative habit';
  static String get frequencyLabel => isArabic ? 'التكرار' : 'Frequency';
  static String get freqDaily => isArabic ? 'يومياً' : 'Daily';
  static String get freqWeekly => isArabic ? 'أسبوعياً' : 'Weekly';
  static String get reminderTimeOpt =>
      isArabic ? 'وقت التذكير (اختياري)' : 'Reminder Time (Optional)';
  static String get tapToSetTime =>
      isArabic ? 'انقر لتعيين الوقت' : 'Tap to set time';
  static String get saveHabitBtn => isArabic ? 'حفظ العادة' : 'Save Habit';

  // Habit Details Specifics
  static String get habitNotFound =>
      isArabic ? 'العادة غير موجودة' : 'Habit not found';
  static String get goBack => isArabic ? 'تراجع' : 'Go Back';
  static String get habitDetails =>
      isArabic ? 'تفاصيل العادة' : 'Habit Details';
  static String get buildHabitText => isArabic ? 'بناء' : 'Build';
  static String get breakHabitText => isArabic ? 'تخلص من' : 'Break';
  static String get habitWord => isArabic ? 'عادة' : 'habit';
  static String get streakLabel => isArabic ? 'سلسلة' : 'Streak';
  static String get bestLabel => isArabic ? 'الأفضل' : 'Best';
  static String get totalLabel => isArabic ? 'الإجمالي' : 'Total';
  static String get xpPerDayLabel => isArabic ? 'خبرة/يوم' : 'XP/Day';
  static String get thisWeekLabel => isArabic ? 'هذا الأسبوع' : 'This Week';
  static String get reminderLabel => isArabic ? 'تذكير' : 'Reminder';
  static String get noReminderSet =>
      isArabic ? 'لم يتم تعيين تذكير' : 'No reminder set';
  static String get editLabel => isArabic ? 'تعديل' : 'Edit';
  static String get deleteLabel => isArabic ? 'حذف' : 'Delete';
  static String get habitTrackingLabel =>
      isArabic ? 'تتبع العادات' : 'HABIT TRACKING';
  static String get editHabitTitle => isArabic ? 'تعديل العادة' : 'Edit Habit';
  static String get habitNameLabel => isArabic ? 'اسم العادة' : 'Habit Name';
  static String get xpRewardLabel => isArabic ? 'مكافأة الخبرة' : 'XP Reward';
  static String get saveLabel => isArabic ? 'حفظ' : 'Save';
  static String deleteConfirmTitle(String name) =>
      isArabic ? 'حذف "$name"؟' : 'Delete "$name"?';
  static String get deleteConfirmDesc => isArabic
      ? 'لا يمكن التراجع عن هذا الإجراء.'
      : 'This action cannot be undone.';
  static List<String> get weekDayInitials => isArabic
      ? ['إ', 'ث', 'أ', 'خ', 'ج', 'س', 'أ']
      : ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  // Habits Specifics
  static String get noBuildHabits => isArabic
      ? 'لا توجد عادات بناء. أضف واحدة للبدء!'
      : 'No build habits yet. Add one to start!';
  static String get noBreakHabits => isArabic
      ? 'لا توجد عادات للتخلص منها. حدد ما يجب تجنبه!'
      : 'No break habits yet. Identify what to avoid!';
  static String get startByAddingHabit => isArabic
      ? 'ابدأ بإضافة أول عادة لتبدأ رحلتلك'
      : 'Start by adding your first habit to begin your journey';
  static String get allHabitsCompleted => isArabic
      ? 'تم إنجاز كل العادات اليوم! انضباط عظيم.'
      : 'All habits completed today! Great discipline.';
  static String completeRemainingHabits(int count) => isArabic
      ? 'أكمل $count عادات متبقية لكسب الخبرة'
      : 'Complete your remaining $count habits to earn XP';
  static String dayStreak(int days) =>
      isArabic ? 'سلسلة أيام $days' : '$days day streak';
  static String habitCompletedFeedback({
    required String habitName,
    required bool isBreak,
    required int xpEarned,
  }) =>
      isArabic
          ? isBreak
              ? 'أحسنت. قاومت "$habitName" بنجاح. +$xpEarned خبرة'
              : 'أحسنت. أكملت "$habitName". +$xpEarned خبرة'
          : isBreak
              ? 'Well done. You resisted "$habitName". +$xpEarned XP'
              : 'Well done. You completed "$habitName". +$xpEarned XP';
  static String get completeHabitReminderVerb => isArabic ? 'أنجز' : 'complete';
  static String get resistHabitReminderVerb => isArabic ? 'قاوم' : 'resist';
  static String get habitCompleted => isArabic ? 'تم إنجاز العادة!' : 'Habit Completed!';
  static String get habitBroken => isArabic ? 'تم مقاومة العادة!' : 'Habit Resisted!';

  // Focus & Session Complete
  static String get sessionCompleteTitle =>
      isArabic ? 'اكتملت الجلسة' : 'SESSION COMPLETE';
  static String get sessionInterruptedTitle =>
      isArabic ? 'تم إيقاف الجلسة' : 'SESSION INTERRUPTED';
  static String get stayFocusedSystem =>
      isArabic ? 'ابقَ مركزاً. نظامك ' : 'Stay focused. Your system is ';
  static String get wellDoneEarned =>
      isArabic ? 'أحسنت! كسبت ' : 'Well done! You earned ';
  static String get sessionInterruptedBody => isArabic
      ? 'تمت مقاطعة الجلسة. لم يتم منح '
      : 'The session ended early. No ';
  static String get noRewardGranted => isArabic ? 'مكافأة' : 'reward granted';
  static String get returnToDashboard =>
      isArabic ? 'العودة للرئيسية' : 'Return to Dashboard';
  static String get viewCompletionSummary =>
      isArabic ? 'عرض ملخص الإكمال' : 'View Completion Summary';
  static String get sessionSummaryUnavailable => isArabic
      ? 'لا يوجد ملخص جلسة مكتملة'
      : 'No completed session summary available';
  static String get sessionSummaryUnavailableBody => isArabic
      ? 'أكمل جلسة تركيز أولاً حتى يظهر ملخص حقيقي ومكافآت صحيحة.'
      : 'Complete a focus session first to unlock a real summary and rewards.';
  static String get focusTimeLabel => isArabic ? 'وقت التركيز' : 'Focus Time';
  static String get completedLabel => isArabic ? 'مكتمل' : 'Completed';
  static String get xpGainedLabel => isArabic ? 'الخبرة المكتسبة' : 'XP Gained';
  static String get experienceLabel => isArabic ? 'خبرة' : 'Experience';
  static String get greatJobYoure =>
      isArabic ? 'عمل رائع. أنت ' : 'Great job. You\'re ';
  static String get improvingLabel => isArabic ? 'تتحسن' : 'improving';
  static String get todaysProgress =>
      isArabic ? 'تقدم اليوم' : 'Today\'s Progress';
  static String get plusOneSession => isArabic ? '+1 جلسة' : '+1 Session';

  // Dashboard Overrides & Specifics
  static String get focusedStatus => isArabic ? 'مركز' : 'Focused';
  static String get monitoringStatus => isArabic ? 'مراقبة' : 'Monitoring';
  static String get xpLabel => isArabic ? 'خبرة' : 'XP';
  static String get identityLabel => isArabic ? 'الهوية' : 'Identity';
  static String get skillsLabel => isArabic ? 'المهارات' : 'Skills';
  static String get dungeonsLabel => isArabic ? 'الزنازين' : 'Dungeons';
  static String get reviewLabel => isArabic ? 'المراجعة' : 'Review';

  static String get msgExcellent => isArabic
      ? 'أداء ممتاز. أنت في كامل التحكم.'
      : 'Excellent performance. You are in control.';
  static String get msgImproving => isArabic
      ? 'أنت تتحسن. حافظ على الاستمرارية.'
      : 'You are improving. Stay consistent.';
  static String get msgHighDistract => isArabic
      ? 'تم اكتشاف تشتت عالي. ابدأ جلسة تركيز.'
      : 'High distraction detected. Start a focus session.';
  static String get msgRoomImprove => isArabic
      ? 'توجد مساحة للتحسن. ابنِ عاداتك.'
      : 'Room for improvement. Build your habits.';
  static String get msgNeedsAttention => isArabic
      ? 'نظامك يحتاج إلى انتباه. ركز على أهدافك.'
      : 'Your system needs attention. Focus on your goals.';

  // Usage Dashboard
  static String get usageDashboard =>
      isArabic ? 'لوحة الاستخدام' : 'Usage Dashboard';
  static String get usageAccessError => isArabic
      ? 'صلاحية الاستخدام مطلوبة. الرجاء تفعيلها من الإعدادات.'
      : 'Usage access required. Please enable it in Settings.';
  static String get todayLabel => isArabic ? 'اليوم' : 'Today';
  static String get weekLabel => isArabic ? 'أسبوع' : 'Week';
  static String get monthLabel => isArabic ? 'شهر' : 'Month';
  static String get totalTime => isArabic ? 'الوقت الإجمالي' : 'Total Time';
  static String get appsUsed => isArabic ? 'التطبيقات' : 'Apps Used';
  static String get topApp => isArabic ? 'التطبيق الأعلى' : 'Top App';
  static String get usageDistribution =>
      isArabic ? 'توزيع الاستخدام' : 'Usage Distribution';
  static String get allApps => isArabic ? 'كل التطبيقات' : 'All Apps';
  static String get timeSort => isArabic ? 'الوقت' : 'Time';
  static String get nameSort => isArabic ? 'الاسم' : 'Name';
  static String get noUsageData => isArabic
      ? 'لا توجد بيانات استخدام لهذه الفترة'
      : 'No usage data for this period';
  static String get opensLabel => isArabic ? 'فتح' : 'opens';
  static String get usageAccessRequired =>
      isArabic ? 'صلاحية الاستخدام مطلوبة' : 'Usage Access Required';
  static String get retryBtn => isArabic ? 'إعادة المحاولة' : 'Retry';

  // Base Stats Mocks
  static String get mockInsight1 => isArabic
      ? 'عادة القراءة استقرت — الروتين الصباحي يعمل جيداً'
      : 'Reading habit stabilized — morning routine working well';
  static String get mockInsight2 => isArabic
      ? 'انخفض استخدام الهاتف ليلاً بنسبة ٤٠٪ — استمر'
      : 'Night phone usage decreased by 40% — keep it up';
  static String get mockInsight3 => isArabic
      ? 'اقتراح: اجعل التمارين قبل المغرب لاستمرارية أفضل'
      : 'Suggestion: Move exercise to before Maghrib for better consistency';
  static String get mockPlan1 => isArabic
      ? 'زيادة القراءة لـ ١٠ دقائق يومياً'
      : 'Increase reading to 10 min/day';
  static String get mockPlan2 => isArabic
      ? 'ابدأ مهارة وزن الجسم (شجرة الرياضي)'
      : 'Start Bodyweight skill (Athlete tree)';
  static String get mockPlan3 => isArabic
      ? 'اهزم رئيس "التصفح اللانهائي"'
      : 'Defeat "Infinite Scroll" boss';
  static String get mockPlan4 => isArabic
      ? 'حافظ على سلسلة الروتين الصباحي'
      : 'Maintain morning routine streak';
  static String get mockBadge1 => isArabic ? 'سلسلة ٥ أيام' : '5-Day Streak';
  static String get mockBadge2 => isArabic ? 'قارئ مستوى ٣' : 'Reader Lv.3';

  static String get statistics => isArabic ? 'الإحصائيات' : 'Statistics';
  static String get progressInsights =>
      isArabic ? 'رؤى تقدمك' : 'Your progress insights';
  static String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  static String get save => isArabic ? 'حفظ' : 'Save';
  static String get thisWeek => isArabic ? 'هذا الأسبوع' : 'This Week';
  static String get distracted => isArabic ? 'تشتت' : 'Distracted';
  static String get complete => isArabic ? 'مكتمل' : 'Complete';
  static String get weeklyOverview =>
      isArabic ? 'نظرة أسبوعية' : 'Weekly Overview';
  static String get mostUsedApps =>
      isArabic ? 'أكثر التطبيقات استخداماً' : 'Most Used Apps';
  static String get habitProgress =>
      isArabic ? 'تقدم العادات' : 'Habit Progress';
  static String get aiInsight => isArabic ? 'رؤية الذكاء' : 'AI INSIGHT';
  static String get analyticsActive =>
      isArabic ? 'التحليلات نشطة' : 'ANALYTICS ACTIVE';

  // ── Level ──
  static String get yourLevel => isArabic ? 'مستواك' : 'Your Level';
  static String get growthInProgress =>
      isArabic ? 'النمو قيد التقدم' : 'Growth in progress';
  static String get experiencePoints =>
      isArabic ? 'نقاط الخبرة' : 'Experience Points';
  static String get recentChanges =>
      isArabic ? 'التغييرات الأخيرة' : 'Recent Changes';
  static String get achievements => isArabic ? 'الإنجازات' : 'Achievements';
  static String get levelSystem => isArabic ? 'نظام المستويات' : 'LEVEL SYSTEM';

  static String get achTitle1 =>
      isArabic ? 'أول جلسة تركيز' : 'First Focus Session';
  static String get achDesc1 =>
      isArabic ? 'أكمل أول جلسة تركيز لك' : 'Complete your first focus session';
  static String get achTitle2 => isArabic ? 'سلسلة 3 أيام' : '3 Days Streak';
  static String get achDesc2 =>
      isArabic ? 'حافظ على العادات لمدة 3 أيام' : 'Maintain habits for 3 days';
  static String get achTitle3 =>
      isArabic ? 'تعزيز التحكم الذاتي' : 'Self Control Boost';
  static String get achDesc3 =>
      isArabic ? 'صل إلى 70% من التحكم الذاتي' : 'Reach 70% self-control';
  static String get achTitle4 =>
      isArabic ? 'منجز المستوى 5' : 'Level 5 Achiever';
  static String get achDesc4 => isArabic ? 'الوصول للمستوى 5' : 'Reach level 5';
  static String get achTitle5 => isArabic ? 'سلسلة 7 أيام' : '7 Days Streak';
  static String get achDesc5 =>
      isArabic ? 'حافظ على العادات لمدة 7 أيام' : 'Maintain habits for 7 days';
  static String get achTitle6 => isArabic ? 'سيد التركيز' : 'Focus Master';
  static String get achDesc6 =>
      isArabic ? 'أكمل 20 جلسة تركيز' : 'Complete 20 focus sessions';

  // ── Settings ──
  static String get settings => isArabic ? 'الإعدادات' : 'Settings';
  static String get customizeSystem =>
      isArabic ? 'خصّص نظامك' : 'Customize your system';
  static String get systemSensitivity =>
      isArabic ? 'حساسية النظام' : 'System Sensitivity';
  static String get escalationStrength =>
      isArabic ? 'قوة التصعيد' : 'Escalation Strength';
  static String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  static String get habitPriority =>
      isArabic ? 'أولويات العادات' : 'Habit Priority';
  static String get escalationSettings =>
      isArabic ? 'إعدادات التصعيد' : 'Escalation Settings';
  static String get profileSettings =>
      isArabic ? 'إعدادات الملف الشخصي' : 'Profile Settings';
  static String get helpAndSupport =>
      isArabic ? 'المساعدة والدعم' : 'Help & Support';
  static String get logout => isArabic ? 'تسجيل الخروج' : 'Logout';
  static String get settingsPanel =>
      isArabic ? 'لوحة الإعدادات' : 'SETTINGS PANEL';
  static String get language => isArabic ? 'اللغة' : 'Language';

  static String get howQuicklySystemDetects => isArabic
      ? 'مدى سرعة استجابة النظام للمشتتات'
      : 'How quickly the system detects distractions';
  static String get howStrictSystemResponds => isArabic
      ? 'مدى صرامة النظام استجابة لسلوكك'
      : 'How strict the system responds to behavior';
  static String get receiveAlertsReminders => isArabic
      ? 'تلقي تنبيهات وإشعارات النظام'
      : 'Receive system alerts and reminders';
  static String get tracking => isArabic ? 'التتبع' : 'Tracking';
  static String get active => isArabic ? 'نشط' : 'Active';
  static String get inactive => isArabic ? 'غير نشط' : 'Inactive';
  static String get usagePermission =>
      isArabic ? 'صلاحية الاستخدام' : 'Usage Permission';
  static String get granted => isArabic ? 'ممنوح' : 'Granted';
  static String get requiredStr => isArabic ? 'مطلوب' : 'Required';
  static String get overlayPermission =>
      isArabic ? 'صلاحية الظهور للواجهة' : 'Overlay Permission';
  static String get currentLevel =>
      isArabic ? 'المستوى الحالي' : 'Current Level';
  static String get appManagement =>
      isArabic ? 'إدارة التطبيقات' : 'App Management';
  static String get usageLimits => isArabic ? 'حدود الاستخدام' : 'Usage Limits';

  // ── App Blacklist/Whitelist ──
  static String get addToBlacklist =>
      isArabic ? 'إضافة للقائمة السوداء' : 'Add to Blacklist';
  static String get addToWhitelist =>
      isArabic ? 'إضافة للقائمة البيضاء' : 'Add to Whitelist';
  static String get tagHint =>
      isArabic ? 'العلامة (مثلاً: مشتت عالي)' : 'Tag (e.g. High distraction)';
  static String get addBtn => isArabic ? 'إضافة' : 'Add';
  static String get aiWillAnalyzeApp => isArabic
      ? 'الذكاء الاصطناعي سيحلل سلوكك ويحدّث القوائم تلقائياً'
      : 'AI will analyze behavior and update lists automatically';
  static String get blacklist => isArabic ? 'القائمة السوداء' : 'Blacklist';
  static String get whitelist => isArabic ? 'القائمة البيضاء' : 'Whitelist';
  static String get addAppToBlacklist =>
      isArabic ? 'إضافة تطبيق للقائمة السوداء' : 'Add App to Blacklist';
  static String get addAppToWhitelist =>
      isArabic ? 'إضافة تطبيق للقائمة البيضاء' : 'Add App to Whitelist';
  static String appCount(int count) => isArabic
      ? '$_lang == "ar" ? "$count تطبيقات" : "$count apps"'
      : '$count apps';

  // ── Usage Limits ──
  static String get selectAppForLimit =>
      isArabic ? 'اختر تطبيق لتعيين حد الاستخدام' : 'Select App for Limit';
  static String get setDailyUsageLimit =>
      isArabic ? 'تعيين الحد اليومي للاستخدام' : 'Set daily usage limit';
  static String get limitLabel => isArabic ? 'الحد: ' : 'Limit: ';
  static String minUnit(int min) => isArabic ? '$min د' : '${min}m';
  static String get setLimitBtn => isArabic ? 'تعيين الحد' : 'Set Limit';
  static String get usageLimitTag => isArabic ? 'حد الاستخدام' : 'Usage limit';
  static String get perAppLimits =>
      isArabic ? 'حدود كل تطبيق' : 'Per-App Limits';
  static String activeCount(int count) =>
      isArabic ? '$count نشط' : '$count active';
  static String get noLimitsSetYet =>
      isArabic ? 'لم يتم تعيين حدود بعد' : 'No limits set yet';
  static String get tapToAddLimit => isArabic
      ? 'اضغط + لإضافة حد لتطبيقك'
      : 'Tap + to add your first app limit';
  static String get addAppLimit =>
      isArabic ? 'إضافة حد التطبيق' : 'Add App Limit';
  static String get limitExceedWarning => isArabic
      ? 'عند تجاوز الحد المسموح سيتم تفعيل نظام التصعيد تلقائياً. يمكنك ضبط شدة التصعيد من الإعدادات.'
      : 'Exceeding the limit will trigger the escalation engine automatically. You can adjust severity in settings.';

  // ── Habit Priority ──
  static String get dragToReorder => isArabic
      ? 'اسحب لإعادة الترتيب. العادات ذات الأولوية الأعلى تمنح خبرة أكثر.'
      : 'Drag to reorder priorities. Higher priority habits give more XP.';

  // ── Escalation Settings ──
  static String get configureSystemIntervention =>
      isArabic ? 'تكوين تدخلات النظام' : 'Configure system intervention';
  static String get escalationLevels =>
      isArabic ? 'مستويات التصعيد' : 'Escalation Levels';
  static String get warningDelay =>
      isArabic ? 'تأخير التحذير (دقائق)' : 'Warning Delay (minutes)';
  static String get warningDelayDesc => isArabic
      ? 'المدة قبل ظهور أول تحذير عند اكتشاف تشتت'
      : 'Time before the first warning appears after distraction is detected';
  static String get overlayDuration =>
      isArabic ? 'مدة التقييد (دقائق)' : 'Restriction Duration (minutes)';
  static String get overlayDurationDesc => isArabic
      ? 'مدة قفل الشاشة المؤقت في المراحل S3/S4'
      : 'Duration of temporary screen lock at stages S3/S4';
  static String get hardLockDuration =>
      isArabic ? 'مدة القفل المتشدد (دقائق)' : 'Strict Lock Duration (minutes)';
  static String get hardLockDurationDesc => isArabic
      ? 'مدة القفل الكامل في المرحلة S5 — المرحلة الوحيدة التي تخصم نقاط'
      : 'Duration of full lockout at S5 — the only stage that deducts XP';
  static String get settingsAbuseNotice => isArabic
      ? 'التغييرات تسري على التصعيدات المستقبلية فقط. العقوبات النشطة لا تتأثر.'
      : 'Changes apply to future escalations only. Active punishments are not affected.';
  static String get escalationEngine =>
      isArabic ? 'محرك التصعيد' : 'ESCALATION ENGINE';

  static List<String> get escalationLevelDescs => isArabic
      ? [
          'S0 → المراقبة|مراقبة|#22C55E',
          'S1 → إشعار خفيف|تحذير|#3B82F6',
          'S2 → تذكير|تنبيه|#F59E0B',
          'S3 → تقييد مؤقت|حظر|#EF4444',
          'S4 → نافذة إعادة دخول محدودة|تقييد|#DC2626',
          'S5 → قفل كامل + خصم نقاط|إجبار|#991B1B'
        ]
      : [
          'S0 → Monitoring|Monitor|#22C55E',
          'S1 → Soft Notification|Warning|#3B82F6',
          'S2 → Reminder|Alert|#F59E0B',
          'S3 → Temporary Block|Block|#EF4444',
          'S4 → Limited Re-entry|Restrict|#DC2626',
          'S5 → Hard Lock + XP Penalty|Enforce|#991B1B'
        ];

  static String get lowLabel => isArabic ? 'منخفض' : 'low';
  static String get mediumLabel => isArabic ? 'متوسط' : 'medium';
  static String get highLabel => isArabic ? 'عالي' : 'high';
  static String get softLabel => isArabic ? 'خفيف' : 'soft';
  static String get balancedLabel => isArabic ? 'متوازن' : 'balanced';
  static String get strictLabel => isArabic ? 'صارم' : 'strict';

  // ── Help & Support ──
  static String get faq =>
      isArabic ? 'الأسئلة الشائعة' : 'Frequently Asked Questions';
  static String get faqQ1 => isArabic
      ? 'كيف يعمل نظام التصعيد؟'
      : 'How does the escalation system work?';
  static String get faqA1 => isArabic
      ? 'يراقب النظام أنماط استخدامك للهاتف. عندما يكتشف تشتت عالي، يتصاعد من S0 (طبيعي) إلى S5 (قفل متشدد) تدريجياً، مع إعطاء فرصة للتصحيح الذاتي في كل مستوى.'
      : 'The system monitors your phone usage patterns. When it detects excessive distraction, it escalates from S0 (normal) to S5 (hard lock) gradually, giving you chances to self-correct at each level.';
  static String get faqQ2 =>
      isArabic ? 'ما هي التحديات (الزنازين)؟' : 'What are Dungeons?';
  static String get faqA2 => isArabic
      ? 'التحديات هي مهام تستمر لعدة أيام تساعدك على هزيمة العادات السيئة. كل عادة سيئة هي "زعيم" له نقاط ضعف. أكمل أيام التحدي لكسب نقاط الخبرة.'
      : 'Dungeons are multi-day challenges that help you defeat bad habits. Each bad habit is a "boss" with weaknesses. Complete the challenge days to earn XP and level up.';
  static String get faqQ3 =>
      isArabic ? 'كيف يعمل نظام الهوية؟' : 'How does the Identity system work?';
  static String get faqA3 => isArabic
      ? 'اختر ٢-٣ هويات ترغب في أن تصبحها. يبني النظام شجرة مهارات حول هذه الهويات ويصمم عاداتك وفقاً لها.'
      : 'Choose 2-3 identities (Reader, Athlete, etc.) that define who you want to become. The system builds skill trees around these identities and tailors your habits accordingly.';
  static String get faqQ4 => isArabic
      ? 'هل يمكنني إيقاف النظام مؤقتاً؟'
      : 'Can I disable the system temporarily?';
  static String get faqA4 => isArabic
      ? 'لا يمكن تجاوز نظام التصعيد بسهولة، فقد صمم ليكون صارماً. هذا مقصود لكي يبني انضباطك.'
      : 'Focus Mode can be paused, but the escalation system is designed to be persistent. This is intentional — a system you can easily bypass won\'t help you build discipline.';

  static String get contact => isArabic ? 'التواصل' : 'Contact';
  static String get emailLabel => isArabic ? 'البريد الإلكتروني' : 'Email';
  static String get versionLabel => isArabic ? 'الإصدار' : 'Version';
  static String get licenseLabel => isArabic ? 'الرخصة' : 'License';
  static String get aboutApp => isArabic ? 'عن التطبيق' : 'About Self Leveling';
  static String get aboutAppDesc => isArabic
      ? 'نظام تدخل سلوكي يعتمد على اللعبة لمساعدتك في بناء عادات إيجابية وتدمير السلبية، ويقوم الذكاء الاصطناعي برصد تشتتك وتحفيزك.'
      : 'Self Leveling is a behavioral intervention system inspired by Solo Leveling and Atomic Habits. It uses gamification and AI to help you build positive habits and break negative ones.';

  // ── Focus ──
  static String get focusModeActive =>
      isArabic ? 'وضع التركيز نشط' : 'Focus Mode Active';
  static String get stayFocused =>
      isArabic ? 'ابقَ مركزاً. نظامك ' : 'Stay focused. Your system is ';
  static String get withYou => isArabic ? 'معك' : 'with you';
  static String get endSession => isArabic ? 'إنهاء الجلسة' : 'End Session';
  static String get sessionComplete =>
      isArabic ? 'اكتملت الجلسة' : 'Session Complete';
  static String get success => isArabic ? 'نجاح' : 'SUCCESS';

  // ── Overlay / Lock ──
  static String get focusModeActivated =>
      isArabic ? 'تم تفعيل وضع التركيز' : 'Focus Mode Activated';
  static String get tooLong => isArabic ? 'طويل جداً' : 'too long';
  static String get timeRemaining =>
      isArabic ? 'الوقت المتبقي' : 'Time Remaining';
  static String get resetAndRefocus => isArabic ? 'إعادة ضبط' : 'reset';
  static String get refocus => isArabic ? 'إعادة التركيز' : 'refocus';
  static String get systemIntervention =>
      isArabic ? 'تدخل النظام' : 'SYSTEM INTERVENTION';
  static String get accessRestricted =>
      isArabic ? 'الوصول مقيد' : 'Access Restricted';
  static String get systemAlert => isArabic ? 'تنبيه النظام' : 'System Alert';
  static String get locked => isArabic ? 'مقفل' : 'locked';
  static String get lockedFor => isArabic ? 'مقفل لمدة' : 'Locked For';
  static String get enforcedRestriction =>
      isArabic ? 'تقييد إجباري' : 'ENFORCED RESTRICTION';

  // ── Overlay Lock Screen ──
  static String get usingAppTooLong => isArabic
      ? 'لقد استخدمت هذا التطبيق لفترة '
      : 'You\'ve been using this app for ';
  static String get takeTimeTo =>
      isArabic ? 'خذ هذا الوقت لـ ' : 'Take this time to ';
  static String get andWord => isArabic ? ' و ' : ' and ';

  // ── Hard Lock Screen ──
  static String get appLockedToProtect =>
      isArabic ? 'هذا التطبيق مقفل مؤقتاً ' : 'This app is temporarily ';
  static String get toProtectFocus =>
      isArabic ? ' لحماية تركيزك' : ' to protect your focus';
  static String selfControlPenalty(int n) =>
      isArabic ? '-$n نقاط تحكم ذاتي' : '-$n Self Control Points';
  static String get enforcedForGrowth => isArabic
      ? 'النظام فرض هذا التقييد '
      : 'The system has enforced this restriction ';
  static String get forYourGrowth => isArabic ? 'لتطورك' : 'for your growth';

  // ── Limited Access Screen ──
  static String get habitsLabel => isArabic ? 'العادات' : 'Habits';
  static String get aiChatLabel => isArabic ? 'محادثة الذكاء' : 'AI Chat';
  static String get statisticsLabel => isArabic ? 'الإحصائيات' : 'Statistics';
  static String get settingsLabel => isArabic ? 'الإعدادات' : 'Settings';

  // ── Notification Banner ──
  static String get notifDisabledWarning => isArabic
      ? 'الإشعارات معطلة — التحذيرات لن تظهر'
      : 'Notifications disabled — warnings won\'t appear';
  static String get enableLabel => isArabic ? 'تفعيل' : 'Enable';

  // ── Permissions Revoked Banner ──
  static String get permissionsRevoked => isArabic
      ? 'أذونات مطلوبة معطلة'
      : 'Required Permissions Disabled';
  static String get permissionsRevokedDesc => isArabic
      ? 'النظام لا يعمل بشكل صحيح. اضغط لإعادة تفعيل الأذونات.'
      : 'System is not working properly. Tap to re-enable permissions.';
  static String get fixNow => isArabic ? 'إصلاح' : 'Fix Now';

  // ── AI Chat ──
  static String get newChat => isArabic ? 'محادثة جديدة' : 'New Chat';
  static String get conversations => isArabic ? 'المحادثات' : 'Conversations';
  static String get noConversationsYet => isArabic
      ? 'لا توجد محادثات بعد'
      : 'No conversations yet';
  static String get startNewConversation => isArabic
      ? 'ابدأ محادثة جديدة مع مدربك'
      : 'Start a new conversation with your coach';
  static String get deleteConversation => isArabic
      ? 'حذف المحادثة'
      : 'Delete Conversation';
  static String get deleteConversationConfirm => isArabic
      ? 'هل تريد حذف هذه المحادثة نهائياً؟'
      : 'Are you sure you want to delete this conversation?';
  static String get delete => isArabic ? 'حذف' : 'Delete';
  static String get levelingCoach => isArabic
      ? 'مدرب التطوير'
      : 'Leveling Coach';
  static String get coachSubtitle => isArabic
      ? 'مدربك الشخصي للتطوير الذاتي'
      : 'Your personal self-improvement coach';
  static String get askAnything => isArabic
      ? 'اسأل أي شيء...'
      : 'Ask anything...';
  static String get suggestionHabits => isArabic
      ? '💡 كيف أحسن عاداتي؟'
      : '💡 How to improve my habits?';
  static String get suggestionFocus => isArabic
      ? '🎯 نصائح للتركيز'
      : '🎯 Focus tips';
  static String get suggestionProgress => isArabic
      ? '📊 حلل تقدمي'
      : '📊 Analyze my progress';
  static String get suggestionMotivation => isArabic
      ? '🔥 أحتاج تحفيز'
      : '🔥 I need motivation';
  static String get thinking => isArabic ? 'يفكر...' : 'Thinking...';
  static String get messageCopied => isArabic
      ? 'تم نسخ الرسالة'
      : 'Message copied';
  static String get notificationsDisabledTitle =>
      isArabic ? 'الإشعارات معطلة' : 'Notifications Disabled';
  static String get cannotDeliverWarnings => isArabic
      ? 'لا يمكن تسليم التحذيرات السلوكية (S1/S2)'
      : 'Behavioral warnings (S1/S2) cannot be delivered';
  static String get enableNotifications =>
      isArabic ? 'تفعيل الإشعارات' : 'Enable Notifications';

  // ── Escalation Info Banner (inside app, non-blocking) ──
  static String appRestricted(String appName) =>
      isArabic ? '$appName مقيد حالياً' : '$appName is currently restricted';
  static String get lockActiveLabel =>
      isArabic ? 'قفل مؤقت نشط' : 'Temporary lock active';
  static String minutesRemaining(int m) =>
      isArabic ? '$m دقيقة متبقية' : '$m min remaining';
  static String currentStageLabel(String stage) =>
      isArabic ? 'المرحلة الحالية: $stage' : 'Current stage: $stage';
  static String get systemHandlingLabel => isArabic
      ? 'النظام يتعامل مع هذا خارج التطبيق'
      : 'System is handling this outside the app';

  // ── System Loading ──
  static String get analyzing => isArabic ? 'جاري التحليل' : 'Analyzing';
  static String get aiProcessing =>
      isArabic ? 'معالجة الذكاء' : 'AI PROCESSING';
  static String get limitedAccess => isArabic ? 'وصول محدود' : 'Limited Access';
  static String get excessiveDistractionDetected => isArabic
      ? 'النظام اكتشف الكثير من التشتت.'
      : 'The system has detected excessive distraction.';
  static String get onlyEssentialFeatures => isArabic
      ? 'الميزات الأساسية فقط متاحة للعمل.'
      : 'Only essential features are available.';
  static String get completeHabitsToRestore => isArabic
      ? 'أكمل عاداتك لاستعادة الوصول الكامل.'
      : 'Complete your habits to restore full access';
  static String get controlledAccess =>
      isArabic ? 'وصول مقيد' : 'CONTROLLED ACCESS';

  static String get noDataYet =>
      isArabic ? 'لا توجد بيانات بعد' : 'No Data Yet';
  static String get startBuildingHabits => isArabic
      ? 'ابدأ في بناء العادات لرؤية تقدمك هنا'
      : 'Start building habits to see your progress here';
  static String get addFirstHabit =>
      isArabic ? 'إضافة أول عادة' : 'Add First Habit';
  static String get awaitingInput =>
      isArabic ? 'بانتظار الإدخال' : 'AWAITING INPUT';
  static String get noAppsFound =>
      isArabic ? 'لم يتم العثور على تطبيقات' : 'No apps found';
  static String get selectApp => isArabic ? 'اختر تطبيقاً' : 'Select App';

  // ── Navigation ──
  static String get home => isArabic ? 'الرئيسية' : 'Home';
  static String get ai => isArabic ? 'الذكاء' : 'AI';
  static String get stats => isArabic ? 'الإحصائيات' : 'Stats';
}
