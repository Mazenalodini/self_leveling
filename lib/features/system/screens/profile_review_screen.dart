import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/glow_button.dart';
import '../../../widgets/system_decorative_line.dart';
import '../../../core/utils/feedback_utils.dart';
import '../../../navigation/app_router.dart';

import '../../../domain/entities/user_profile.dart';
import '../../../domain/entities/onboarding_survey.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/user_profile_repository.dart';
import '../../../providers/app_init_provider.dart';
import '../../../providers/locale_provider.dart';

class ProfileReviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> answers;
  final Map<String, String> otherTexts;
  final String surveyLanguage;

  const ProfileReviewScreen({
    super.key,
    required this.answers,
    required this.otherTexts,
    required this.surveyLanguage,
  });

  @override
  ConsumerState<ProfileReviewScreen> createState() =>
      _ProfileReviewScreenState();
}

class _ProfileReviewScreenState extends ConsumerState<ProfileReviewScreen> {
  bool _isSaving = false;

  Future<void> _finalizeSetup() async {
    setState(() => _isSaving = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final profileRepo = ref.read(userProfileRepositoryProvider);

      final uid = await authRepo.getCurrentUserId();
      if (uid == null) throw Exception("User not authenticated.");

      // Construct final profile
      final user = authRepo.currentUser;
      final newProfile = UserProfile(
        id: UserProfile.canonicalLocalId,
        accountUid: uid,
        displayName: user?.displayName ?? 'Agent',
        email: user?.email,
        createdAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        installReason: _getCanonical('installReason'),
        occupation: _getCanonical('occupation'),
        primaryIdentity: _getCanonical('primaryIdentity'),
        frustrationPoints: _getCanonicalList('frustrationPoints'),
        distractionCategories: _getCanonicalList('distractionCategories'),
        weaknessWindow: _getCanonical('weaknessWindow'),
        emotionalTrigger: _getCanonical('emotionalTrigger'),
        targetHabits: _getCanonicalList('targetHabits'),
        breakTarget: _getCanonical('breakTarget'),
        strictnessPreference: _getCanonical('strictnessPreference'),
        messageStylePreference: _getCanonical('messageStylePreference'),
        interventionPreference: _getCanonical('interventionPreference'),
        preferredHabitSize: _getCanonical('preferredHabitSize'),
        openReflections: widget.otherTexts,
        surveyLanguage: widget.surveyLanguage,
      );

      await profileRepo.saveProfile(newProfile);

      // Tell appInitProvider that onboarding is done
      await ref.read(appInitProvider.notifier).completeOnboarding();

      // Because AppInitNotifier immediately updates state and BootScreen routing changes
      // or we just manually route since we are not in BootScreen.
      // Wait, we should just route to Permissions. No, let appRouter/boot handle it or we push to Setup.
      if (mounted) context.go(RoutePaths.setup);
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, 'Error saving profile: $e');
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _getCanonical(String key) {
    var val = widget.answers[key]?.toString() ?? '';
    // If it was Other, check otherTexts
    if (val == 'other' || val == 'Other') {
      return widget.otherTexts[key] ?? val;
    }
    return val;
  }

  List<String> _getCanonicalList(String key) {
    var list = widget.answers[key] as List<dynamic>? ?? [];
    return list.map((item) {
      if (item == 'other' || item == 'Other') {
        return widget.otherTexts[key] ?? item.toString();
      }
      return item.toString();
    }).toList();
  }

  String _getDisplayLabel(String key, bool isAr) {
    final canonical = _getCanonical(key);
    // Since 'otherTexts' bypass OnboardingSurvey constants natively if it's 'other', it will fall back to the raw string
    return OnboardingSurvey.getLabel(canonical, isAr);
  }

  String _getDisplayList(String key, bool isAr) {
    final list = _getCanonicalList(key);
    return list.map((id) => OnboardingSurvey.getLabel(id, isAr)).join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';

    return Scaffold(
      body: SystemBackground(
        particleCount: 15,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: Column(
                      children: [
                        GlowCard(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.3)),
                                    boxShadow: [
                                      BoxShadow(
                                          color: AppColors.primaryBlue
                                              .withOpacity(0.3),
                                          blurRadius: 20)
                                    ],
                                  ),
                                  child: const Icon(Icons.fingerprint,
                                      color: AppColors.primaryBlue, size: 32),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Text(
                                    isAr
                                        ? 'تمت المعايرة'
                                        : 'Profile Calibrated',
                                    style: AppTextStyles.h2),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  isAr
                                      ? 'هكذا يفهمك النظام الآن.'
                                      : 'This is how the system understands you.',
                                  style: AppTextStyles.secondaryText,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _buildProfileRow(
                                  isAr ? 'الهوية:' : 'Identity Target:',
                                  _getDisplayLabel('primaryIdentity', isAr)),
                              _buildProfileRow(isAr ? 'الدور:' : 'Role:',
                                  _getDisplayLabel('occupation', isAr)),
                              _buildProfileRow(
                                  isAr ? 'عادات مرجوة:' : 'Must Form:',
                                  _getDisplayList('targetHabits', isAr)),
                              _buildProfileRow(
                                  isAr ? 'عادة للكسر:' : 'Must Break:',
                                  _getDisplayLabel('breakTarget', isAr)),
                              _buildProfileRow(
                                  isAr ? 'صوت المحرك:' : 'Engine Voice:',
                                  _getDisplayLabel(
                                      'messageStylePreference', isAr)),
                              _buildProfileRow(
                                  isAr ? 'حساسية النظام:' : 'Strictness:',
                                  _getDisplayLabel(
                                      'strictnessPreference', isAr)),
                            ],
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),
                        const SizedBox(height: 32),
                        SystemDecorativeLine(
                                label:
                                    isAr ? 'تهيئة النظام' : 'INITIALIZE SYSTEM')
                            .animate()
                            .fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _isSaving
                    ? const CircularProgressIndicator()
                    : GlowButton(
                        text: isAr
                            ? 'تأكيد وإعداد الصلاحيات'
                            : 'Confirm & Setup Permissions',
                        onPressed: _finalizeSetup,
                      ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.primaryBlue)),
          const SizedBox(height: 4),
          Text(value.isEmpty ? '-' : value,
              style: AppTextStyles.bodyMedium
                  .copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
