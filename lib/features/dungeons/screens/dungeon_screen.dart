import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../services/gamification_service.dart';
import '../../../providers/system_provider.dart';

/// Dungeon Screen — تحديات ضد العادات السلبية
class DungeonScreen extends ConsumerStatefulWidget {
  const DungeonScreen({super.key});
  @override
  ConsumerState<DungeonScreen> createState() => _DungeonScreenState();
}

class _DungeonScreenState extends ConsumerState<DungeonScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  final _gamificationService = GamificationService();
  bool _isLoading = true;
  List<_DungeonData> _dungeons = [];
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _loadDungeons();
  }

  Future<void> _loadDungeons() async {
    setState(() => _isLoading = true);
    await _gamificationService.seedDefaultDungeons();
    // Auto-check real usage data for active dungeons
    final autoCompleted = await _gamificationService.autoCheckActiveDungeons();
    final rows = await _gamificationService.getAllDungeons();
    final count = await _gamificationService.getCompletedDungeonCount();

    final list = rows.map((row) {
      List<String> weaknesses = [];
      try { weaknesses = List<String>.from(jsonDecode(row['weaknesses'] as String? ?? '[]')); } catch (_) {}
      return _DungeonData(
        id: row['id'] as String,
        name: row['title'] as String,
        bossName: (row['boss_name'] as String?)?.isNotEmpty == true ? row['boss_name'] as String : row['title'] as String,
        description: row['description'] as String? ?? '',
        icon: _resolveIcon(row['icon_name'] as String? ?? 'dangerous'),
        color: Color(row['color_hex'] as int? ?? 0xFFE11D48),
        durationDays: row['duration_days'] as int? ?? 3,
        currentDay: row['current_day'] as int? ?? 0,
        status: _parseStatus(row['status'] as String? ?? 'available'),
        rewards: row['reward_xp'] as int? ?? 50,
        weaknesses: weaknesses,
        conditionType: row['condition_type'] as String? ?? 'manual',
      );
    }).toList();

    if (mounted) {
      setState(() { _dungeons = list; _completedCount = count; _isLoading = false; });
      // Show toast for auto-completed days
      if (autoCompleted.isNotEmpty) {
        final isAr = AppStrings.isArabic;
        for (final id in autoCompleted) {
          final d = list.where((x) => x.id == id).firstOrNull;
          if (d != null) {
            ref.read(systemProvider.notifier).awardXP(20);
            showAchievementToast(context,
              title: isAr ? 'تقدم تلقائي!' : 'Auto Progress!',
              subtitle: '${d.bossName} — ${isAr ? "تم تأكيد اليوم تلقائياً" : "Day auto-confirmed"}',
              xpEarned: 20, icon: d.icon, color: d.color,
            );
          }
        }
      }
    }
  }

  _DungeonStatus _parseStatus(String s) {
    switch (s) {
      case 'active': return _DungeonStatus.active;
      case 'completed': return _DungeonStatus.defeated;
      case 'failed': return _DungeonStatus.failed;
      default: return _DungeonStatus.available;
    }
  }

  IconData _resolveIcon(String name) {
    const map = {
      'dangerous': Icons.dangerous, 'swipe_down_alt': Icons.swipe_down_alt_rounded,
      'nightlight': Icons.nightlight_round, 'hourglass_empty': Icons.hourglass_empty_rounded,
      'center_focus_strong': Icons.center_focus_strong, 'wb_sunny': Icons.wb_sunny_rounded,
      'phone_android': Icons.phone_android_rounded,
    };
    return map[name] ?? Icons.dangerous;
  }

  String _conditionLabel(String type) {
    final isAr = AppStrings.isArabic;
    switch (type) {
      case 'max_screen_time': return isAr ? 'تقليل وقت الشاشة' : 'Reduce screen time';
      case 'no_phone_after': return isAr ? 'لا هاتف بعد وقت محدد' : 'No phone after set time';
      case 'daily_task': return isAr ? 'إتمام مهمة يومية' : 'Complete daily task';
      case 'focus_session': return isAr ? 'جلسة تركيز يومية' : 'Daily focus session';
      case 'wake_before': return isAr ? 'استيقاظ مبكر' : 'Early wake up';
      default: return isAr ? 'تأكيد يدوي' : 'Manual confirmation';
    }
  }

  void _showStartDialog(_DungeonData dungeon) {
    final isAr = AppStrings.isArabic;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1225),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dungeon.color.withOpacity(0.4), width: 2)),
        title: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dungeon.color.withOpacity(0.15),
              border: Border.all(color: dungeon.color.withOpacity(0.5))),
            child: Icon(dungeon.icon, color: dungeon.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(dungeon.bossName, style: AppTextStyles.h3.copyWith(color: dungeon.color))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dungeon.description, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70)),
          const SizedBox(height: 16),
          // Condition
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: dungeon.color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: dungeon.color.withOpacity(0.2))),
            child: Row(children: [
              Icon(Icons.gps_fixed, color: dungeon.color, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_conditionLabel(dungeon.conditionType),
                style: AppTextStyles.caption.copyWith(color: dungeon.color, fontWeight: FontWeight.w600))),
            ]),
          ),
          const SizedBox(height: 12),
          // Weaknesses
          if (dungeon.weaknesses.isNotEmpty) ...[
            Text(isAr ? '⚔️ نقاط الضعف' : '⚔️ Weaknesses',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            ...dungeon.weaknesses.map((w) => Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(children: [
                Icon(Icons.fiber_manual_record, color: dungeon.color.withOpacity(0.6), size: 6),
                const SizedBox(width: 8),
                Text(w, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ]),
            )),
          ],
          const SizedBox(height: 16),
          // Stats row
          Row(children: [
            Icon(Icons.calendar_today, color: AppColors.textTertiary, size: 14),
            const SizedBox(width: 6),
            Text('${dungeon.durationDays} ${isAr ? "أيام" : "days"}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary)),
            const Spacer(),
            Icon(Icons.stars, color: AppColors.warning, size: 14),
            const SizedBox(width: 6),
            Text('+${dungeon.rewards} XP',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
          ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(isAr ? 'إلغاء' : 'Cancel', style: AppTextStyles.button.copyWith(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: dungeon.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              Navigator.pop(ctx);
              await _gamificationService.startDungeon(dungeon.id);
              await _loadDungeons();
            },
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 4),
              Text(isAr ? 'دخول التحدي' : 'Enter Challenge',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ],
      ),
    );
  }

  void _showActiveDialog(_DungeonData dungeon) async {
    final isAr = AppStrings.isArabic;
    final isAutoTracked = GamificationService.isAutoTrackedType(dungeon.conditionType);
    final alreadyCheckedIn = isAutoTracked ? true : await _gamificationService.hasCheckedInToday(dungeon.id);
    final canCheckIn = !isAutoTracked && !alreadyCheckedIn && dungeon.currentDay < dungeon.durationDays;

    if (!mounted) return;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF12101C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: dungeon.color.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(
            color: AppColors.textTertiary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 52, height: 52,
              decoration: BoxDecoration(shape: BoxShape.circle, color: dungeon.color.withOpacity(0.15),
                border: Border.all(color: dungeon.color.withOpacity(0.5), width: 2)),
              child: Icon(dungeon.icon, color: dungeon.color, size: 26)),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(dungeon.bossName, style: AppTextStyles.h3.copyWith(color: Colors.white)),
              Text('${isAr ? "اليوم" : "Day"} ${dungeon.currentDay}/${dungeon.durationDays}',
                style: AppTextStyles.caption.copyWith(color: dungeon.color)),
            ])),
          ]),
          const SizedBox(height: 20),
          // Progress bar
          ClipRRect(borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: dungeon.durationDays > 0 ? dungeon.currentDay / dungeon.durationDays : 0,
              backgroundColor: AppColors.cardBackground,
              valueColor: AlwaysStoppedAnimation(dungeon.color), minHeight: 10)),
          const SizedBox(height: 12),
          // Auto-tracked info OR manual instruction
          if (isAutoTracked) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dungeon.color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: dungeon.color.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.radar, color: dungeon.color, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  isAr ? 'يتم تتبع هذا التحدي تلقائياً من خلال مراقبة استخدامك' : 'This challenge is auto-tracked by monitoring your usage',
                  style: AppTextStyles.caption.copyWith(color: dungeon.color, fontWeight: FontWeight.w500, fontSize: 11),
                )),
              ]),
            ),
            const SizedBox(height: 8),
            Text(
              isAr ? 'سيتم احتساب يومك تلقائياً عند تحقق الشرط' : 'Your day will be auto-counted when the condition is met',
              style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 10),
            ),
          ] else ...[
            Text(isAr ? 'أكمل يومك وأكّد إنجازك' : 'Complete your day and confirm your progress',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 20),
          // Buttons
          if (isAutoTracked) ...[
            // Auto-tracked: only withdraw button
            SizedBox(width: double.infinity, child: OutlinedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _gamificationService.cancelDungeon(dungeon.id);
                await _loadDungeons();
              },
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger,
                side: BorderSide(color: AppColors.danger.withOpacity(0.3)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.exit_to_app, size: 18),
                const SizedBox(width: 6),
                Text(isAr ? 'انسحاب من التحدي' : 'Withdraw from Challenge',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            )),
          ] else ...[
            // Manual: withdraw + day done
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _gamificationService.cancelDungeon(dungeon.id);
                  await _loadDungeons();
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withOpacity(0.3)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(isAr ? 'انسحاب' : 'Withdraw'),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: canCheckIn ? () async {
                  Navigator.pop(ctx);
                  final isLastDay = dungeon.currentDay + 1 >= dungeon.durationDays;
                  await _gamificationService.completeDungeonDay(dungeon.id);
                  await _loadDungeons();
                  if (mounted) {
                    if (isLastDay) {
                      ref.read(systemProvider.notifier).awardXP(dungeon.rewards);
                      showAchievementToast(context,
                        title: isAr ? 'تحدي مكتمل! 🏆' : 'Challenge Complete! 🏆',
                        subtitle: dungeon.bossName,
                        xpEarned: dungeon.rewards,
                        icon: Icons.emoji_events,
                        color: AppColors.success,
                      );
                    } else {
                      ref.read(systemProvider.notifier).awardXP(20);
                      showAchievementToast(context,
                        title: isAr ? 'يوم مكتمل! ✅' : 'Day Done! ✅',
                        subtitle: '${dungeon.bossName} — ${isAr ? "اليوم" : "Day"} ${dungeon.currentDay + 1}/${dungeon.durationDays}',
                        xpEarned: 20,
                        icon: dungeon.icon,
                        color: dungeon.color,
                      );
                    }
                  }
                } : null,
                style: ElevatedButton.styleFrom(backgroundColor: dungeon.color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: AppColors.cardBackground),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(canCheckIn ? Icons.check_circle : Icons.hourglass_top, size: 18),
                  const SizedBox(width: 6),
                  Text(canCheckIn
                    ? (isAr ? 'أتممت اليوم ✨' : 'Day Done ✨')
                    : (isAr ? 'أُنجز اليوم مسبقاً' : 'Already done today'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
              )),
            ]),
          ],
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = AppStrings.isArabic;
    if (_isLoading) {
      return const Scaffold(backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.danger)));
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(children: [
          // Header
          SafeArea(bottom: false, child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: Row(children: [
              GestureDetector(onTap: () => context.pop(),
                child: Container(padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.cardBackground.withOpacity(0.5)),
                  child: const Icon(Icons.arrow_back, color: AppColors.primaryBlue, size: 24))),
              const SizedBox(width: 16),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isAr ? 'التحديات' : 'Dungeons', style: AppTextStyles.h2),
                Row(children: [
                  Container(width: 32, height: 1, color: AppColors.danger),
                  const SizedBox(width: 8),
                  const Icon(Icons.local_fire_department, color: AppColors.danger, size: 12),
                ]),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.success.withOpacity(0.3))),
                child: Row(children: [
                  const Icon(Icons.emoji_events, color: AppColors.success, size: 14),
                  const SizedBox(width: 4),
                  Text('$_completedCount ${isAr ? "مهزوم" : "defeated"}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600, fontSize: 11)),
                ]),
              ),
            ]).animate().fadeIn().slideY(begin: -0.2),
          )),
          const SizedBox(height: 24),
          // Dungeons List
          Expanded(child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
            itemCount: _dungeons.length,
            itemBuilder: (context, index) {
              final dungeon = _dungeons[index];
              return _DungeonCard(
                dungeon: dungeon, glowController: _glowController,
                onTap: () {
                  if (dungeon.status == _DungeonStatus.active) {
                    _showActiveDialog(dungeon);
                  } else if (dungeon.status == _DungeonStatus.available) {
                    _showStartDialog(dungeon);
                  }
                },
              ).animate(delay: Duration(milliseconds: 200 + index * 100)).fadeIn().slideY(begin: 0.1);
            },
          )),
        ]),
      ),
    );
  }

  @override
  void dispose() { _glowController.dispose(); super.dispose(); }
}

