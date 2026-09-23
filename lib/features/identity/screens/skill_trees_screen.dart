import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/system_background.dart';
import '../../../widgets/glow_card.dart';
import '../../../widgets/input_field.dart';
import '../../../widgets/achievement_overlay.dart';
import '../../../services/gamification_service.dart';
import '../../../providers/system_provider.dart';

/// Skill Trees Screen — شجرة المهارات لكل هوية
class SkillTreesScreen extends ConsumerStatefulWidget {
  const SkillTreesScreen({super.key});

  @override
  ConsumerState<SkillTreesScreen> createState() => _SkillTreesScreenState();
}

class _SkillTreesScreenState extends ConsumerState<SkillTreesScreen> {
  int _selectedIdentity = 0;
  final _gamificationService = GamificationService();
  bool _isLoading = true;
  List<_IdentityTree> _trees = [];
  Map<String, List<_SkillNode>> _dbSkills = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final identityRows = await _gamificationService.getIdentities();
    if (identityRows.isEmpty) {
      if (mounted) setState(() { _trees = []; _isLoading = false; });
      return;
    }

    final newTrees = <_IdentityTree>[];
    final newDbSkills = <String, List<_SkillNode>>{};

    for (var row in identityRows) {
      final title = row['title'] as String;
      final iconCode = row['icon_code'] as int? ?? Icons.star.codePoint;
      final colorHex = row['color_hex'] as int? ?? AppColors.primaryBlue.value;

      final skillRows = await _gamificationService.getSkills(title);

      // Auto-seed if empty
      if (skillRows.isEmpty) {
        await _gamificationService.saveIdentities([row]);
        final freshSkills = await _gamificationService.getSkills(title);
        newDbSkills[title] = freshSkills.map(_mapSkill).toList();
      } else {
        newDbSkills[title] = skillRows.map(_mapSkill).toList();
      }

      // Ensure first skill is always unlocked
      await _gamificationService.ensureFirstSkillUnlocked(title);

      newTrees.add(_IdentityTree(
        name: title,
        icon: IconData(iconCode, fontFamily: 'MaterialIcons'),
        color: Color(colorHex),
      ));
    }

