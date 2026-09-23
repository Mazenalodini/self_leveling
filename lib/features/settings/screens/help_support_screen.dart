import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';

/// Help & Support Screen
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                      Text(AppStrings.helpAndSupport, style: AppTextStyles.h2),
                      Row(children: [
                        Container(width: 32, height: 1,
                            color: AppColors.primaryCyan),
                        const SizedBox(width: 8),
                        const Icon(Icons.help_outline,
                            color: AppColors.primaryCyan, size: 12),
                      ]),
                    ],
                  ),
                ]).animate().fadeIn().slideY(begin: -0.2),
              ),
            ),

            const SizedBox(height: 24),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FAQ Section
                    Text(AppStrings.faq,
                        style: AppTextStyles.h3)
                        .animate().fadeIn(delay: 200.ms),
                    const SizedBox(height: 16),

                    _FaqCard(
                      question: AppStrings.faqQ1,
                      answer: AppStrings.faqA1,
                    ).animate().fadeIn(delay: 300.ms),

                    _FaqCard(
                      question: AppStrings.faqQ2,
                      answer: AppStrings.faqA2,
                    ).animate().fadeIn(delay: 400.ms),

                    _FaqCard(
                      question: AppStrings.faqQ3,
                      answer: AppStrings.faqA3,
                    ).animate().fadeIn(delay: 500.ms),

                    _FaqCard(
                      question: AppStrings.faqQ4,
                      answer: AppStrings.faqA4,
                    ).animate().fadeIn(delay: 600.ms),

                    const SizedBox(height: 24),

                    // Contact Section
                    Text(AppStrings.contact, style: AppTextStyles.h3)
                        .animate().fadeIn(delay: 700.ms),
                    const SizedBox(height: 12),

                    GlowCard(
                      glowColor: AppColors.primaryCyan,
                      glowOpacity: 0.1,
                      child: Column(
                        children: [
                          _ContactRow(
                            icon: Icons.email_outlined,
                            label: AppStrings.emailLabel,
                            value: 'support@selfleveling.app',
                          ),
                          const SizedBox(height: 12),
                          _ContactRow(
                            icon: Icons.code,
                            label: AppStrings.versionLabel,
                            value: '1.0.0 Beta',
                          ),
                          const SizedBox(height: 12),
                          _ContactRow(
                            icon: Icons.info_outline,
                            label: AppStrings.licenseLabel,
                            value: 'MIT',
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 800.ms),

                    const SizedBox(height: 24),

                    // About
                    GlowCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.auto_awesome,
                                color: AppColors.primaryBlue, size: 20),
                            const SizedBox(width: 8),
                            Text(AppStrings.aboutApp,
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                )),
                          ]),
                          const SizedBox(height: 12),
                          Text(
                            AppStrings.aboutAppDesc,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 900.ms),
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

class _FaqCard extends StatefulWidget {
  final String question;
  final String answer;

  const _FaqCard({required this.question, required this.answer});

  @override
  State<_FaqCard> createState() => _FaqCardState();
}

class _FaqCardState extends State<_FaqCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _expanded
              ? AppColors.primaryBlue.withOpacity(0.3)
              : AppColors.primaryBlue.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.help_outline,
                    color: _expanded
                        ? AppColors.primaryBlue
                        : AppColors.textTertiary,
                    size: 18,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        color: _expanded
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                widget.answer,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryCyan, size: 18),
        const SizedBox(width: 12),
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textTertiary)),
        const Spacer(),
        Text(value,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            )),
      ],
    );
  }
}