// ═══════════════════════════════════════════
// Dungeon Card
// ═══════════════════════════════════════════
class _DungeonCard extends StatelessWidget {
  final _DungeonData dungeon;
  final AnimationController glowController;
  final VoidCallback onTap;

  const _DungeonCard({required this.dungeon, required this.glowController, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = dungeon.status == _DungeonStatus.active;
    final isDefeated = dungeon.status == _DungeonStatus.defeated;
    final isFailed = dungeon.status == _DungeonStatus.failed;
    final progress = dungeon.durationDays > 0 ? dungeon.currentDay / dungeon.durationDays : 0.0;
    final isAr = AppStrings.isArabic;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDefeated ? AppColors.success.withOpacity(0.04)
              : isFailed ? AppColors.danger.withOpacity(0.03)
              : dungeon.color.withOpacity(isActive ? 0.06 : 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDefeated ? AppColors.success.withOpacity(0.3)
                : isFailed ? AppColors.danger.withOpacity(0.2)
                : dungeon.color.withOpacity(isActive ? 0.4 : 0.15),
            width: isActive ? 2 : 1),
          boxShadow: isActive ? [BoxShadow(color: dungeon.color.withOpacity(0.15), blurRadius: 20)] : null,
        ),
        child: Padding(padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 52, height: 52,
                decoration: BoxDecoration(shape: BoxShape.circle,
                  color: isDefeated ? AppColors.success.withOpacity(0.15) : dungeon.color.withOpacity(0.12),
                  border: Border.all(color: isDefeated ? AppColors.success.withOpacity(0.4) : dungeon.color.withOpacity(0.4))),
                child: Icon(isDefeated ? Icons.check : isFailed ? Icons.close : dungeon.icon,
                  color: isDefeated ? AppColors.success : isFailed ? AppColors.danger : dungeon.color, size: 24)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dungeon.bossName, style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700, fontSize: 15,
                  color: isDefeated ? AppColors.success : isFailed ? AppColors.textTertiary : Colors.white)),
                Text(dungeon.description, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 11)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(dungeon.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _statusColor(dungeon.status).withOpacity(0.4))),
                child: Text(_statusText(dungeon.status),
                  style: AppTextStyles.caption.copyWith(color: _statusColor(dungeon.status), fontWeight: FontWeight.w600, fontSize: 10)),
              ),
            ]),
            if (isActive) ...[
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ClipRRect(borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: progress,
                      backgroundColor: AppColors.cardBackground, valueColor: AlwaysStoppedAnimation(dungeon.color), minHeight: 6)),
                  const SizedBox(height: 4),
                  Text('${isAr ? "اليوم" : "Day"} ${dungeon.currentDay}/${dungeon.durationDays}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
                ])),
                const SizedBox(width: 8),
                if (GamificationService.isAutoTrackedType(dungeon.conditionType))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.radar, color: AppColors.primaryBlue, size: 10),
                      const SizedBox(width: 3),
                      Text(isAr ? 'تلقائي' : 'Auto',
                        style: AppTextStyles.caption.copyWith(color: AppColors.primaryBlue, fontSize: 8, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: dungeon.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Text('+${dungeon.rewards} XP',
                    style: AppTextStyles.caption.copyWith(color: dungeon.color, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ]),
            ],
            if (!isActive && !isDefeated && !isFailed) ...[
              const SizedBox(height: 16),
              Container(width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: dungeon.color.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: dungeon.color.withOpacity(0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.play_arrow_rounded, color: dungeon.color, size: 18),
                  const SizedBox(width: 6),
                  Text('${isAr ? "دخول التحدي" : "Enter Challenge"} • +${dungeon.rewards} XP',
                    style: AppTextStyles.caption.copyWith(color: dungeon.color, fontWeight: FontWeight.w600)),
                ]),
              ),
            ],
            if (isDefeated) ...[
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.emoji_events, color: AppColors.success, size: 16),
                const SizedBox(width: 6),
                Text('${isAr ? "مهزوم" : "Defeated"} • +${dungeon.rewards} XP',
                  style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
              ]),
            ],
          ]),
        ),
      ),
    );
  }

  Color _statusColor(_DungeonStatus status) {
    switch (status) {
      case _DungeonStatus.active: return dungeon.color;
      case _DungeonStatus.available: return AppColors.warning;
      case _DungeonStatus.defeated: return AppColors.success;
      case _DungeonStatus.failed: return AppColors.danger;
    }
  }

  String _statusText(_DungeonStatus status) {
    final isAr = AppStrings.isArabic;
    switch (status) {
      case _DungeonStatus.active: return isAr ? 'نشط' : 'ACTIVE';
      case _DungeonStatus.available: return isAr ? 'متاح' : 'AVAILABLE';
      case _DungeonStatus.defeated: return isAr ? 'مهزوم' : 'DEFEATED';
      case _DungeonStatus.failed: return isAr ? 'فشل' : 'FAILED';
    }
  }
}

// ═══════════════════════════════════════════
// Data
// ═══════════════════════════════════════════
enum _DungeonStatus { active, available, defeated, failed }

class _DungeonData {
  final String id, name, bossName, description, conditionType;
  final IconData icon;
  final Color color;
  final int durationDays, currentDay, rewards;
  final _DungeonStatus status;
  final List<String> weaknesses;

  const _DungeonData({
    required this.id, required this.name, required this.bossName,
    required this.description, required this.icon, required this.color,
    required this.durationDays, required this.currentDay, required this.status,
    required this.rewards, required this.weaknesses, required this.conditionType,
  });
}