    if (mounted) {
      setState(() {
        _trees = newTrees;
        _dbSkills = newDbSkills;
        _selectedIdentity = _selectedIdentity.clamp(0, newTrees.length - 1);
        _isLoading = false;
      });
    }
  }

  _SkillNode _mapSkill(Map<String, dynamic> sRow) {
    return _SkillNode(
      id: sRow['id'] as String,
      name: sRow['name'] as String,
      desc: sRow['description'] as String? ?? '',
      level: sRow['level'] as int? ?? 0,
      maxLevel: sRow['max_level'] as int? ?? 5,
      unlocked: (sRow['is_unlocked'] as int?) == 1,
      sortOrder: sRow['sort_order'] as int? ?? 0,
      xpReward: sRow['xp_reward'] as int? ?? 25,
      iconName: sRow['icon_name'] as String? ?? 'star',
    );
  }

  IconData _resolveIcon(String name) {
    const map = {
      'star': Icons.star, 'auto_stories': Icons.auto_stories, 'edit_note': Icons.edit_note,
      'timer': Icons.timer, 'menu_book': Icons.menu_book, 'playlist_add_check': Icons.playlist_add_check,
      'workspace_premium': Icons.workspace_premium, 'fitness_center': Icons.fitness_center,
      'directions_walk': Icons.directions_walk, 'self_improvement': Icons.self_improvement,
      'trending_up': Icons.trending_up, 'sports_martial_arts': Icons.sports_martial_arts,
      'emoji_events': Icons.emoji_events, 'code': Icons.code, 'school': Icons.school,
      'psychology': Icons.psychology, 'rocket_launch': Icons.rocket_launch,
      'rate_review': Icons.rate_review, 'terminal': Icons.terminal, 'bedtime': Icons.bedtime,
      'alarm': Icons.alarm, 'phone_disabled': Icons.phone_disabled, 'event_note': Icons.event_note,
      'cleaning_services': Icons.cleaning_services, 'military_tech': Icons.military_tech,
      'favorite': Icons.favorite, 'spa': Icons.spa, 'diversity_3': Icons.diversity_3,
      'brightness_7': Icons.brightness_7, 'brush': Icons.brush, 'palette': Icons.palette,
      'construction': Icons.construction, 'draw': Icons.draw, 'share': Icons.share,
    };
    return map[name] ?? Icons.star;
  }

  Future<void> _onSkillTap(_SkillNode skill, Color color) async {
    if (!skill.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(AppStrings.isArabic
            ? 'أكمل المهارة السابقة أولاً لفتح هذه المهارة'
            : 'Complete the previous skill first to unlock this one'),
        backgroundColor: AppColors.cardBackground,
      ));
      return;
    }

    final branch = _trees[_selectedIdentity].name;
    final canUpgrade = await _gamificationService.canUpgradeToday(skill.id);
    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SkillDetailSheet(
        skill: skill, color: color, resolveIcon: _resolveIcon,
        canUpgradeToday: canUpgrade,
      ),
    );

    if (result == 'upgrade' && mounted) {
      final success = await _gamificationService.upgradeSkill(skill.id, skill.level);
      if (success) {
        // Award XP globally
        ref.read(systemProvider.notifier).awardXP(skill.xpReward);
        // Check if skill maxed → unlock next
        if (skill.level + 1 >= skill.maxLevel) {
          await _gamificationService.checkAndUnlockNextSkill(branch, skill.sortOrder);
        }
        await _loadData();
        // Show achievement toast
        if (mounted) {
          final isAr = AppStrings.isArabic;
          showAchievementToast(context,
            title: isAr ? 'ترقية مهارة!' : 'Skill Upgraded!',
            subtitle: '${skill.name} → ${isAr ? "المستوى" : "Level"} ${skill.level + 1}',
            xpEarned: skill.xpReward,
            icon: _resolveIcon(skill.iconName),
            color: color,
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppStrings.isArabic
              ? 'يمكنك ترقية هذه المهارة مرة واحدة يومياً'
              : 'You can upgrade this skill once per day'),
          backgroundColor: AppColors.cardBackground,
        ));
      }
    }
  }

  Future<void> _showAddSkillDialog() async {
    final curBranch = _trees[_selectedIdentity].name;
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.background,
        title: Text('${AppStrings.addCustomSkillTo} $curBranch', style: AppTextStyles.h3),
        content: InputField(controller: ctrl, label: AppStrings.skillName, prefixIcon: Icons.edit),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.cancel, style: TextStyle(color: AppColors.textTertiary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            onPressed: () async {
              if (ctrl.text.isEmpty) return;
              await _gamificationService.addSkill(ctrl.text.trim(), curBranch);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _loadData();
            },
            child: Text(AppStrings.addSkill),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryBlue)),
      );
    }
    if (_trees.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.account_tree, color: AppColors.textTertiary, size: 48),
            const SizedBox(height: 16),
            Text(AppStrings.noIdentitiesFound, style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text(AppStrings.goBackToIdentityBuilder, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary)),
          ]),
        ),
      );
    }

    final tree = _trees[_selectedIdentity];
    final skills = _dbSkills[tree.name] ?? [];
    final profile = ref.watch(systemProvider).profile;
    final displayLevel = profile.level;
    final displayXp = profile.currentXP.clamp(0, profile.xpForNextLevel);
    final displayXpToNext = profile.xpForNextLevel;
    final displayLevelProgress = profile.levelProgress.clamp(0.0, 1.0);
    final unlockedCount = skills.where((s) => s.unlocked).length;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SystemBackground(
        child: Column(children: [
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
                    decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.cardBackground.withOpacity(0.5)),
                    child: const Icon(Icons.arrow_back, color: AppColors.primaryBlue, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(AppStrings.skillTrees, style: AppTextStyles.h2),
                  Row(children: [
                    Container(width: 32, height: 1, color: AppColors.primaryBlue),
                    const SizedBox(width: 8),
                    const Icon(Icons.account_tree, color: AppColors.primaryBlue, size: 12),
                  ]),
                ]),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: tree.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: tree.color.withOpacity(0.3)),
                  ),
                  child: Text('$unlockedCount/${skills.length}',
                    style: AppTextStyles.caption.copyWith(color: tree.color, fontWeight: FontWeight.w600)),
                ),
              ]).animate().fadeIn().slideY(begin: -0.2),
            ),
          ),
          const SizedBox(height: 16),
          // Identity tabs
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: _trees.length,
              itemBuilder: (context, index) {
                final t = _trees[index];
                final isActive = index == _selectedIdentity;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIdentity = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isActive ? t.color.withOpacity(0.15) : AppColors.cardBackground.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isActive ? t.color.withOpacity(0.6) : AppColors.primaryBlue.withOpacity(0.15)),
                      ),
                      child: Row(children: [
                        Icon(t.icon, color: isActive ? t.color : AppColors.textTertiary, size: 18),
                        const SizedBox(width: 8),
                        Text('${t.name} ${AppStrings.levelText(displayLevel)}',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isActive ? Colors.white : AppColors.textSecondary,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400)),
                      ]),
                    ),
                  ),
                );
              },
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          // XP card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GlowCard(
              glowColor: tree.color, glowOpacity: 0.2,
              child: Column(children: [
                Row(children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: tree.color.withOpacity(0.15),
                      border: Border.all(color: tree.color.withOpacity(0.4))),
                    child: Icon(tree.icon, color: tree.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${tree.name} — ${AppStrings.levelText(displayLevel)}',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: displayLevelProgress,
                        backgroundColor: AppColors.cardBackground, valueColor: AlwaysStoppedAnimation(tree.color), minHeight: 6),
                    ),
                    const SizedBox(height: 2),
                    Text('$displayXp / $displayXpToNext XP',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 10)),
                  ])),
                ]),
              ]),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          // Skills list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 120),
              itemCount: skills.length,
              itemBuilder: (context, index) {
                final skill = skills[index];
                return GestureDetector(
                  onTap: () => _onSkillTap(skill, tree.color),
                  child: _SkillNodeCard(
                    skill: skill, color: tree.color,
                    isLast: index == skills.length - 1,
                    resolveIcon: _resolveIcon,
                  ).animate(delay: Duration(milliseconds: 350 + index * 100))
                   .fadeIn().slideX(begin: -0.1),
                );
              },
            ),
          ),
        ]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSkillDialog,
        backgroundColor: tree.color,
        icon: const Icon(Icons.add),
        label: Text(AppStrings.addSkill, style: const TextStyle(fontWeight: FontWeight.bold)),
      ).animate().fadeIn(delay: 500.ms),
    );
  }
}

