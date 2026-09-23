import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../providers/locale_provider.dart';

/// Language Settings — تبديل اللغة
class LanguageSettingsScreen extends ConsumerStatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  ConsumerState<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends ConsumerState<LanguageSettingsScreen> {
  final List<_LangOption> _languages = [
    _LangOption('en', 'English', 'English', '🇺🇸'),
    _LangOption('ar', 'العربية', 'Arabic', '🇸🇦'),
  ];

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final currentLang = locale.languageCode;
    final s = S.of(ref);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
            // Header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.cardBackground.withOpacity(0.5),
                      ),
                      child: const Icon(Icons.arrow_back,
                          color: AppColors.primaryBlue, size: 24),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.language, style: AppTextStyles.h2),
                      Row(children: [
                        Container(width: 32, height: 1,
                            color: AppColors.primaryCyan),
                        const SizedBox(width: 8),
                        const Icon(Icons.language,
                            color: AppColors.primaryCyan, size: 12),
                      ]),
                    ],
                  ),
                ]).animate().fadeIn().slideY(begin: -0.2),
              ),
            ),

            const SizedBox(height: 24),

            // Language options
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.selectLanguage,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary))
                        .animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),

                    ...List.generate(_languages.length, (index) {
                      final lang = _languages[index];
                      final isSelected = currentLang == lang.code;
                      return GestureDetector(
                        onTap: () {
                          ref.read(localeProvider.notifier).setLocale(lang.code);
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primaryBlue.withOpacity(0.08)
                                : AppColors.cardBackground.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryBlue.withOpacity(0.4)
                                  : AppColors.primaryBlue.withOpacity(0.1),
                              width: isSelected ? 1.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.primaryBlue
                                          .withOpacity(0.15),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Flag
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryBlue.withOpacity(0.1)
                                      : AppColors.cardBackground
                                          .withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(lang.flag,
                                      style: const TextStyle(fontSize: 24)),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      lang.nativeName,
                                      style:
                                          AppTextStyles.bodySmall.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      lang.englishName,
                                      style:
                                          AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Check icon
                              AnimatedContainer(
                                duration:
                                    const Duration(milliseconds: 200),
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primaryBlue
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primaryBlue
                                        : AppColors.textTertiary,
                                    width: 1.5,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check,
                                        color: Colors.white, size: 16)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(
                          delay: Duration(milliseconds: 300 + index * 100));
                    }),

                    const SizedBox(height: 24),

                    // Info note
                    GlowCard(
                      glowOpacity: 0.05,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline,
                              color: AppColors.primaryCyan, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.languageChangeNote,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LangOption {
  final String code;
  final String nativeName;
  final String englishName;
  final String flag;

  _LangOption(this.code, this.nativeName, this.englishName, this.flag);
}
