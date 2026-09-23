import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/app_picker_dialog.dart';
import '../../../services/app_list_service.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:installed_apps/app_info.dart';

/// Usage Limits — wired to SQLite via AppListService.
class UsageLimitsScreen extends StatefulWidget {
  const UsageLimitsScreen({super.key});

  @override
  State<UsageLimitsScreen> createState() => _UsageLimitsScreenState();
}

class _UsageLimitsScreenState extends State<UsageLimitsScreen> {
  final _service = AppListService();
  List<Map<String, dynamic>> _limits = [];
  Map<String, AppInfo> _appInfoMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLimits();
  }

  Future<void> _loadLimits() async {
    final data = await _service.getAppsWithLimits();

    if (_appInfoMap.isEmpty) {
      try {
        final apps = await InstalledApps.getInstalledApps(true, true, '');
        _appInfoMap = {for (var a in apps) a.packageName: a};
      } catch (e) {
        // Ignore error if it fails to load apps
      }
    }

    if (mounted)
      setState(() {
        _limits = data;
        _isLoading = false;
      });
  }

  void _showAddLimitDialog() async {
    // Step 1: Pick an app from installed apps
    final selectedApp = await showAppPicker(
      context,
      title: AppStrings.selectAppForLimit,
    );
    if (selectedApp == null || !mounted) return;

    // Step 2: Set the time limit
    double minutes = 30;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.background,
          title: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: AppColors.warning.withOpacity(0.1),
              ),
              child: selectedApp.icon != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(selectedApp.icon!, fit: BoxFit.cover),
                    )
                  : const Icon(Icons.timer, color: AppColors.warning, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(selectedApp.name, style: AppTextStyles.h4)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.setDailyUsageLimit,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              Row(children: [
                Text(AppStrings.limitLabel, style: AppTextStyles.caption),
                Expanded(
                  child: Slider(
                    value: minutes < 2 ? 2 : minutes,
                    min: 2,
                    max: 182,
                    divisions: 90,
                    activeColor: AppColors.warning,
                    onChanged: (v) => setDialogState(() => minutes = v),
                  ),
                ),
                Text(AppStrings.minUnit(minutes.toInt()),
                    style:
                        AppTextStyles.label.copyWith(color: AppColors.warning)),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(AppStrings.cancel,
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, minutes.toInt()),
              child: Text(AppStrings.setLimitBtn,
                  style: const TextStyle(color: AppColors.primaryBlue)),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;

    await _service.addApp(
      name: selectedApp.name,
      packageName: selectedApp.packageName,
      listType: 'limit',
      dailyLimitMinutes: result,
      tag: AppStrings.usageLimitTag,
    );
    _loadLimits();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
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
                      Text(AppStrings.usageLimits, style: AppTextStyles.h2),
                      Row(children: [
                        Container(
                            width: 32, height: 1, color: AppColors.warning),
                        const SizedBox(width: 8),
                        const Icon(Icons.timer,
                            color: AppColors.warning, size: 12),
                      ]),
                    ],
                  ),
                ]).animate().fadeIn().slideY(begin: -0.2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primaryBlue))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Per-app limits header
                          Row(children: [
                            Text(AppStrings.perAppLimits,
                                style: AppTextStyles.h3),
                            const Spacer(),
                            Text(AppStrings.activeCount(_limits.length),
                                style: AppTextStyles.caption.copyWith(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w500,
                                )),
                          ]).animate().fadeIn(delay: 200.ms),

                          const SizedBox(height: 12),

                          if (_limits.isEmpty)
                            GlowCard(
                              glowOpacity: 0.05,
                              child: Column(children: [
                                const Icon(Icons.timer_off,
                                    color: AppColors.textTertiary, size: 36),
                                const SizedBox(height: 12),
                                Text(AppStrings.noLimitsSetYet,
                                    style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textTertiary)),
                                const SizedBox(height: 4),
                                Text(AppStrings.tapToAddLimit,
                                    style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textTertiary)),
                              ]),
                            ).animate().fadeIn(delay: 300.ms),

                          ...List.generate(_limits.length, (index) {
                            return _buildLimitCard(_limits[index], index);
                          }),

                          const SizedBox(height: 12),

                          // Add button
                          GestureDetector(
                            onTap: _showAddLimitDialog,
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color:
                                        AppColors.primaryBlue.withOpacity(0.2)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline,
                                      color: AppColors.primaryBlue
                                          .withOpacity(0.5),
                                      size: 20),
                                  const SizedBox(width: 8),
                                  Text(AppStrings.addAppLimit,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.primaryBlue
                                            .withOpacity(0.5),
                                      )),
                                ],
                              ),
                            ),
                          ).animate().fadeIn(
                              delay: Duration(
                                  milliseconds: 350 + _limits.length * 80)),

                          const SizedBox(height: 16),

                          // Info card
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
                                    AppStrings.limitExceedWarning,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(
                              delay: Duration(
                                  milliseconds: 400 + _limits.length * 80)),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitCard(Map<String, dynamic> limit, int index) {
    final name = limit['name'] as String;
    final packageName = limit['package_name'] as String? ?? '';
    final minutes = limit['daily_limit_minutes'] as int;
    final enabled = (limit['is_enabled'] as int?) == 1;
    final id = limit['id'] as int;
    final color = AppColors.warning;
    final appInfo = _appInfoMap[packageName];

    return Dismissible(
      key: Key('limit_$id'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.danger.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: AppColors.danger),
      ),
      onDismissed: (_) async {
        await _service.deleteApp(id);
        _loadLimits();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled
              ? color.withOpacity(0.04)
              : AppColors.cardBackground.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.2)
                : AppColors.primaryBlue.withOpacity(0.08),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: appInfo?.icon != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child:
                              Image.memory(appInfo!.icon!, fit: BoxFit.cover),
                        )
                      : Icon(Icons.timer, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(name,
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: enabled ? Colors.white : AppColors.textTertiary,
                      )),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(AppStrings.minUnit(minutes),
                      style: AppTextStyles.caption.copyWith(
                        color: enabled ? color : AppColors.textTertiary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      )),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: enabled,
                  onChanged: (v) async {
                    await _service.toggleApp(id, v);
                    _loadLimits();
                  },
                  activeColor: color,
                  activeTrackColor: color.withOpacity(0.3),
                  inactiveThumbColor: AppColors.textTertiary,
                  inactiveTrackColor: AppColors.cardBackground,
                ),
              ],
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withOpacity(0.12),
                  thumbColor: color,
                  overlayColor: color.withOpacity(0.08),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: (minutes < 2 ? 2 : minutes).toDouble(),
                  min: 2,
                  max: 182,
                  divisions: 90,
                  onChanged: (v) async {
                    await _service.updateLimit(id, v.toInt());
                    _loadLimits();
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 350 + index * 80));
  }
}
