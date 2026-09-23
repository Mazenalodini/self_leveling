/// Structured mapping for bilingual canonical onboarding survey options.
/// Ensures we have a reliable data model for machine parsing rather than raw UI strings.

class SurveyOption {
  final String id;
  final String labelEn;
  final String labelAr;

  const SurveyOption({
    required this.id,
    required this.labelEn,
    required this.labelAr,
  });
}

class OnboardingSurvey {
  // Helper to map UI string logic back later for ProfileReviewScreen (Legacy Support Backup)
  static String getLabel(String id, bool isArabic) {
    if (id.isEmpty) return '';
    if (id == 'Other') return isArabic ? 'أخرى' : 'Other'; // Handle fallback

    for (var list in [
      reasons, occupations, identities, frustrations,
      distractionCategories, weaknessWindows, emotionalTriggers,
      targetHabits, breakTargets, strictnessPreferences,
      messageStyles, interventionPreferences, habitSizes
    ]) {
      for (var opt in list) {
        if (opt.id == id || opt.labelEn == id) { // fallback comparison for legacy string saves
          return isArabic ? opt.labelAr : opt.labelEn;
        }
      }
    }
    return id; // if custom text string 
  }

  static const List<SurveyOption> reasons = [
    SurveyOption(id: 'wasting_too_much_time', labelEn: 'Wasting too much time on the phone', labelAr: 'تضييع وقت طويل على الهاتف'),
    SurveyOption(id: 'build_better_habits', labelEn: 'Want to build better habits', labelAr: 'أرغب في بناء عادات أفضل'),
    SurveyOption(id: 'break_bad_habit', labelEn: 'Want to break a bad habit', labelAr: 'أرغب في كسر عادة سيئة'),
    SurveyOption(id: 'more_discipline', labelEn: 'Want more discipline', labelAr: 'أرغب في مزيد من الانضباط'),
    SurveyOption(id: 'better_focus', labelEn: 'Want better focus for study/work', labelAr: 'أحتاج لتركيز أفضل للدراسة/العمل'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> occupations = [
    SurveyOption(id: 'student', labelEn: 'Student', labelAr: 'طالب'),
    SurveyOption(id: 'teacher', labelEn: 'Teacher / Professor', labelAr: 'معلم / أستاذ'),
    SurveyOption(id: 'employee', labelEn: 'Employee', labelAr: 'موظف'),
    SurveyOption(id: 'freelancer', labelEn: 'Freelancer', labelAr: 'عمل حر'),
    SurveyOption(id: 'job_seeker', labelEn: 'Job seeker', labelAr: 'باحث عن عمل'),
    SurveyOption(id: 'homemaker', labelEn: 'Homemaker', labelAr: 'ربة منزل'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> identities = [
    SurveyOption(id: 'disciplined_person', labelEn: 'Disciplined person', labelAr: 'شخص منضبط'),
    SurveyOption(id: 'focused_person', labelEn: 'Focused person', labelAr: 'شخص شديد التركيز'),
    SurveyOption(id: 'reader', labelEn: 'Reader', labelAr: 'قارئ'),
    SurveyOption(id: 'athlete', labelEn: 'Athlete', labelAr: 'رياضي'),
    SurveyOption(id: 'calm_balanced', labelEn: 'Calm and balanced person', labelAr: 'شخص هادئ ومتوازن'),
    SurveyOption(id: 'does_not_waste_day', labelEn: 'Someone who does not waste their day', labelAr: 'شخص لا يضيع يومه'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> frustrations = [
    SurveyOption(id: 'lose_hours', labelEn: 'I lose hours without noticing', labelAr: 'أفقد ساعات دون أن أشعر'),
    SurveyOption(id: 'start_dont_continue', labelEn: 'I start but don’t continue', labelAr: 'أبدأ ولكن لا أستمر'),
    SurveyOption(id: 'know_what_to_do_dont_commit', labelEn: 'I know what to do but don’t commit', labelAr: 'أعرف ما يجب فعله ولا ألتزم'),
    SurveyOption(id: 'escape_into_phone', labelEn: 'I escape into my phone under pressure', labelAr: 'أهرب إلى الهاتف تحت الضغط'),
    SurveyOption(id: 'stay_up_too_late', labelEn: 'I stay up too late', labelAr: 'أسهر لوقت متأخر جداً'),
    SurveyOption(id: 'bounce_between_apps', labelEn: 'I bounce between apps without purpose', labelAr: 'أتنقل بين التطبيقات بلا هدف'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> distractionCategories = [
    SurveyOption(id: 'short_videos', labelEn: 'Short-form videos', labelAr: 'فيديوهات قصيرة'),
    SurveyOption(id: 'social_media', labelEn: 'Social media', labelAr: 'التواصل الاجتماعي'),
    SurveyOption(id: 'youtube', labelEn: 'YouTube', labelAr: 'يوتيوب'),
    SurveyOption(id: 'games', labelEn: 'Games', labelAr: 'ألعاب'),
    SurveyOption(id: 'messaging', labelEn: 'Chats/Messaging', labelAr: 'محادثات / رسائل'),
    SurveyOption(id: 'random_browsing', labelEn: 'Random browsing', labelAr: 'تصفح عشوائي'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> weaknessWindows = [
    SurveyOption(id: 'morning', labelEn: 'Morning', labelAr: 'الصباح'),
    SurveyOption(id: 'during_work', labelEn: 'During study/work', labelAr: 'أثناء الدراسة/العمل'),
    SurveyOption(id: 'afternoon', labelEn: 'Afternoon', labelAr: 'بعد الظهر'),
    SurveyOption(id: 'evening', labelEn: 'Evening', labelAr: 'المساء'),
    SurveyOption(id: 'before_sleep', labelEn: 'Before sleep', labelAr: 'قبل النوم'),
    SurveyOption(id: 'when_tired', labelEn: 'When tired', labelAr: 'عند التعب'),
    SurveyOption(id: 'when_stressed', labelEn: 'When stressed', labelAr: 'تحت الضغط'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> emotionalTriggers = [
    SurveyOption(id: 'boredom', labelEn: 'Boredom', labelAr: 'ملل'),
    SurveyOption(id: 'pressure', labelEn: 'Pressure', labelAr: 'ضغط نفسي'),
    SurveyOption(id: 'escape', labelEn: 'Escape', labelAr: 'هروب'),
    SurveyOption(id: 'fatigue', labelEn: 'Fatigue', labelAr: 'إرهاق'),
    SurveyOption(id: 'emptiness', labelEn: 'Emptiness', labelAr: 'فراغ'),
    SurveyOption(id: 'anxiety', labelEn: 'Anxiety', labelAr: 'قلق'),
    SurveyOption(id: 'automatic_habit', labelEn: 'Automatic habit', labelAr: 'عادة لا إرادية'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> targetHabits = [
    SurveyOption(id: 'reading', labelEn: 'Reading', labelAr: 'القراءة'),
    SurveyOption(id: 'focus_sessions', labelEn: 'Focus sessions', labelAr: 'جلسات تركيز عميق'),
    SurveyOption(id: 'sleeping_earlier', labelEn: 'Sleeping earlier', labelAr: 'النوم مبكراً'),
    SurveyOption(id: 'waking_earlier', labelEn: 'Waking earlier', labelAr: 'الاستيقاظ مبكراً'),
    SurveyOption(id: 'exercise', labelEn: 'Exercise', labelAr: 'الرياضة'),
    SurveyOption(id: 'studying', labelEn: 'Studying/Review', labelAr: 'دراسة / مراجعة'),
    SurveyOption(id: 'journaling', labelEn: 'Journaling/Reflection', labelAr: 'كتابة / تأمل'),
    SurveyOption(id: 'reducing_phone', labelEn: 'Reducing phone use', labelAr: 'تقليل استخدام الهاتف'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> breakTargets = [
    SurveyOption(id: 'short_videos', labelEn: 'Short-form videos', labelAr: 'فيديوهات قصيرة'),
    SurveyOption(id: 'social_media', labelEn: 'Social media', labelAr: 'تواصل اجتماعي'),
    SurveyOption(id: 'staying_up_late', labelEn: 'Staying up late', labelAr: 'السهر'),
    SurveyOption(id: 'procrastination', labelEn: 'Procrastination', labelAr: 'المماطلة'),
    SurveyOption(id: 'opening_phone_randomly', labelEn: 'Opening phone for no reason', labelAr: 'فتح الهاتف بلا سبب'),
    SurveyOption(id: 'gaming', labelEn: 'Gaming', labelAr: 'الألعاب'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> strictnessPreferences = [
    SurveyOption(id: 'during_work', labelEn: 'During study/work', labelAr: 'أثناء الدراسة/العمل'),
    SurveyOption(id: 'evening', labelEn: 'In the evening', labelAr: 'في المساء'),
    SurveyOption(id: 'before_sleep', labelEn: 'Before sleep', labelAr: 'قبل النوم'),
    SurveyOption(id: 'all_day', labelEn: 'All day', labelAr: 'طوال اليوم'),
    SurveyOption(id: 'custom_times', labelEn: 'At times I define', labelAr: 'في أوقات أحددها بنفسي'),
    SurveyOption(id: 'other', labelEn: 'Other', labelAr: 'أخرى'),
  ];

  static const List<SurveyOption> messageStyles = [
    SurveyOption(id: 'gentle_encouraging', labelEn: 'Gentle and encouraging', labelAr: 'لطيف ومحفز'),
    SurveyOption(id: 'direct_clear', labelEn: 'Direct and clear', labelAr: 'مباشر وواضح'),
    SurveyOption(id: 'slightly_strict', labelEn: 'Slightly strict', labelAr: 'صارم بعض الشيء'),
    SurveyOption(id: 'practical_short', labelEn: 'Practical and short', labelAr: 'عملي وقصير'),
    SurveyOption(id: 'emotional_motivating', labelEn: 'Emotional and motivating', labelAr: 'عاطفي ومُلهِم'),
    SurveyOption(id: 'system_decides', labelEn: 'Let the app learn and decide', labelAr: 'دع النظام يتخذ القرار'),
  ];

  static const List<SurveyOption> interventionPreferences = [
    SurveyOption(id: 'remind_gently', labelEn: 'Remind me gently again', labelAr: 'ذكرني بلطف مرة أخرى'),
    SurveyOption(id: 'more_direct', labelEn: 'Become more direct', labelAr: 'كن مباشراً أكثر'),
    SurveyOption(id: 'increase_friction', labelEn: 'Increase friction gradually', labelAr: 'زد من الاحتكاك تدريجياً'),
    SurveyOption(id: 'block_after_repetition', labelEn: 'Block only after repetition', labelAr: 'احظر فقط بعد التكرار'),
    SurveyOption(id: 'system_decides', labelEn: 'Decide based on my behavior', labelAr: 'حدد بناءً على سلوكي'),
  ];

  static const List<SurveyOption> habitSizes = [
    SurveyOption(id: 'very_small', labelEn: 'Very small (2–5 min)', labelAr: 'صغير جداً (2-5 دقائق)'),
    SurveyOption(id: 'small', labelEn: 'Small (5–10 min)', labelAr: 'صغير (5-10 دقائق)'),
    SurveyOption(id: 'medium', labelEn: 'Medium (10–20 min)', labelAr: 'متوسط (10-20 دقيقة)'),
    SurveyOption(id: 'system_decides', labelEn: 'Let the app decide', labelAr: 'دع النظام يقرر'),
  ];
}