// ═══════════════════════════════════════════
// Skill Detail Bottom Sheet
// ═══════════════════════════════════════════
class _SkillDetailSheet extends StatelessWidget {
  final _SkillNode skill;
  final Color color;
  final IconData Function(String) resolveIcon;
  final bool canUpgradeToday;

  const _SkillDetailSheet({required this.skill, required this.color, required this.resolveIcon, required this.canUpgradeToday});

  String _getHowTo(String name) {
    final isAr = AppStrings.isArabic;
    final lower = name.toLowerCase();
    if (lower.contains('قراءة') || lower.contains('read')) {
      return isAr ? 'اختر كتاباً واجلس في مكان هادئ. خصص وقتاً محدداً يومياً واستخدم مؤقتاً لتتبع تقدمك.' : 'Pick a book, find a quiet spot, set a fixed daily time and use a timer to track progress.';
    }
    if (lower.contains('تمرين') || lower.contains('workout') || lower.contains('مشي') || lower.contains('step') || lower.contains('stretch') || lower.contains('مرونة')) {
      return isAr ? 'ابدأ بتمارين بسيطة وزد التحدي تدريجياً. الاستمرارية أهم من الشدة.' : 'Start simple and increase gradually. Consistency matters more than intensity.';
    }
    if (lower.contains('كود') || lower.contains('code') || lower.contains('مشروع') || lower.contains('project')) {
      return isAr ? 'اختر تحدياً برمجياً صغيراً. خصص وقتاً ثابتاً وابدأ حتى لو 15 دقيقة.' : 'Pick a small coding challenge. Set fixed time and start even if just 15 min.';
    }
    if (lower.contains('تأمل') || lower.contains('meditat') || lower.contains('ورد')) {
      return isAr ? 'اجلس في مكان هادئ وركّز على تنفسك. ابدأ بدقائق قليلة وزدها تدريجياً.' : 'Sit quietly, focus on breathing. Start with few minutes and increase gradually.';
    }
    if (lower.contains('نوم') || lower.contains('sleep') || lower.contains('استيقاظ') || lower.contains('wake')) {
      return isAr ? 'ضع هاتفك بعيداً قبل النوم بساعة. اجعل روتين ثابت للنوم والاستيقاظ.' : 'Put phone away 1h before bed. Create a consistent sleep/wake routine.';
    }
    if (lower.contains('إبداع') || lower.contains('creat') || lower.contains('رسم') || lower.contains('draw')) {
      return isAr ? 'خصص وقتاً يومياً للإبداع. لا تنتظر الإلهام — ابدأ وسيأتي.' : 'Set daily creative time. Don\'t wait for inspiration — just start.';
    }
    return isAr ? 'خصص وقتاً يومياً وابدأ صغيراً. الاستمرارية هي المفتاح.' : 'Set daily time and start small. Consistency is key.';
  }

