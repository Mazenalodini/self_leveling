import 'dart:math';
import '../domain/interfaces/recommendation_engine.dart';
import '../domain/entities/ai_contexts.dart';
import '../domain/entities/ai_outputs.dart';
import '../domain/enums/action_type.dart';
import '../../../domain/enums/escalation_level.dart';

class LocalRecommendationEngine implements RecommendationEngine {
  
  @override
  Future<RecommendationResult> getBestAction(RecommendationContext context) async {
    final isAr = context.currentLanguage == 'ar';
    final stageRaw = context.currentStage.index; 

    // Rule 1: Extreme Crisis (S5) - Hard Lock Recovery
    if (stageRaw == 5) {
      return RecommendationResult(
        actionType: ActionType.systemRecovery,
        title: isAr ? 'إجراء طارئ' : 'Emergency Action',
        subtitle: isAr ? 'أغلق شاشة الهاتف، وقم بالمشي لـ ٥ دقائق لكسر الدائرة.' : 'Lock your screen and walk for 5 minutes to break the loop.',
        confidenceScore: 1.0,
        reasoningTags: ['S5_hard_lock', 'physiological_break'],
      );
    }

    // Rule 2: Monitored Control (S4)
    if (stageRaw == 4) {
      return RecommendationResult(
        actionType: ActionType.stepAway,
        title: isAr ? 'تحدي المراقبة' : 'Monitored Challenge',
        subtitle: isAr ? 'تعمد إرجاع الهاتف إلى جيبك فوراً كدليل على السيطرة.' : 'Voluntarily put your phone in your pocket to prove control.',
        confidenceScore: 0.95,
        reasoningTags: ['S4_monitored_test', 'voluntary_exit'],
      );
    }

    // Rule 3: Forced Break (S3)
    if (stageRaw == 3) {
      return RecommendationResult(
        actionType: ActionType.stepAway,
        title: isAr ? 'تنفس عميق' : 'Deep Breathing',
        subtitle: isAr ? 'خذ ٥ أنفاس عميقة ومدروسة أثناء هذا الإيقاف لإعادة ضبط تفكيرك.' : 'Take 5 slow deep breaths during this pause to reset your mind.',
        confidenceScore: 0.9,
        reasoningTags: ['S3_interruption', 'mindfulness_reset'],
      );
    }

    // Rule 4: Escalating Warning (S2)
    // Needs a strong pivot, ideally a habit, but framed sternly
    if (stageRaw == 2) {
      if (context.pendingHabits.isNotEmpty) {
        final target = context.pendingHabits.first;
        return RecommendationResult(
          actionType: ActionType.pendingHabit,
          targetId: target.id,
          title: isAr ? 'الفرار للمهمة القادمة' : 'Escape to Pivot',
          subtitle: isAr ? 'اهرب الآن وابدأ بـ: ${target.name}' : 'Escape now and start: ${target.name}',
          confidenceScore: 0.85,
          reasoningTags: ['S2_pivot', 'urgent_habit_switch'],
        );
      } else {
        return RecommendationResult(
          actionType: ActionType.microPivot,
          title: isAr ? 'إغلاق فوري' : 'Immediate Close',
          subtitle: isAr ? 'أغلق التطبيق لتجنب الإجراء الإجباري القادم.' : 'Close the app now to prevent a forced lock.',
          confidenceScore: 0.8,
          reasoningTags: ['S2_warning', 'prevent_s3'],
        );
      }
    }

    // Rule 5: Gentle Awareness (S1)
    if (stageRaw == 1) {
      if (context.pendingHabits.isNotEmpty) {
        final target = context.pendingHabits.first;
        return RecommendationResult(
          actionType: ActionType.pendingHabit,
          targetId: target.id,
          title: isAr ? 'الخطوة الأفضل' : 'Next Best Step',
          subtitle: isAr ? 'توجيه انتباهك إلى: ${target.name}' : 'Direct your focus to: ${target.name}',
          confidenceScore: 0.85,
          reasoningTags: ['S1_gentle_pivot', 'habit_suggestion'],
        );
      } else {
        return RecommendationResult(
          actionType: ActionType.microPivot,
          title: isAr ? 'مراجعة للمسار' : 'Path Check',
          subtitle: isAr ? 'توقف لثانية واسأل نفسك: هل أستفيد الآن؟' : 'Pause for a second: Is this benefiting you?',
          confidenceScore: 0.7,
          reasoningTags: ['S1_awareness_prompt'],
        );
      }
    }

    // Rule 6: Idle / Neutral (S0)
    if (context.pendingHabits.isNotEmpty) {
       final target = context.pendingHabits.first;
       return RecommendationResult(
          actionType: ActionType.pendingHabit,
          targetId: target.id,
          title: isAr ? 'التالي: ${target.name}' : 'Up next: ${target.name}',
          confidenceScore: 0.8,
          reasoningTags: ['neutral_state_suggestion'],
        );
    }

    return RecommendationResult(
      actionType: ActionType.startFocusSession,
      title: isAr ? 'ابدأ جلسة تركيز' : 'Start Focus Session',
      subtitle: isAr ? 'حافظ على مسارك الصحيح' : 'Keep on the right track',
      confidenceScore: 0.5,
      reasoningTags: ['default_fallback'],
    );
  }
}
