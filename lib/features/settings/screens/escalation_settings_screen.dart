import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/system_decorative_line.dart';

/// Escalation Settings — values saved to SQLite settings table.
///
/// These settings tune the native escalation engine's timing and intensity.
/// They do NOT override behavior analysis — they only adjust thresholds.
///
/// Abuse prevention: changes apply to FUTURE escalation cycles only.
/// Active punishments (locks) use the policy snapshot frozen at lock creation.
class EscalationSettingsScreen extends StatefulWidget {
  const EscalationSettingsScreen({super.key});

  @override
  State<EscalationSettingsScreen> createState() =>
      _EscalationSettingsScreenState();
}

class _EscalationSettingsScreenState extends State<EscalationSettingsScreen> {
  final SettingsRepository _settingsRepository = SettingsRepository();

  // Defaults match Kotlin DEFAULT_* constants
  double _warningDelay = 3;
  double _overlayDuration = 10;
  double _hardLockDuration = 45;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final warning = await _getSetting('warning_delay');
    final overlay = await _getSetting('overlay_duration');
    final hardLock = await _getSetting('hard_lock_duration');

    if (mounted) {
      setState(() {
        // Clamp to enforced bounds — prevents stale out-of-range values
        _warningDelay = (warning ?? 3).clamp(2, 15);
        _overlayDuration = (overlay ?? 10).clamp(8, 30);
        _hardLockDuration = (hardLock ?? 45).clamp(30, 120);
        _loaded = true;
      });
    }
  }

  Future<double?> _getSetting(String key) async {
    return _settingsRepository.getDouble(key);
  }

  Future<void> _saveSetting(String key, double value) async {
    await _settingsRepository.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SystemBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppStrings.escalationSettings, style: AppTextStyles.h2, overflow: TextOverflow.ellipsis),
                  Text(AppStrings.configureSystemIntervention,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                ])),
              ]).animate().fadeIn().slideY(begin: -0.2),
              const SizedBox(height: 32),

              // Escalation levels
              GlowCard(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.escalationLevels,
                          style: AppTextStyles.h4),
                      const SizedBox(height: 16),
                      ...AppStrings.escalationLevelDescs.map((e) {
                        final parts = e.split('|');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(int.parse(
                                        '0xFF${parts[2].substring(1)}')))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Text(parts[0],
                                    style: AppTextStyles.bodySmall)),
                          ]),
                        );
                      }),
                    ]),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 24),

              if (!_loaded)
                const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primaryBlue))
              else ...[
                // ── Abuse Prevention Notice ──
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2)),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline,
                        color: AppColors.primaryBlue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                      AppStrings.settingsAbuseNotice,
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.textSecondary, fontSize: 11),
                    )),
                  ]),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 16),

                // Warning Delay (2–15 min)
                GlowCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.warningDelay,
                            style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        Text(AppStrings.warningDelayDesc,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Slider(
                            value: _warningDelay,
                            min: 2,
                            max: 15,
                            activeColor: AppColors.primaryBlue,
                            inactiveColor:
                                AppColors.primaryBlue.withOpacity(0.2),
                            onChanged: (v) {
                              setState(() => _warningDelay = v);
                              _saveSetting('warning_delay', v);
                            },
                          )),
                          Text(AppStrings.minUnit(_warningDelay.toInt()),
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.primaryBlue)),
                        ]),
                      ]),
                ).animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 16),

                // Restriction Duration — S3/S4 (8–30 min)
                GlowCard(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.overlayDuration,
                            style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        Text(AppStrings.overlayDurationDesc,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Slider(
                            value: _overlayDuration,
                            min: 8,
                            max: 30,
                            activeColor: AppColors.warning,
                            inactiveColor: AppColors.warning.withOpacity(0.2),
                            onChanged: (v) {
                              setState(() => _overlayDuration = v);
                              _saveSetting('overlay_duration', v);
                            },
                          )),
                          Text(AppStrings.minUnit(_overlayDuration.toInt()),
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.warning)),
                        ]),
                      ]),
                ).animate().fadeIn(delay: 300.ms),

                const SizedBox(height: 16),

                // Strict Lock Duration — S5 only (30–120 min) — only stage with XP penalty
                GlowCard(
                  glowColor: AppColors.danger,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.hardLockDuration,
                            style: AppTextStyles.label),
                        const SizedBox(height: 4),
                        Text(AppStrings.hardLockDurationDesc,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary, fontSize: 11)),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                              child: Slider(
                            value: _hardLockDuration,
                            min: 30,
                            max: 120,
                            activeColor: AppColors.danger,
                            inactiveColor: AppColors.danger.withOpacity(0.2),
                            onChanged: (v) {
                              setState(() => _hardLockDuration = v);
                              _saveSetting('hard_lock_duration', v);
                            },
                          )),
                          Text(AppStrings.minUnit(_hardLockDuration.toInt()),
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.danger)),
                        ]),
                      ]),
                ).animate().fadeIn(delay: 400.ms),
              ],

              const SizedBox(height: 32),
              SystemDecorativeLine(label: AppStrings.escalationEngine),
            ]),
          ),
        ),
      ),
    );
  }
}
