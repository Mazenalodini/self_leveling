import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:installed_apps/app_info.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../domain/entities/report_models.dart';
import '../../../providers/report_provider.dart';
import '../../../providers/system_provider.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/system_background.dart';
import '../services/app_info_cache_service.dart';

class UsageDashboardScreen extends ConsumerStatefulWidget {
  const UsageDashboardScreen({super.key});

  @override
  ConsumerState<UsageDashboardScreen> createState() =>
      _UsageDashboardScreenState();
}

class _UsageDashboardScreenState extends ConsumerState<UsageDashboardScreen>
    with WidgetsBindingObserver {
  String _sortBy = 'time';
  UsagePeriod _period = UsagePeriod.today;
  String _iconPrefetchSignature = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(ref.read(appInfoCacheProvider).warmCatalog());
    unawaited(_refreshUsageData());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshUsageData());
  }

  Future<void> _refreshUsageData() async {
    await ref.read(behaviorServiceProvider).refreshTodayUsage(
          days: switch (_period) {
            UsagePeriod.today => 1,
            UsagePeriod.week => 7,
            UsagePeriod.month => 30,
          },
        );
    if (!mounted) return;
    ref.read(reportRefreshVersionProvider.notifier).markDirty();
  }

  void _prefetchVisibleIcons(
    AppInfoCacheService appInfoCache,
    List<UsageAppSummary> apps,
  ) {
    final signature = apps
        .take(40)
        .map((app) => app.packageName)
        .where((packageName) => packageName.isNotEmpty)
        .join('|');

    if (signature.isEmpty || signature == _iconPrefetchSignature) {
      return;
    }

    _iconPrefetchSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        appInfoCache.prefetchPackages(
          apps.take(40).map((app) => app.packageName),
        ),
      );
    });
  }

  List<UsageAppSummary> _sortedApps(List<UsageAppSummary> apps) {
    final sorted = List<UsageAppSummary>.from(apps);
    switch (_sortBy) {
      case 'name':
        sorted.sort(
          (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
        );
        break;
      case 'category':
        sorted.sort((a, b) {
          final catCmp = a.category.index.compareTo(b.category.index);
          if (catCmp != 0) return catCmp;
          return b.durationSeconds.compareTo(a.durationSeconds);
        });
        break;
      case 'time':
      default:
        sorted.sort((a, b) => b.durationSeconds.compareTo(a.durationSeconds));
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(usageReportProvider(_period));
    final appInfoCache = ref.watch(appInfoCacheProvider);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.cardBackground.withOpacity(0.5),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppColors.primaryBlue,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.usageDashboard,
                            style: AppTextStyles.h2,
                          ),
                          Row(
                            children: [
                              Container(
                                width: 32,
                                height: 1,
                                color: AppColors.primaryCyan,
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.analytics,
                                color: AppColors.primaryCyan,
                                size: 12,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ).animate().fadeIn().slideY(begin: -0.2),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: reportAsync.when(
                loading: () => const Center(
                  child:
                      CircularProgressIndicator(color: AppColors.primaryBlue),
                ),
                error: (_, __) => _buildErrorState(),
                data: (report) {
                  final sortedApps = _sortedApps(report.apps);
                  _prefetchVisibleIcons(appInfoCache, sortedApps);

                  if (sortedApps.isEmpty) {
                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPeriodSelector(),
                                const SizedBox(height: 16),
                                _buildSummaryRow(report),
                                const SizedBox(height: 20),
                                _buildListHeader(),
                                const SizedBox(height: 12),
                                GlowCard(
                                  glowOpacity: 0.05,
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Text(
                                      AppStrings.noDataYet,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.textTertiary,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return CustomScrollView(
                    cacheExtent: 800,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                        sliver: SliverToBoxAdapter(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildPeriodSelector(),
                              const SizedBox(height: 16),
                              _buildSummaryRow(report),
                              const SizedBox(height: 20),
                              _buildDistributionCard(
                                  report, sortedApps, appInfoCache),
                              const SizedBox(height: 20),
                              _buildListHeader(),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
                        sliver: SliverList.builder(
                          itemCount: sortedApps.length,
                          itemBuilder: (context, index) {
                            final app = sortedApps[index];
                            final maxDuration = sortedApps.first.durationSeconds;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _buildAppCard(
                                app,
                                appInfoCache.infoFor(app.packageName),
                                maxDuration: maxDuration,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: GlowCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            AppStrings.usageAccessError,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Row(
      children: [
        _buildPeriodChip(AppStrings.todayLabel, UsagePeriod.today),
        const SizedBox(width: 8),
        _buildPeriodChip(AppStrings.weekLabel, UsagePeriod.week),
        const SizedBox(width: 8),
        _buildPeriodChip(AppStrings.monthLabel, UsagePeriod.month),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildSummaryRow(UsageReport report) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.access_time,
            label: AppStrings.totalTime,
            value: _formatDurationFromSeconds(report.totalDurationSeconds),
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.apps,
            label: AppStrings.appsUsed,
            value: '${report.totalApps}',
            color: AppColors.primaryCyan,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SummaryCard(
            icon: Icons.trending_up,
            label: AppStrings.topApp,
            value: report.topAppName != null
                ? _shortName(report.topAppName!)
                : '-',
            color: const Color(0xFF8B5CF6),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildDistributionCard(
    UsageReport report,
    List<UsageAppSummary> sortedApps,
    AppInfoCacheService appInfoCache,
  ) {
    return GlowCard(
      glowOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart,
                color: AppColors.primaryBlue,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                AppStrings.usageDistribution,
                style: AppTextStyles.label,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...sortedApps.take(5).map((app) {
            final percent = report.totalDurationSeconds > 0
                ? app.durationSeconds / report.totalDurationSeconds
                : 0.0;
            final appInfo = appInfoCache.infoFor(app.packageName);
            final color = _getAppColor(appInfo?.name ?? app.appName);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 88,
                    child: Row(
                      children: [
                        _AppAvatar(
                          packageName: app.packageName,
                          appName: app.appName,
                          color: color,
                          appInfo: appInfo,
                          size: 24,
                          borderRadius: 8,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _shortName(appInfo?.name ?? _displayNameFor(app)),
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percent.clamp(0.0, 1.0),
                          child: Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(7),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withOpacity(0.3),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 42,
                    child: Text(
                      '${(percent * 100).toInt()}%',
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildListHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.allApps, style: AppTextStyles.h3),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildSortChip(
              Icons.access_time,
              'time',
              AppStrings.timeSort,
            ),
            const SizedBox(width: 6),
            _buildSortChip(
              Icons.sort_by_alpha,
              'name',
              AppStrings.nameSort,
            ),
            const SizedBox(width: 6),
            _buildSortChip(
              Icons.category_outlined,
              'category',
              AppStrings.habits,
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildPeriodChip(String label, UsagePeriod period) {
    final selected = _period == period;
    return GestureDetector(
      onTap: () {
        setState(() => _period = period);
        unawaited(_refreshUsageData());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withOpacity(0.12)
              : AppColors.cardBackground.withOpacity(0.4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? AppColors.primaryBlue.withOpacity(0.35)
                : AppColors.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: selected ? AppColors.primaryBlue : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(IconData icon, String sortKey, String label) {
    final selected = _sortBy == sortKey;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = sortKey),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryCyan.withOpacity(0.1)
              : AppColors.cardBackground.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.primaryCyan.withOpacity(0.35)
                : AppColors.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: selected ? AppColors.primaryCyan : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color:
                    selected ? AppColors.primaryCyan : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(UsageAppSummary app, AppInfo? appInfo, {int maxDuration = 1}) {
    final color = _getAppColor(appInfo?.name ?? app.appName);
    final progress = maxDuration > 0 ? app.durationSeconds / maxDuration : 0.0;
    return GlowCard(
      glowOpacity: 0.05,
      child: Column(
        children: [
          Row(
            children: [
              _AppAvatar(
                packageName: app.packageName,
                appName: app.appName,
                color: color,
                appInfo: appInfo,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appInfo?.name ?? _displayNameFor(app),
                      style: AppTextStyles.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.packageName,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary,
                              fontSize: 10,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (app.launchCount > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${app.launchCount} ${AppStrings.opensLabel}',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _formatDurationFromSeconds(app.durationSeconds),
                            style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w600,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
              backgroundColor: color.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDurationFromSeconds(int seconds) {
    if (seconds > 0 && seconds < 60) return '<1m';
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours == 0) return '${duration.inMinutes}m';
    if (minutes == 0) return '${hours}h';
    return '${hours}h ${minutes}m';
  }

  String _shortName(String name) {
    if (name.length <= 10) return name;
    return '${name.substring(0, 10)}…';
  }

  String _displayNameFor(UsageAppSummary app) {
    if (app.appName.trim().isNotEmpty && app.appName != app.packageName) {
      return app.appName;
    }
    final segments = app.packageName.split('.');
    return segments.isNotEmpty ? segments.last : app.packageName;
  }

  Color _getAppColor(String appName) {
    final lower = appName.toLowerCase();
    if (lower.contains('instagram') || lower.contains('tiktok')) {
      return AppColors.danger;
    }
    if (lower.contains('youtube') || lower.contains('netflix')) {
      return AppColors.warning;
    }
    return AppColors.primaryBlue;
  }
}

class _AppAvatar extends StatelessWidget {
  final String packageName;
  final String appName;
  final Color color;
  final AppInfo? appInfo;
  final double size;
  final double borderRadius;

  const _AppAvatar({
    required this.packageName,
    required this.appName,
    required this.color,
    required this.appInfo,
    this.size = 40,
    this.borderRadius = 10,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedName = appInfo?.name.trim() ?? '';
    final initialSource = resolvedName.isNotEmpty
        ? resolvedName
        : appName.trim().isNotEmpty
            ? appName.trim()
            : packageName;
    final initial = initialSource.isNotEmpty
        ? String.fromCharCode(initialSource.runes.first).toUpperCase()
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        color: color.withOpacity(0.12),
      ),
      child: appInfo?.icon != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.memory(appInfo!.icon!, fit: BoxFit.cover),
            )
          : Center(
              child: Text(
                initial,
                style: AppTextStyles.bodySmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowOpacity: 0.08,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(value, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
