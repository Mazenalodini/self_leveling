import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/constants/app_strings.dart';

class GamificationService {
  final _db = DatabaseHelper.instance;
  final _uuid = const Uuid();

  // ═══════════════════════════════════════════
  // Identities
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getIdentities() async {
    return await _db.queryWhere(
      'user_identities',
      where: 'selected = ?',
      whereArgs: [1],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> saveIdentities(List<Map<String, dynamic>> identities) async {
    await _db.delete('user_identities', where: 'selected = ?', whereArgs: [1]);
    for (var id in identities) {
      final branchTitle = id['title'] as String;
      await _db.insert('user_identities', {
        'id': id['id'] ?? _uuid.v4(),
        'title': branchTitle,
        'subtitle': id['subtitle'] ?? '',
        'icon_code': id['icon_code'] ?? 0,
        'color_hex': id['color_hex'] ?? 0,
        'selected': 1,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
      // Seed default skills if none exist
      final existing = await getSkills(branchTitle);
      if (existing.isEmpty) {
        await _seedSkillsForIdentity(branchTitle);
      }
    }
  }

  Future<void> addCustomIdentity(
      String title, String subtitle, int iconCode, int colorHex) async {
    await _db.insert('user_identities', {
      'id': _uuid.v4(),
      'title': title,
      'subtitle': subtitle,
      'icon_code': iconCode,
      'color_hex': colorHex,
      'selected': 1,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  // ═══════════════════════════════════════════
  // Skills
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getSkills(String branchName) async {
    return await _db.queryWhere(
      'skills',
      where: 'branch = ?',
      whereArgs: [branchName],
      orderBy: 'sort_order ASC, created_at ASC',
    );
  }

  Future<void> addSkill(String name, String branch,
      {String description = '', int sortOrder = 99}) async {
    await _db.insert('skills', {
      'id': _uuid.v4(),
      'name': name,
      'description': description,
      'branch': branch,
      'is_unlocked': 0,
      'level': 0,
      'max_level': 5,
      'sort_order': sortOrder,
      'icon_name': 'star',
      'xp_reward': 25,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> unlockSkill(String id) async {
    await _db.update('skills', {
      'is_unlocked': 1,
      'level': 1,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<bool> canUpgradeToday(String id) async {
    final skill = await _db.queryFirst('skills', where: 'id = ?', whereArgs: [id]);
    if (skill == null) return false;
    final lastUpgraded = skill['last_upgraded_at'] as int?;
    if (lastUpgraded == null) return true;
    final lastDate = DateTime.fromMillisecondsSinceEpoch(lastUpgraded);
    final now = DateTime.now();
    return now.year != lastDate.year || now.month != lastDate.month || now.day != lastDate.day;
  }

  Future<bool> upgradeSkill(String id, int currentLevel) async {
    final skill = await _db.queryFirst('skills', where: 'id = ?', whereArgs: [id]);
    if (skill == null) return false;
    final maxLevel = skill['max_level'] as int? ?? 5;
    if (currentLevel >= maxLevel) return false;
    if (!await canUpgradeToday(id)) return false;
    await _db.update('skills', {
      'level': currentLevel + 1,
      'is_unlocked': 1,
      'last_upgraded_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
    return true;
  }

  /// Ensure first skill in each branch is always unlocked
  Future<void> ensureFirstSkillUnlocked(String branch) async {
    final skills = await getSkills(branch);
    if (skills.isEmpty) return;
    final first = skills.first;
    if ((first['is_unlocked'] as int?) != 1) {
      await unlockSkill(first['id'] as String);
    }
  }

  /// Check if next skill should auto-unlock based on previous skill completion
  Future<void> checkAndUnlockNextSkill(String branch, int completedSortOrder) async {
    final skills = await getSkills(branch);
    for (final skill in skills) {
      final order = skill['sort_order'] as int? ?? 0;
      final unlocked = (skill['is_unlocked'] as int?) == 1;
      if (order == completedSortOrder + 1 && !unlocked) {
        await unlockSkill(skill['id'] as String);
        break;
      }
    }
  }

  Future<void> _seedSkillsForIdentity(String identity) async {
    final skills = _getDefaultSkillsForIdentity(identity);
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < skills.length; i++) {
      final s = skills[i];
      await _db.insert('skills', {
        'id': _uuid.v4(),
        'name': s['name'],
        'description': s['desc'],
        'branch': identity,
        'is_unlocked': i == 0 ? 1 : 0, // First skill auto-unlocked
        'level': i == 0 ? 1 : 0,
        'max_level': s['maxLevel'] ?? 5,
        'sort_order': i,
        'icon_name': s['icon'] ?? 'star',
        'xp_reward': s['xp'] ?? 25,
        'created_at': now,
      });
    }
  }

  List<Map<String, dynamic>> _getDefaultSkillsForIdentity(String identity) {
    final isAr = AppStrings.isArabic;
    // Match by known identity titles
    final lower = identity.toLowerCase();
    if (lower.contains('قارئ') || lower.contains('reader')) {
      return [
        {'name': isAr ? 'قراءة 15 دقيقة' : 'Read 15 min', 'desc': isAr ? 'قراءة يومية مستمرة' : 'Daily consistent reading', 'icon': 'auto_stories', 'xp': 20, 'maxLevel': 5},
        {'name': isAr ? 'تلخيص فصل' : 'Summarize a Chapter', 'desc': isAr ? 'اكتب ملخصاً لما قرأته' : 'Write a summary of what you read', 'icon': 'edit_note', 'xp': 30, 'maxLevel': 3},
        {'name': isAr ? 'قراءة 30 دقيقة' : 'Read 30 min', 'desc': isAr ? 'مضاعفة وقت القراءة' : 'Double your reading time', 'icon': 'timer', 'xp': 35, 'maxLevel': 5},
        {'name': isAr ? 'إنهاء كتاب' : 'Finish a Book', 'desc': isAr ? 'أكمل كتاباً كاملاً' : 'Complete an entire book', 'icon': 'menu_book', 'xp': 50, 'maxLevel': 3},
        {'name': isAr ? 'قائمة قراءة' : 'Reading List', 'desc': isAr ? 'أنشئ وتابع قائمة قراءتك' : 'Create and follow your reading list', 'icon': 'playlist_add_check', 'xp': 40, 'maxLevel': 3},
        {'name': isAr ? 'قراءة ساعة' : 'Read 1 Hour', 'desc': isAr ? 'ساعة قراءة متواصلة' : 'One hour of continuous reading', 'icon': 'workspace_premium', 'xp': 60, 'maxLevel': 5},
      ];
    }
    if (lower.contains('رياضي') || lower.contains('athlete')) {
      return [
        {'name': isAr ? 'تمرين صباحي' : 'Morning Workout', 'desc': isAr ? '10 دقائق تمرين بعد الاستيقاظ' : '10 min exercise after waking up', 'icon': 'fitness_center', 'xp': 20, 'maxLevel': 5},
        {'name': isAr ? 'مشي 5000 خطوة' : 'Walk 5000 Steps', 'desc': isAr ? 'حرك جسمك يومياً' : 'Move your body daily', 'icon': 'directions_walk', 'xp': 25, 'maxLevel': 5},
        {'name': isAr ? 'تمارين مرونة' : 'Stretching', 'desc': isAr ? 'تمدد لمدة 10 دقائق' : 'Stretch for 10 minutes', 'icon': 'self_improvement', 'xp': 20, 'maxLevel': 3},
        {'name': isAr ? '10000 خطوة' : '10000 Steps', 'desc': isAr ? 'الهدف الذهبي للمشي' : 'The golden walking goal', 'icon': 'trending_up', 'xp': 40, 'maxLevel': 5},
        {'name': isAr ? 'تمرين 30 دقيقة' : '30 Min Workout', 'desc': isAr ? 'جلسة تمرين كاملة' : 'Full workout session', 'icon': 'sports_martial_arts', 'xp': 50, 'maxLevel': 5},
        {'name': isAr ? 'تحدي اللياقة' : 'Fitness Challenge', 'desc': isAr ? 'أسبوع كامل بدون توقف' : 'Full week without stopping', 'icon': 'emoji_events', 'xp': 60, 'maxLevel': 3},
      ];
    }
    if (lower.contains('مطور') || lower.contains('developer') || lower.contains('مبرمج')) {
      return [
        {'name': isAr ? 'كتابة كود 30 دقيقة' : 'Code 30 min', 'desc': isAr ? 'برمجة يومية مستمرة' : 'Daily consistent coding', 'icon': 'code', 'xp': 25, 'maxLevel': 5},
        {'name': isAr ? 'تعلم مفهوم جديد' : 'Learn New Concept', 'desc': isAr ? 'تعلم شيئاً جديداً كل أسبوع' : 'Learn something new weekly', 'icon': 'school', 'xp': 30, 'maxLevel': 5},
        {'name': isAr ? 'حل مشكلة' : 'Solve a Problem', 'desc': isAr ? 'حل تحدي برمجي' : 'Solve a coding challenge', 'icon': 'psychology', 'xp': 35, 'maxLevel': 5},
        {'name': isAr ? 'مشروع شخصي' : 'Side Project', 'desc': isAr ? 'اعمل على مشروعك الخاص' : 'Work on your personal project', 'icon': 'rocket_launch', 'xp': 50, 'maxLevel': 3},
        {'name': isAr ? 'مراجعة كود' : 'Code Review', 'desc': isAr ? 'راجع وحسّن كودك القديم' : 'Review and improve old code', 'icon': 'rate_review', 'xp': 30, 'maxLevel': 3},
        {'name': isAr ? 'ساعة برمجة عميقة' : 'Deep Code Hour', 'desc': isAr ? 'ساعة تركيز كامل على الكود' : 'One hour of deep focus coding', 'icon': 'terminal', 'xp': 60, 'maxLevel': 5},
      ];
    }
    if (lower.contains('منضبط') || lower.contains('disciplined')) {
      return [
        {'name': isAr ? 'نوم مبكر' : 'Early Sleep', 'desc': isAr ? 'نم قبل الساعة 11' : 'Sleep before 11 PM', 'icon': 'bedtime', 'xp': 25, 'maxLevel': 5},
        {'name': isAr ? 'استيقاظ مبكر' : 'Early Wake', 'desc': isAr ? 'استيقظ قبل 7 صباحاً' : 'Wake up before 7 AM', 'icon': 'alarm', 'xp': 25, 'maxLevel': 5},
        {'name': isAr ? 'لا هاتف بعد 10' : 'No Phone After 10', 'desc': isAr ? 'ضع الهاتف جانباً' : 'Put the phone away', 'icon': 'phone_disabled', 'xp': 30, 'maxLevel': 5},
        {'name': isAr ? 'جدول يومي' : 'Daily Schedule', 'desc': isAr ? 'خطط يومك كل صباح' : 'Plan your day every morning', 'icon': 'event_note', 'xp': 20, 'maxLevel': 3},
        {'name': isAr ? 'ترتيب المكان' : 'Clean Space', 'desc': isAr ? 'رتب مكانك قبل العمل' : 'Organize your space before work', 'icon': 'cleaning_services', 'xp': 20, 'maxLevel': 3},
        {'name': isAr ? 'انضباط كامل' : 'Full Discipline', 'desc': isAr ? 'أسبوع كامل بدون تفويت' : 'Full week without missing', 'icon': 'military_tech', 'xp': 60, 'maxLevel': 5},
      ];
    }
    if (lower.contains('روحاني') || lower.contains('spiritual')) {
      return [
        {'name': isAr ? 'تأمل 5 دقائق' : 'Meditate 5 min', 'desc': isAr ? 'لحظات هدوء يومية' : 'Daily moments of calm', 'icon': 'self_improvement', 'xp': 20, 'maxLevel': 5},
        {'name': isAr ? 'قراءة ورد يومي' : 'Daily Recitation', 'desc': isAr ? 'ورد يومي ثابت' : 'Fixed daily recitation', 'icon': 'auto_stories', 'xp': 25, 'maxLevel': 5},
        {'name': isAr ? 'الامتنان' : 'Gratitude', 'desc': isAr ? 'اكتب 3 أشياء ممتنّ لها' : 'Write 3 things you are grateful for', 'icon': 'favorite', 'xp': 20, 'maxLevel': 3},
        {'name': isAr ? 'تأمل 15 دقيقة' : 'Meditate 15 min', 'desc': isAr ? 'تعميق جلسة التأمل' : 'Deepen your meditation', 'icon': 'spa', 'xp': 35, 'maxLevel': 5},
        {'name': isAr ? 'التسامح والصفح' : 'Forgiveness', 'desc': isAr ? 'تدرب على التسامح' : 'Practice forgiveness', 'icon': 'diversity_3', 'xp': 30, 'maxLevel': 3},
        {'name': isAr ? 'سلام داخلي' : 'Inner Peace', 'desc': isAr ? 'أسبوع من الهدوء والتأمل' : 'A week of calm and reflection', 'icon': 'brightness_7', 'xp': 60, 'maxLevel': 5},
      ];
    }
    if (lower.contains('مبدع') || lower.contains('creator')) {
      return [
        {'name': isAr ? 'إبداع 15 دقيقة' : 'Create 15 min', 'desc': isAr ? 'ارسم أو اكتب يومياً' : 'Draw or write daily', 'icon': 'brush', 'xp': 20, 'maxLevel': 5},
        {'name': isAr ? 'مشروع إبداعي' : 'Creative Project', 'desc': isAr ? 'ابدأ مشروعاً جديداً' : 'Start a new project', 'icon': 'palette', 'xp': 35, 'maxLevel': 3},
        {'name': isAr ? 'تعلم أداة جديدة' : 'Learn New Tool', 'desc': isAr ? 'تعلم برنامجاً أو أداة إبداعية' : 'Learn a creative tool', 'icon': 'construction', 'xp': 30, 'maxLevel': 3},
        {'name': isAr ? 'إبداع 30 دقيقة' : 'Create 30 min', 'desc': isAr ? 'ضاعف وقت الإبداع' : 'Double your creative time', 'icon': 'draw', 'xp': 40, 'maxLevel': 5},
        {'name': isAr ? 'مشاركة عملك' : 'Share Your Work', 'desc': isAr ? 'شارك ما أنشأت مع آخرين' : 'Share what you created', 'icon': 'share', 'xp': 30, 'maxLevel': 3},
        {'name': isAr ? 'ماستر الإبداع' : 'Creative Master', 'desc': isAr ? 'أكمل مشروعاً كاملاً' : 'Complete a full project', 'icon': 'workspace_premium', 'xp': 60, 'maxLevel': 5},
      ];
    }
    // Fallback generic
    return [
      {'name': isAr ? 'المهارة الأولى' : 'First Skill', 'desc': isAr ? 'ابدأ رحلتك' : 'Start your journey', 'icon': 'star', 'xp': 20, 'maxLevel': 5},
      {'name': isAr ? 'التحسين' : 'Improvement', 'desc': isAr ? 'طوّر نفسك' : 'Develop yourself', 'icon': 'trending_up', 'xp': 30, 'maxLevel': 5},
      {'name': isAr ? 'الإتقان' : 'Mastery', 'desc': isAr ? 'أتقن ما تعلمته' : 'Master what you learned', 'icon': 'emoji_events', 'xp': 50, 'maxLevel': 5},
    ];
  }

  // ═══════════════════════════════════════════
  // Dungeon Quests
  // ═══════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllDungeons() async {
    return await _db.queryWhere(
      'dungeon_quests',
      orderBy: "CASE status WHEN 'active' THEN 0 WHEN 'available' THEN 1 WHEN 'completed' THEN 2 WHEN 'failed' THEN 3 END, created_at DESC",
    );
  }

  Future<List<Map<String, dynamic>>> getActiveQuests() async {
    return await _db.queryWhere(
      'dungeon_quests',
      where: "status IN ('available', 'active')",
      orderBy: 'created_at DESC',
    );
  }

  Future<void> seedDefaultDungeons() async {
    final existing = await _db.count('dungeon_quests',
        where: 'is_default = ?', whereArgs: [1]);
    if (existing > 0) return;

    final isAr = AppStrings.isArabic;
    final now = DateTime.now().millisecondsSinceEpoch;
    final defaults = [
      {
        'title': isAr ? 'التمرير اللانهائي' : 'Infinite Scroll',
        'boss_name': isAr ? 'مزاحم الوقت' : 'The Doom Scroller',
        'description': isAr ? 'سوشال ميديا أقل من 30 دقيقة يومياً لمدة 5 أيام' : 'Social media less than 30 min/day for 5 days',
        'icon_name': 'swipe_down_alt',
        'color_hex': 0xFFEF4444,
        'reward_xp': 150,
        'duration_days': 5,
        'condition_type': 'max_screen_time',
        'condition_value': '30',
        'weaknesses': jsonEncode(isAr ? ['مثيرات الصباح', 'قبل النوم', 'الملل'] : ['Morning trigger', 'Before sleep', 'Boredom']),
      },
      {
        'title': isAr ? 'سارق الليل' : 'Night Thief',
        'boss_name': isAr ? 'لص المنتصف' : 'The Midnight Thief',
        'description': isAr ? 'لا هاتف بعد الساعة 11 مساءً لمدة 3 أيام' : 'No phone after 11 PM for 3 days',
        'icon_name': 'nightlight',
        'color_hex': 0xFF8B5CF6,
        'reward_xp': 120,
        'duration_days': 3,
        'condition_type': 'no_phone_after',
        'condition_value': '23:00',
        'weaknesses': jsonEncode(isAr ? ['الخوف من التفويت', 'الإشعارات', 'لا يوجد روتين'] : ['FOMO', 'Notifications', 'No routine']),
      },
      {
        'title': isAr ? 'التسويف' : 'Procrastination',
        'boss_name': isAr ? 'المؤجل الأعظم' : 'The Grand Delayer',
        'description': isAr ? 'أتمم مهمة واحدة على الأقل يومياً لمدة 7 أيام' : 'Complete at least one task daily for 7 days',
        'icon_name': 'hourglass_empty',
        'color_hex': 0xFFF59E0B,
        'reward_xp': 200,
        'duration_days': 7,
        'condition_type': 'daily_task',
        'condition_value': '1',
        'weaknesses': jsonEncode(isAr ? ['المهام الكبيرة', 'غياب الخطة', 'الخوف من الفشل'] : ['Big tasks', 'Lack of plan', 'Fear of failure']),
      },
      {
        'title': isAr ? 'كاسر التركيز' : 'Focus Breaker',
        'boss_name': isAr ? 'المشتت' : 'The Distractor',
        'description': isAr ? 'أكمل جلسة تركيز 25 دقيقة يومياً لمدة 5 أيام' : 'Complete a 25 min focus session daily for 5 days',
        'icon_name': 'center_focus_strong',
        'color_hex': 0xFF06B6D4,
        'reward_xp': 180,
        'duration_days': 5,
        'condition_type': 'focus_session',
        'condition_value': '25',
        'weaknesses': jsonEncode(isAr ? ['الإشعارات', 'تعدد المهام', 'عدم التخطيط'] : ['Notifications', 'Multitasking', 'No planning']),
      },
      {
        'title': isAr ? 'سارق الفجر' : 'Dawn Stealer',
        'boss_name': isAr ? 'وحش الصباح' : 'The Morning Monster',
        'description': isAr ? 'استيقظ قبل الساعة 7 صباحاً لمدة 5 أيام' : 'Wake up before 7 AM for 5 days',
        'icon_name': 'wb_sunny',
        'color_hex': 0xFFF97316,
        'reward_xp': 160,
        'duration_days': 5,
        'condition_type': 'wake_before',
        'condition_value': '07:00',
        'weaknesses': jsonEncode(isAr ? ['سهر متأخر', 'إغفاء المنبه', 'لا دافع صباحي'] : ['Late nights', 'Snoozing alarm', 'No morning motivation']),
      },
    ];

    for (final d in defaults) {
      await _db.insert('dungeon_quests', {
        'id': _uuid.v4(),
        ...d,
        'is_ai_generated': 0,
        'status': 'available',
        'current_day': 0,
        'daily_progress': '[]',
        'is_default': 1,
        'created_at': now,
      });
    }
  }

  Future<void> addQuest({
    required String title,
    String description = '',
    String bossName = '',
    int rewardXp = 50,
    int durationDays = 3,
    bool isAiGenerated = false,
  }) async {
    await _db.insert('dungeon_quests', {
      'id': _uuid.v4(),
      'title': title,
      'description': description,
      'boss_name': bossName.isEmpty ? title : bossName,
      'reward_xp': rewardXp,
      'duration_days': durationDays,
      'is_ai_generated': isAiGenerated ? 1 : 0,
      'status': 'available',
      'current_day': 0,
      'daily_progress': '[]',
      'is_default': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> startDungeon(String id) async {
    await _db.update('dungeon_quests', {
      'status': 'active',
      'started_at': DateTime.now().millisecondsSinceEpoch,
      'current_day': 0,
      'daily_progress': '[]',
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> completeDungeonDay(String id) async {
    final quest = await _db.queryFirst('dungeon_quests',
        where: 'id = ?', whereArgs: [id]);
    if (quest == null) return;

    final currentDay = (quest['current_day'] as int? ?? 0) + 1;
    final durationDays = quest['duration_days'] as int? ?? 3;
    final progress = List<String>.from(
        jsonDecode(quest['daily_progress'] as String? ?? '[]'));
    progress.add(DateTime.now().toIso8601String());

    if (currentDay >= durationDays) {
      // Challenge completed!
      await _db.update('dungeon_quests', {
        'status': 'completed',
        'current_day': currentDay,
        'daily_progress': jsonEncode(progress),
        'completed_at': DateTime.now().millisecondsSinceEpoch,
      }, where: 'id = ?', whereArgs: [id]);
    } else {
      await _db.update('dungeon_quests', {
        'current_day': currentDay,
        'daily_progress': jsonEncode(progress),
      }, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> failDungeon(String id) async {
    await _db.update('dungeon_quests', {
      'status': 'failed',
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> cancelDungeon(String id) async {
    await _db.update('dungeon_quests', {
      'status': 'available',
      'current_day': 0,
      'daily_progress': '[]',
      'started_at': null,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> completeQuest(String id) async {
    await _db.update('dungeon_quests', {
      'status': 'completed',
      'completed_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getCompletedDungeonCount() async {
    return await _db.count('dungeon_quests',
        where: "status = ?", whereArgs: ['completed']);
  }

  /// Auto-check all active dungeons against real usage data.
  Future<List<String>> autoCheckActiveDungeons() async {
    final active = await _db.queryWhere('dungeon_quests',
        where: "status = ?", whereArgs: ['active']);
    final autoCompleted = <String>[];
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    for (final quest in active) {
      final id = quest['id'] as String;
      final condType = quest['condition_type'] as String? ?? 'manual';
      final condValue = quest['condition_value'] as String? ?? '';
      final progress = List<String>.from(
          jsonDecode(quest['daily_progress'] as String? ?? '[]'));

      if (!isAutoTrackedType(condType)) continue;
      if (progress.any((p) => p.startsWith(todayKey))) continue;

      bool passed = false;
      switch (condType) {
        case 'max_screen_time':
          final limitMin = int.tryParse(condValue) ?? 60;
          final rows = await _db.queryWhere('app_usage',
              where: 'date_key = ?', whereArgs: [todayKey]);
          int totalSec = 0;
          for (final r in rows) {
            totalSec += (r['duration_seconds'] as int? ?? 0);
          }
          if (rows.isNotEmpty) passed = (totalSec / 60) <= limitMin;
          break;

        case 'no_phone_after':
          final parts = condValue.split(':');
          final limitHour = int.tryParse(parts.isNotEmpty ? parts[0] : '23') ?? 23;
          if (now.hour < 5) continue;
          final yesterday = now.subtract(const Duration(days: 1));
          final yKey = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
          final usageY = await _db.queryWhere('app_usage',
              where: 'date_key = ?', whereArgs: [yKey]);
          bool usedLate = false;
          for (final r in usageY) {
            final lastUsed = r['last_time_used'] as int? ?? 0;
            if (lastUsed > 0) {
              final t = DateTime.fromMillisecondsSinceEpoch(lastUsed);
              if (t.hour >= limitHour) { usedLate = true; break; }
            }
          }
          if (!usedLate) {
            final usageT = await _db.queryWhere('app_usage',
                where: 'date_key = ?', whereArgs: [todayKey]);
            for (final r in usageT) {
              final st = r['start_time'] as int? ?? 0;
              if (st > 0) {
                final t = DateTime.fromMillisecondsSinceEpoch(st);
                if (t.hour < 5) { usedLate = true; break; }
              }
            }
          }
          passed = !usedLate;
          break;

        case 'focus_session':
          final reqMin = int.tryParse(condValue) ?? 25;
          final sessions = await _db.queryWhere('focus_sessions',
              where: 'was_completed = 1');
          for (final s in sessions) {
            final ca = s['completed_at'] as int? ?? 0;
            if (ca > 0) {
              final d = DateTime.fromMillisecondsSinceEpoch(ca);
              final sKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              if (sKey == todayKey && (s['duration_minutes'] as int? ?? 0) >= reqMin) {
                passed = true; break;
              }
            }
          }
          break;
      }

      if (passed) {
        await completeDungeonDay(id);
        autoCompleted.add(id);
      }
    }
    return autoCompleted;
  }

  /// Returns true if this condition type is auto-tracked (no manual button)
  static bool isAutoTrackedType(String conditionType) {
    return conditionType == 'max_screen_time' ||
           conditionType == 'no_phone_after' ||
           conditionType == 'focus_session';
  }

  /// Check if user already manually checked in today
  Future<bool> hasCheckedInToday(String questId) async {
    final quest = await _db.queryFirst('dungeon_quests',
        where: 'id = ?', whereArgs: [questId]);
    if (quest == null) return true;
    final progress = List<String>.from(
        jsonDecode(quest['daily_progress'] as String? ?? '[]'));
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return progress.any((p) => p.startsWith(todayKey));
  }
}