  @override
  Widget build(BuildContext context) {
    final isMaxed = skill.level >= skill.maxLevel;
    final isAr = AppStrings.isArabic;
    final canPress = canUpgradeToday && !isMaxed;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF12101C),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: AppColors.textTertiary.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Row(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.15),
              border: Border.all(color: color.withOpacity(0.4), width: 2)),
            child: Icon(resolveIcon(skill.iconName), color: color, size: 28)),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(skill.name, style: AppTextStyles.h3.copyWith(color: Colors.white)),
            if (skill.desc.isNotEmpty)
              Text(skill.desc, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ])),
        ]),
        const SizedBox(height: 16),
        // How-to section
        Container(width: double.infinity, padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: color.withOpacity(0.06), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.lightbulb_outline, color: color, size: 16),
              const SizedBox(width: 6),
              Text(isAr ? 'كيف تنفّذ هذه المهارة؟' : 'How to practice this skill?',
                style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            Text(_getHowTo(skill.name),
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5)),
          ]),
        ),
        const SizedBox(height: 16),
        // Level progress
        Row(children: [
          Text(isAr ? 'المستوى' : 'Level', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          const SizedBox(width: 12),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: skill.maxLevel > 0 ? skill.level / skill.maxLevel : 0,
              backgroundColor: AppColors.cardBackground, valueColor: AlwaysStoppedAnimation(color), minHeight: 8))),
          const SizedBox(width: 12),
          Text('${skill.level}/${skill.maxLevel}',
            style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        // XP + cooldown row
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.warning.withOpacity(0.2))),
            child: Row(children: [
              const Icon(Icons.stars, color: AppColors.warning, size: 16),
              const SizedBox(width: 6),
              Text('+${skill.xpReward} XP', style: AppTextStyles.caption.copyWith(color: AppColors.warning, fontWeight: FontWeight.w600)),
            ]))),
          if (!canUpgradeToday && !isMaxed) ...[
            const SizedBox(width: 8),
            Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: AppColors.textTertiary.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.textTertiary.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.hourglass_top, color: AppColors.textTertiary, size: 16),
                const SizedBox(width: 6),
                Flexible(child: Text(isAr ? 'متاحة غداً' : 'Tomorrow',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontWeight: FontWeight.w600, fontSize: 10))),
              ]))),
          ],
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: canPress ? () => Navigator.pop(context, 'upgrade') : null,
            style: ElevatedButton.styleFrom(backgroundColor: isMaxed ? AppColors.success.withOpacity(0.2) : color,
              foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              disabledBackgroundColor: isMaxed ? AppColors.success.withOpacity(0.15) : AppColors.cardBackground),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(isMaxed ? Icons.check_circle : !canUpgradeToday ? Icons.hourglass_top : Icons.arrow_upward, size: 20,
                color: isMaxed ? AppColors.success : !canUpgradeToday ? AppColors.textTertiary : Colors.white),
              const SizedBox(width: 8),
              Text(isMaxed ? (isAr ? 'مهارة مكتملة ✨' : 'Skill Mastered ✨')
                : !canUpgradeToday ? (isAr ? 'تم الترقية اليوم' : 'Upgraded Today')
                : (isAr ? 'ترقية المهارة' : 'Upgrade Skill'),
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15,
                  color: isMaxed ? AppColors.success : !canUpgradeToday ? AppColors.textTertiary : Colors.white)),
            ]),
          )),
        const SizedBox(height: 8),
      ]),
    );
  }
}

