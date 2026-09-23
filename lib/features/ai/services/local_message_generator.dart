import '../domain/interfaces/message_generator.dart';
import '../domain/entities/ai_contexts.dart';
import '../domain/entities/ai_outputs.dart';
import '../domain/enums/output_channel.dart';
import '../../../domain/enums/habit_type.dart';
import '../../../domain/entities/onboarding_survey.dart';

class LocalMessageGenerator implements MessageGenerator {
  @override
  Future<GeneratedMessage> generateMessage(
    MessageContext context,
    OutputChannel targetChannel,
  ) async {
    final isAr = context.currentLanguage == 'ar';
    final stageRaw = context.currentStage.index;

    // Resolve Canonical profile fields into localized strings
    final p = context.profile;

    final primaryIdentity = OnboardingSurvey.getLabel(p.primaryIdentity, isAr);
    final identityToUse = primaryIdentity.isEmpty
        ? (isAr ? 'شخص مركّز' : 'focused person')
        : primaryIdentity;

    final breakTargetCan = p.breakTarget;
    final breakTarget = OnboardingSurvey.getLabel(breakTargetCan, isAr);
    final targetToUse = breakTarget.isEmpty
        ? (isAr ? 'المشتتات' : 'distractions')
        : breakTarget;

    final triggerCan = p.emotionalTrigger;
    final trigger = OnboardingSurvey.getLabel(triggerCan, isAr);
    final emotionToUse = trigger.isEmpty
        ? (isAr ? 'ضعف لحظي' : 'a moment of weakness')
        : trigger;

    final frustration = p.frustrationPoints.isNotEmpty
        ? OnboardingSurvey.getLabel(p.frustrationPoints.first, isAr)
        : '';
    final painPointToUse = frustration.isEmpty
        ? (isAr ? 'الندم بضياع الوقت' : 'the regret of wasted time')
        : frustration;

    final isPhilosophical = p.messageStylePreference == 'philosophical';
    final ignored = context.ignoredWarningCount;
    final isBreakHabitReminder =
        context.contextHabitType == HabitType.breakHabit;
    final appLabel = context.currentAppName?.trim().isNotEmpty == true
        ? context.currentAppName!.trim()
        : (context.currentAppPackage?.trim().isNotEmpty == true
            ? context.currentAppPackage!.trim()
            : (isAr ? 'هذا التطبيق' : 'this app'));
    final disciplineFrame = context.focusModeActive
        ? (isAr
            ? 'أنت في وضع تركيز صارم الآن. '
            : 'You are in strict focus mode now. ')
        : '';
    final recentPressure = context.recentInterventionCount24h >= 3
        ? (isAr
            ? 'لقد واجهت عدة تدخلات اليوم. '
            : 'You have already had several interventions today. ')
        : '';

    // S0 - Expected/Idle/Positive
    if (stageRaw == 0) {
      if (targetChannel == OutputChannel.habitReminder) {
        final taskName =
            context.contextTaskName ?? (isAr ? 'مهمتك' : 'your task');
        return GeneratedMessage(
          headline: isBreakHabitReminder
              ? (isAr
                  ? 'حافظ على الابتعاد عن $taskName'
                  : 'Keep away from $taskName')
              : (isAr
                  ? 'حان وقت إنجاز $taskName!'
                  : 'Time to complete $taskName!'),
          body: isAr
              ? isBreakHabitReminder
                  ? 'أثبت أنك $identityToUse العظيم وواصل مقاومة $taskName. لا تسمح لـ $emotionToUse أن يعيدك إلى هذا السلوك اليوم.'
                  : 'أثبت أنك $identityToUse العظيم وأنجز ما التزمت به. لا تدع $emotionToUse يعيقك عن إتمام $taskName اليوم.'
              : isBreakHabitReminder
                  ? 'Prove you are the great $identityToUse and keep resisting $taskName. Do not let $emotionToUse pull you back into it today.'
                  : 'Prove you are the great $identityToUse and do what you committed to. Don\'t let $emotionToUse delay completing $taskName today.',
          tone: 'motivational',
          channel: targetChannel,
          language: context.currentLanguage,
        );
      }

      if (targetChannel == OutputChannel.missedHabitNudge) {
        final taskName =
            context.contextTaskName ?? (isAr ? 'مهام معلقة' : 'pending tasks');
        return GeneratedMessage(
          headline: isBreakHabitReminder
              ? (isAr ? 'أنهِ اليوم نظيفاً' : 'Finish the day clean')
              : (isAr ? 'راجع مسارك!' : 'Review your path!'),
          body: isAr
              ? isBreakHabitReminder
                  ? 'انتهى اليوم تقريباً. واصل الابتعاد عن $taskName حتى النهاية وأثبت أنك $identityToUse لا يعود إلى $painPointToUse.'
                  : 'انتهى اليوم تقريباً ولديك $taskName بانتظارك. هل تريد الرجوع إلى $painPointToUse أم ستثبت أنك $identityToUse؟'
              : isBreakHabitReminder
                  ? 'The day is almost over. Keep away from $taskName until the finish and prove you are a $identityToUse who does not return to $painPointToUse.'
                  : 'The day is almost over and you still have $taskName waiting. Do you want to return to $painPointToUse or prove you are a $identityToUse?',
          tone: 'strict',
          channel: targetChannel,
          language: context.currentLanguage,
        );
      }

      if (targetChannel == OutputChannel.notification) {
        return GeneratedMessage(
          headline: isAr ? 'استمر بتقدمك!' : 'Keep going!',
          body: isAr
              ? 'أنت تبني هوية $identityToUse العظيمة.'
              : 'You are building the $identityToUse identity.',
          tone: 'encouraging',
          channel: targetChannel,
          language: context.currentLanguage,
        );
      }
      return GeneratedMessage(
        headline: isAr ? 'مسار مستقر' : 'Stable Trajectory',
        body: isAr
            ? 'سجل تشتتك ممتاز. استمر في طريقك لتصبح $identityToUse.'
            : 'Your distraction score is excellent. Stay the course of a $identityToUse.',
        tone: 'encouraging',
        channel: targetChannel,
        reasoningTags: ['S0', 'positive_reinforcement'],
        language: context.currentLanguage,
      );
    }

    // S1 - Gentle Awareness + Identity Reminder
    if (stageRaw == 1) {
      return GeneratedMessage(
        headline: isAr ? 'انتباه' : 'Awareness Check',
        body: targetChannel == OutputChannel.notification
            ? (isAr
                ? '${disciplineFrame}عُد إلى المسار. أنت تهدف لتكون $identityToUse.'
                : '${disciplineFrame}Return to your path. You aim to be a $identityToUse.')
            : (isAr
                ? '${disciplineFrame}تذكر أنك اخترت طريق $identityToUse. البقاء داخل $appLabel الآن لا يخدم هذا المسار. خذ القرار الصحيح.'
                : '${disciplineFrame}Remember you chose the path of a $identityToUse. Staying in $appLabel right now does not serve that path. Make the right call.'),
        tone: isPhilosophical ? 'reflective' : 'gentle',
        actionLabel: isAr ? 'فهمت' : 'Noted',
        channel: targetChannel,
        reasoningTags: ['S1', 'identity_nudge'],
        language: context.currentLanguage,
      );
    }

    // S2 - Reminder + Consequence + Emotion
    if (stageRaw == 2) {
      final ignoredMsg = ignored > 0
          ? (isAr
              ? 'هذا التحذير رقم ${ignored + 1}. '
              : 'Warning ${ignored + 1} ignored. ')
          : '';
      return GeneratedMessage(
        headline: isAr ? 'انحراف مستمر' : 'Sustained Drift',
        body: targetChannel == OutputChannel.notification
            ? (isAr
                ? '$recentPressure$ignoredMsg لا تدع $emotionToUse يسيطر.'
                : '$recentPressure$ignoredMsg Don\'t let $emotionToUse take over.')
            : (isAr
                ? '$recentPressure$ignoredMsg هل تشعر بـ $emotionToUse؟ لا تدع هذه المشاعر تبقيك داخل $appLabel وتعيدك إلى $painPointToUse. دافع عن درعك الآن.'
                : '$recentPressure$ignoredMsg Are you feeling $emotionToUse? Don\'t let this keep you inside $appLabel and pull you back to $painPointToUse. Defend your shield.'),
        tone: 'strict',
        actionLabel: isAr ? 'سأتوقف فوراً' : 'Stopping now',
        channel: targetChannel,
        reasoningTags: ['S2', 'emotional_trigger', 'consequence_framing'],
        language: context.currentLanguage,
      );
    }

    // S3 - Temporary Block / Interruption
    if (stageRaw == 3) {
      return GeneratedMessage(
        headline: isAr ? 'تم إيقاف المشتت' : 'Intervention Triggered',
        body: targetChannel == OutputChannel.notification
            ? (isAr
                ? 'تم التدخل بسبب الاستخدام المفرط.'
                : 'Intervened due to excessive use.')
            : (isAr
                ? 'لقد أجبرناك على التوقف داخل $appLabel. أنت هنا لأنك أردت التخلص من $painPointToUse. هذا الفاصل مصمم لاستعادة وعيك بعيداً عن سيطرة $targetToUse.'
                : 'Force quit initialized inside $appLabel. You are here because you wanted to escape $painPointToUse. This break will restore your awareness away from $targetToUse.'),
        tone: 'severe_but_supportive',
        channel: targetChannel,
        actionLabel: isAr ? 'استرجاع السيطرة' : 'Regain Control',
        reasoningTags: ['S3', 'lock_recovery', 'frustration_point'],
        language: context.currentLanguage,
      );
    }

    // S4 - Monitored Limited-Access
    if (stageRaw == 4) {
      return GeneratedMessage(
        headline: isAr ? 'وصول مقيد ومراقب' : 'Monitored Restraint',
        body: targetChannel == OutputChannel.notification
            ? (isAr
                ? 'النظام يراقب. أثبت سيطرتك واخرج.'
                : 'Monitored. Prove your control and leave.')
            : (isAr
                ? 'تم منحك نافذة وصول أخيرة داخل $appLabel، ولكنك الآن تحت المراقبة. النظام يتحدى قدرتك كـ $identityToUse على اتخاذ قرار طوعي بالإغلاق قبل فوات الأوان.'
                : 'Final access window granted inside $appLabel, but monitored. The system challenges your ability as a $identityToUse to close it voluntarily before it is too late.'),
        tone: 'monitored_guidance',
        channel: targetChannel,
        actionLabel: isAr ? 'الخروج الطوعي' : 'Voluntary Exit',
        reasoningTags: ['S4', 'monitored_prove_identity'],
        language: context.currentLanguage,
      );
    }

    // S5 - Hard Stop + Reset Direction
    return GeneratedMessage(
      headline: isAr ? 'الحظر الشامل' : 'Total Lockdown',
      body: isAr
          ? 'تم إغلاق التطبيق. لقد فقدت السيطرة أمام $targetToUse وتم خصم نقاطك. لا تستسلم لليأس، استخدم هذه اللحظة للبدء في التعافي والتخلص من $painPointToUse.'
          : 'System locked. You lost control to $targetToUse and XP was penalized. Do not despair, use this moment to begin your recovery to escape $painPointToUse.',
      tone: 'punitive_but_restorative',
      channel: targetChannel,
      actionLabel: isAr ? 'بدء إجراء التعافي' : 'Begin Recovery',
      reasoningTags: ['S5', 'hard_lock_reset', 'frustration_point'],
      language: context.currentLanguage,
    );
  }
}
