import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/input_field.dart';
import '../../../navigation/app_router.dart';
import '../../../domain/entities/onboarding_survey.dart';
import '../../../providers/locale_provider.dart';

// --- Data Models for Survey ---
enum QuestionType { single, multi, open, intro }

class SurveyQuestion {
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final IconData icon;
  final QuestionType type;
  final List<SurveyOption> options;
  final int maxSelect;
  final String fieldKey;

  SurveyQuestion({
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.icon,
    this.type = QuestionType.single,
    this.options = const [],
    this.maxSelect = 1,
    this.fieldKey = '',
  });
}

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  
  // Data accumulator
  final Map<String, dynamic> _answers = {};
  final Map<String, String> _otherTexts = {}; // Tracks specific custom inputs

  late final List<SurveyQuestion> _questions;

  @override
  void initState() {
    super.initState();
    _initSurvey();
  }

  void _initSurvey() {
    _questions = [
      // Intro 
      SurveyQuestion(
        titleEn: 'System Diagnostics',
        titleAr: 'تشخيص النظام',
        subtitleEn: 'To calibrate Self Leveling exactly to your brain, we need to understand your baseline. This process takes ~2 minutes.',
        subtitleAr: 'لمعايرة النظام حصرياً لدماغك، نحتاج لمعرفة نقطة بدايتك. تستغرق العملية دقيقتين.',
        icon: Icons.radar,
        type: QuestionType.intro,
      ),
      // Q1
      SurveyQuestion(
        titleEn: 'Primary installation motive',
        titleAr: 'الدافع الأساسي للتثبيت',
        subtitleEn: 'Why did you activate this system today?',
        subtitleAr: 'لماذا قمت بتفعيل هذا النظام اليوم؟',
        icon: Icons.flag,
        type: QuestionType.single,
        options: OnboardingSurvey.reasons,
        fieldKey: 'installReason',
      ),
      // Q2
      SurveyQuestion(
        titleEn: 'Current Occupation',
        titleAr: 'المهنة الحالية',
        subtitleEn: 'Your daily schedule constraints.',
        subtitleAr: 'قيود جدولك اليومي.',
        icon: Icons.work,
        type: QuestionType.single,
        options: OnboardingSurvey.occupations,
        fieldKey: 'occupation',
      ),
      // Q3
      SurveyQuestion(
        titleEn: 'Target Identity',
        titleAr: 'الهوية المستهدفة',
        subtitleEn: 'Who are you trying to become?',
        subtitleAr: 'من هو الشخص الذي تسعى لتكونه؟',
        icon: Icons.psychology,
        type: QuestionType.single,
        options: OnboardingSurvey.identities,
        fieldKey: 'primaryIdentity',
      ),
      // Q4
      SurveyQuestion(
        titleEn: 'Biggest Frustration',
        titleAr: 'أكبر إحباط لك',
        subtitleEn: 'Select up to 2 pain points.',
        subtitleAr: 'اختر حتى نقطتين تزعجانك.',
        icon: Icons.warning_amber,
        type: QuestionType.multi,
        maxSelect: 2,
        options: OnboardingSurvey.frustrations,
        fieldKey: 'frustrationPoints',
      ),
      // Q5
      SurveyQuestion(
        titleEn: 'Main Distractors',
        titleAr: 'المشتتات الرئيسية',
        subtitleEn: 'Select up to 3 application categories.',
        subtitleAr: 'اختر حتى 3 تصنيفات تطبيقات.',
        icon: Icons.app_blocking,
        type: QuestionType.multi,
        maxSelect: 3,
        options: OnboardingSurvey.distractionCategories,
        fieldKey: 'distractionCategories',
      ),
      // Q6
      SurveyQuestion(
        titleEn: 'Weakness Windows',
        titleAr: 'نوافذ الضعف',
        subtitleEn: 'When do you usually lose control?',
        subtitleAr: 'متى تفقد السيطرة عادة؟',
        icon: Icons.access_time,
        type: QuestionType.single,
        options: OnboardingSurvey.weaknessWindows,
        fieldKey: 'weaknessWindow',
      ),
      // Q7
      SurveyQuestion(
        titleEn: 'Emotional Triggers',
        titleAr: 'المحفزات العاطفية',
        subtitleEn: 'What feeling is closest when you drift?',
        subtitleAr: 'ما هو أقرب شعور لك عندما تنجرف للهاتف؟',
        icon: Icons.favorite_border,
        type: QuestionType.single,
        options: OnboardingSurvey.emotionalTriggers,
        fieldKey: 'emotionalTrigger',
      ),
      // Q8
      SurveyQuestion(
        titleEn: 'Habits to Build',
        titleAr: 'عادات تطمح لبنائها',
        subtitleEn: 'Select up to 4 constructive behaviors.',
        subtitleAr: 'اختر حتى 4 سلوكيات إيجابية.',
        icon: Icons.fitness_center,
        type: QuestionType.multi,
        maxSelect: 4,
        options: OnboardingSurvey.targetHabits,
        fieldKey: 'targetHabits',
      ),
      // Q9
      SurveyQuestion(
        titleEn: 'Primary Break Target',
        titleAr: 'الهدف الأساسي للكسر',
        subtitleEn: 'Which habit must we destroy first?',
        subtitleAr: 'أي عادة يجب أن ندمرها أولاً؟',
        icon: Icons.block,
        type: QuestionType.single,
        options: OnboardingSurvey.breakTargets,
        fieldKey: 'breakTarget',
      ),
      // Q10
      SurveyQuestion(
        titleEn: 'Strictness Preference',
        titleAr: 'تفضيلات الصرامة',
        subtitleEn: 'When should the escalation engine be aggressive?',
        subtitleAr: 'متى يجب أن يكون نظام التصعيد عدائياً؟',
        icon: Icons.security,
        type: QuestionType.single,
        options: OnboardingSurvey.strictnessPreferences,
        fieldKey: 'strictnessPreference',
      ),
      // Q11
      SurveyQuestion(
        titleEn: 'Intervention Voice',
        titleAr: 'صوت التدخل',
        subtitleEn: 'What message style helps you specifically?',
        subtitleAr: 'ما هو أسلوب الرسائل الأنسب لك؟',
        icon: Icons.record_voice_over,
        type: QuestionType.single,
        options: OnboardingSurvey.messageStyles,
        fieldKey: 'messageStylePreference',
      ),
      // Q12
      SurveyQuestion(
        titleEn: 'Escalation Response',
        titleAr: 'الاستجابة للتصعيد',
        subtitleEn: 'When you ignore warnings, what should I do?',
        subtitleAr: 'عندما تتجاهل التحذيرات، ماذا يجب أن أفعل؟',
        icon: Icons.gavel,
        type: QuestionType.single,
        options: OnboardingSurvey.interventionPreferences,
        fieldKey: 'interventionPreference',
      ),
      // Q13
      SurveyQuestion(
        titleEn: 'Habit Size',
        titleAr: 'حجم العادة',
        subtitleEn: 'How much time per session do you prefer?',
        subtitleAr: 'كم من الوقت تفضل في الجلسة الواحدة؟',
        icon: Icons.timer,
        type: QuestionType.single,
        options: OnboardingSurvey.habitSizes,
        fieldKey: 'preferredHabitSize',
      ),
      // Q14
      SurveyQuestion(
        titleEn: 'Core Desire',
        titleAr: 'الرغبة الجوهرية',
        subtitleEn: 'What do you most want to truly change about yourself?',
        subtitleAr: 'أكثر شيء ترغب حقاً في تغييره في نفسك؟',
        icon: Icons.stars,
        type: QuestionType.open,
        fieldKey: 'openReflectChange',
      ),
      // Q15
      SurveyQuestion(
        titleEn: 'Deepest Pain',
        titleAr: 'الألم الأعمق',
        subtitleEn: 'What hurts most in your current relationship with the phone?',
        subtitleAr: 'ما الذي يزعجك حقاً في علاقتك الحالية بهاتفك؟',
        icon: Icons.healing,
        type: QuestionType.open,
        fieldKey: 'openReflectPain',
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _canProceed() {
    final q = _questions[_currentStep];
    if (q.type == QuestionType.intro) return true;
    
    // Check if answered
    final value = _answers[q.fieldKey];
    if (q.type == QuestionType.single) {
      if (value == null || value.toString().isEmpty) return false;
      if (value == 'other' && (_otherTexts[q.fieldKey] ?? '').isEmpty) return false;
      return true;
    }
    if (q.type == QuestionType.multi) {
      if (value == null || (value as List).isEmpty) return false;
      if ((value as List).contains('other') && (_otherTexts[q.fieldKey] ?? '').isEmpty) return false;
      return true;
    }
    if (q.type == QuestionType.open) {
      return value != null && value.toString().trim().isNotEmpty;
    }
    return false;
  }

  void _nextStep() {
    if (_currentStep < _questions.length - 1) {
      setState(() {
        _currentStep++;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    } else {
      // Done - save to riverpod state / router param, navigate to Profile Review
      final currentLang = ref.read(localeProvider).languageCode;
      context.push(RoutePaths.profileReview, extra: {
        'answers': _answers,
        'otherTexts': _otherTexts,
        'surveyLanguage': currentLang,
      });
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _pageController.animateToPage(
          _currentStep,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SystemBackground(
        particleCount: 12,
        child: SafeArea(
          child: Column(
            children: [
              // Progress Bar
              if (_currentStep > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Phase ${_currentStep} / ${_questions.length - 1}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                        Text('${((_currentStep) / (_questions.length - 1) * 100).toInt()}%', style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600)),
                      ]),
                      const SizedBox(height: 12),
                      Container(
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(2)),
                        child: Row(children: List.generate(_questions.length - 1, (i) => Expanded(
                          child: Container(
                            margin: EdgeInsets.only(right: i < _questions.length - 2 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: (i + 1) <= _currentStep ? AppColors.primaryBlue : AppColors.cardBackground.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: (i + 1) == _currentStep ? [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.8), blurRadius: 8)] : null,
                            ),
                          ),
                        ))),
                      ),
                    ],
                  ),
                ).animate().fadeIn(),

              // Content View
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // no swipe, only buttons
                  itemCount: _questions.length,
                  itemBuilder: (context, index) {
                    return _buildQuestionCard(_questions[index]);
                  },
                ),
              ),

              // Bottom Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        flex: 1,
                        child: GestureDetector(
                          onTap: _prevStep,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
                            ),
                            child: Center(child: Text('Back', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary))),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Opacity(
                        opacity: _canProceed() ? 1.0 : 0.4,
                        child: GlowButton(
                          text: _currentStep == _questions.length - 1 ? 'Analyze Data' : (_currentStep == 0 ? 'Commence Calibration' : 'Next'),
                          onPressed: _canProceed() ? _nextStep : () {},
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard(SurveyQuestion q) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    final title = isAr ? q.titleAr : q.titleEn;
    final subtitle = isAr ? q.subtitleAr : q.subtitleEn;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: GlowCard(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                  boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.3), blurRadius: 20)],
                ),
                child: Icon(q.icon, color: AppColors.primaryBlue, size: 32),
              ),
              const SizedBox(height: 24),

              Text(title, style: AppTextStyles.h3, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(subtitle, style: AppTextStyles.secondaryText, textAlign: TextAlign.center),
              const SizedBox(height: 32),

              if (q.type == QuestionType.intro)
                 _buildIntro(isAr),
              if (q.type == QuestionType.single)
                 _buildSingleChoice(q, isAr),
              if (q.type == QuestionType.multi)
                 _buildMultiChoice(q, isAr),
              if (q.type == QuestionType.open)
                 _buildOpenEnded(q, isAr),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIntro(bool isAr) {
    return Column(
      children: [
        // Language Switcher Toggle
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLangTab('EN', !isAr, () => ref.read(localeProvider.notifier).setLocale('en')),
              _buildLangTab('عربي', isAr, () => ref.read(localeProvider.notifier).setLocale('ar')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(isAr ? "نمذجات منطقية صارمة" : "Strict logic modeling", style: AppTextStyles.bodyMedium)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(isAr ? "تتبع نفسي صريح" : "Honest psychological tracking", style: AppTextStyles.bodyMedium)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.primaryBlue, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(isAr ? "نقاط ضعفك الدقيقة" : "Your precise role and weakness vectors", style: AppTextStyles.bodyMedium)),
          ],
        ),
      ],
    );
  }

  Widget _buildLangTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          title,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSingleChoice(SurveyQuestion q, bool isAr) {
    final selectedId = _answers[q.fieldKey] as String?;
    final isOtherSelected = selectedId == 'other';

    return Column(
      children: [
        ...q.options.map((option) {
          final isSec = option.id == selectedId;
          final displayText = isAr ? option.labelAr : option.labelEn;
          return GestureDetector(
            onTap: () => setState(() {
              _answers[q.fieldKey] = option.id; // STORE CANONICAL ID
              if (option.id != 'other') _otherTexts[q.fieldKey] = '';
            }),
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSec ? AppColors.primaryBlue.withOpacity(0.2) : AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSec ? AppColors.primaryBlue : AppColors.primaryBlue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(isSec ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSec ? AppColors.primaryBlue : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(displayText, style: AppTextStyles.bodyMedium.copyWith(color: isSec ? Colors.white : AppColors.textSecondary))),
                ],
              ),
            ),
          );
        }),
        if (isOtherSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: InputField(
              placeholder: isAr ? 'يرجى التحديد...' : 'Please specify...',
              onChanged: (val) => setState(() => _otherTexts[q.fieldKey] = val),
            ).animate().fadeIn(duration: 200.ms),
          ),
      ],
    );
  }

  Widget _buildMultiChoice(SurveyQuestion q, bool isAr) {
    final selectedList = (_answers[q.fieldKey] as List<String>?) ?? [];
    final isOtherSelected = selectedList.contains('other');

    return Column(
      children: [
        ...q.options.map((option) {
          final isSec = selectedList.contains(option.id);
          final displayText = isAr ? option.labelAr : option.labelEn;
          return GestureDetector(
            onTap: () {
              setState(() {
                if (isSec) {
                  selectedList.remove(option.id);
                  if (option.id == 'other') _otherTexts[q.fieldKey] = '';
                } else {
                  if (selectedList.length < q.maxSelect) {
                    selectedList.add(option.id); // STORE CANONICAL ID
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isAr ? 'الحد الأقصى ${q.maxSelect} اختيارات.' : 'Maximum ${q.maxSelect} selections allowed.')));
                  }
                }
                _answers[q.fieldKey] = selectedList;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSec ? AppColors.primaryBlue.withOpacity(0.2) : AppColors.background.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSec ? AppColors.primaryBlue : AppColors.primaryBlue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  Icon(isSec ? Icons.check_box : Icons.check_box_outline_blank, color: isSec ? AppColors.primaryBlue : AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(child: Text(displayText, style: AppTextStyles.bodyMedium.copyWith(color: isSec ? Colors.white : AppColors.textSecondary))),
                ],
              ),
            ),
          );
        }),
        if (isOtherSelected)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: InputField(
              placeholder: isAr ? 'يرجى التحديد...' : 'Please specify...',
              onChanged: (val) => setState(() => _otherTexts[q.fieldKey] = val),
            ).animate().fadeIn(duration: 200.ms),
          ),
      ],
    );
  }

  Widget _buildOpenEnded(SurveyQuestion q, bool isAr) {
    return InputField(
      placeholder: isAr ? 'كن صريحاً تماماً...' : 'Be entirely honest...',
      maxLines: 4,
      onChanged: (val) => setState(() => _answers[q.fieldKey] = val),
    );
  }
}
