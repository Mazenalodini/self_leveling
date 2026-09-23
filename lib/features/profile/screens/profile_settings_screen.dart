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
import '../../../widgets/system_decorative_line.dart';
import '../../../providers/system_provider.dart';
import '../../../providers/habit_provider.dart';

class ProfileSettingsScreen extends ConsumerStatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  ConsumerState<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends ConsumerState<ProfileSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _identityController;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(systemProvider).profile;
    _nameController = TextEditingController(text: profile.displayName);
    _identityController = TextEditingController(text: profile.identityStatement);
    _nameController.addListener(() => setState(() => _hasChanges = true));
    _identityController.addListener(() => setState(() => _hasChanges = true));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final notifier = ref.read(systemProvider.notifier);
    final name = _nameController.text.trim();
    final identity = _identityController.text.trim();

    if (name.isNotEmpty) {
      await notifier.updateDisplayName(name);
    }
    await notifier.updateIdentity(identity);

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.profileSaved),
          backgroundColor: AppColors.success.withOpacity(0.9),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final system = ref.watch(systemProvider);
    final profile = system.profile;
    final habitState = ref.watch(habitProvider);

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SystemBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                GestureDetector(onTap: () => context.pop(), child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.cardBackground.withOpacity(0.5),
                  ),
                  child: const Icon(Icons.arrow_back, color: AppColors.primaryBlue, size: 24),
                )),
                const SizedBox(width: 16),
                Expanded(child: Text(AppStrings.profileSettings, style: AppTextStyles.h2, overflow: TextOverflow.ellipsis)),
              ]).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 32),

              // Avatar with level badge
              Center(child: Stack(
                children: [
                  Container(
                    width: 96, height: 96,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.primaryBlue.withOpacity(0.4), blurRadius: 24)],
                    ),
                    child: Center(
                      child: Text(
                        profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : 'U',
                        style: AppTextStyles.h1.copyWith(fontSize: 36),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryCyan,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2),
                      ),
                      child: Text('${profile.level}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              )).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.8, 0.8)),
              const SizedBox(height: 32),

              // Editable fields
              InputField(
                label: AppStrings.displayName,
                placeholder: AppStrings.enterYourName,
                controller: _nameController,
              ),
              const SizedBox(height: 20),
              InputField(
                label: AppStrings.identityStatement,
                placeholder: AppStrings.iWantToBecome,
                maxLines: 3,
                controller: _identityController,
              ),

              const SizedBox(height: 24),

              // Save button
              if (_hasChanges)
                GlowButton(
                  text: AppStrings.saveChanges,
                  icon: Icons.save,
                  onPressed: _saveProfile,
                ).animate().fadeIn().slideY(begin: 0.3),

              const SizedBox(height: 24),

              // Real stats card
              GlowCard(
                backgroundOpacity: 0.4, borderOpacity: 0.2,
                child: Column(children: [
                  _InfoRow(label: AppStrings.level, value: '${profile.level}'),
                  const Divider(color: AppColors.cardBackground, height: 24),
                  _InfoRow(label: AppStrings.totalXP, value: '${profile.totalXPEarned}'),
                  const Divider(color: AppColors.cardBackground, height: 24),
                  _InfoRow(label: AppStrings.currentXP, value: '${profile.currentXP} / ${profile.xpForNextLevel}'),
                  const Divider(color: AppColors.cardBackground, height: 24),
                  _InfoRow(label: AppStrings.activeHabits, value: '${habitState.totalCount}'),
                  const Divider(color: AppColors.cardBackground, height: 24),
                  _InfoRow(label: AppStrings.selfControl, value: '${profile.selfControlScore}%'),
                ]),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 32),
              SystemDecorativeLine(label: AppStrings.profileSystem),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
      Text(value, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
    ]);
  }
}