// ═══════════════════════════════════════════
// Skill Node Card
// ═══════════════════════════════════════════
class _SkillNodeCard extends StatelessWidget {
  final _SkillNode skill;
  final Color color;
  final bool isLast;
  final IconData Function(String) resolveIcon;

  const _SkillNodeCard({required this.skill, required this.color, required this.isLast, required this.resolveIcon});

  @override
  Widget build(BuildContext context) {
    final isMaxed = skill.level >= skill.maxLevel;
    final progress = skill.maxLevel > 0 ? skill.level / skill.maxLevel : 0.0;

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Connection line + node dot
      SizedBox(width: 32, child: Column(children: [
        Container(
          width: 16, height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMaxed ? AppColors.success.withOpacity(0.3)
                : skill.unlocked ? color.withOpacity(0.3) : AppColors.cardBackground,
            border: Border.all(
              color: isMaxed ? AppColors.success
                  : skill.unlocked ? color : AppColors.textTertiary.withOpacity(0.3), width: 2),
            boxShadow: skill.unlocked ? [BoxShadow(color: (isMaxed ? AppColors.success : color).withOpacity(0.4), blurRadius: 8)] : null,
          ),
          child: isMaxed
              ? const Icon(Icons.check, size: 8, color: AppColors.success)
              : skill.level > 0 ? Icon(Icons.arrow_upward, size: 8, color: color) : null,
        ),
        if (!isLast)
          Container(width: 2, height: 80,
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                skill.unlocked ? color.withOpacity(0.5) : AppColors.textTertiary.withOpacity(0.15),
                AppColors.textTertiary.withOpacity(0.1),
              ],
            )),
          ),
      ])),
      const SizedBox(width: 12),
      // Skill card
      Expanded(child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isMaxed ? AppColors.success.withOpacity(0.05)
              : skill.unlocked ? color.withOpacity(0.06) : AppColors.cardBackground.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isMaxed ? AppColors.success.withOpacity(0.3)
              : skill.unlocked ? color.withOpacity(0.3) : AppColors.textTertiary.withOpacity(0.1)),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(shape: BoxShape.circle,
              color: skill.unlocked ? color.withOpacity(0.15) : AppColors.cardBackground.withOpacity(0.5)),
            child: Icon(skill.unlocked ? resolveIcon(skill.iconName) : Icons.lock,
              color: skill.unlocked ? color : AppColors.textTertiary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(skill.name, style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
              color: skill.unlocked ? Colors.white : AppColors.textTertiary)),
            if (skill.unlocked && skill.desc.isNotEmpty)
              Text(skill.desc, style: AppTextStyles.caption.copyWith(color: AppColors.textTertiary, fontSize: 11)),
            if (skill.unlocked) ...[
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: progress,
                  backgroundColor: AppColors.cardBackground,
                  valueColor: AlwaysStoppedAnimation(isMaxed ? AppColors.success : color), minHeight: 4)),
            ],
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isMaxed ? AppColors.success : skill.unlocked ? color : Colors.transparent).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: (isMaxed ? AppColors.success : skill.unlocked ? color : AppColors.textTertiary).withOpacity(skill.unlocked ? 0.4 : 0.2)),
            ),
            child: Text(
              isMaxed ? '★ MAX' : AppStrings.levelProgress(skill.level, skill.maxLevel),
              style: AppTextStyles.caption.copyWith(
                color: isMaxed ? AppColors.success : skill.unlocked ? color : AppColors.textTertiary,
                fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        ]),
      )),
    ]);
  }
}

// ═══════════════════════════════════════════
// Data Classes
// ═══════════════════════════════════════════
class _IdentityTree {
  final String name;
  final IconData icon;
  final Color color;
  const _IdentityTree({required this.name, required this.icon, required this.color});
}

class _SkillNode {
  final String id;
  final String name;
  final String desc;
  final int level;
  final int maxLevel;
  final bool unlocked;
  final int sortOrder;
  final int xpReward;
  final String iconName;

  const _SkillNode({
    required this.id, required this.name, required this.desc,
    required this.level, required this.maxLevel, required this.unlocked,
    required this.sortOrder, required this.xpReward, required this.iconName,
  });
}
