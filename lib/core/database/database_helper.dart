import 'package:sqflite/sqflite.dart';

/// Central SQLite database manager.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('self_leveling.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$filePath';
    return await openDatabase(
      path,
      version: 14,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      // sqflite expects PRAGMA statements that return rows to go through
      // rawQuery/query, not execute().
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA busy_timeout = 3000');
      },
      singleInstance: true,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await _migrateToV5(db);
    }
    if (oldVersion < 6) {
      await _migrateToV6(db);
    }
    if (oldVersion < 7) {
      await _migrateToV7(db);
    }
    if (oldVersion < 8) {
      await _migrateToV8(db);
    }
    if (oldVersion < 9) {
      await _migrateToV9(db);
    }
    if (oldVersion < 10) {
      await _migrateToV10(db);
    }
    if (oldVersion < 11) {
      await _migrateToV11(db);
    }
    if (oldVersion < 12) {
      await _migrateToV12(db);
    }
    if (oldVersion < 13) {
      await _migrateToV13(db);
    }
    if (oldVersion < 14) {
      await _migrateToV14(db);
    }
  }

  Future<void> _createDB(Database db, int version) async {
    // ═══════════════════════════════════════════
    // User Profile
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE user_profile (
        id TEXT PRIMARY KEY,
        account_uid TEXT,
        display_name TEXT NOT NULL DEFAULT 'User',
        identity_statement TEXT DEFAULT '',
        email TEXT DEFAULT '',
        level INTEGER DEFAULT 1,
        current_xp INTEGER DEFAULT 0,
        total_xp_earned INTEGER DEFAULT 0,
        self_control_score INTEGER DEFAULT 50,
        system_sensitivity REAL DEFAULT 0.5,
        escalation_strength REAL DEFAULT 0.5,
        notifications_enabled INTEGER DEFAULT 1,
        occupation TEXT DEFAULT '',
        primary_identity TEXT DEFAULT '',
        frustration_points_json TEXT DEFAULT '[]',
        distraction_categories_json TEXT DEFAULT '[]',
        weakness_window TEXT DEFAULT '',
        emotional_trigger TEXT DEFAULT '',
        target_habits_json TEXT DEFAULT '[]',
        break_target TEXT DEFAULT '',
        install_reason TEXT DEFAULT '',
        strictness_preference TEXT DEFAULT '',
        message_style_preference TEXT DEFAULT '',
        intervention_preference TEXT DEFAULT '',
        preferred_habit_size TEXT DEFAULT '',
        open_reflections_json TEXT DEFAULT '{}',
        survey_language TEXT DEFAULT 'en',
        observed_profile_json TEXT DEFAULT '{}',
        reconciliation_confidence REAL DEFAULT 1.0,
        created_at INTEGER NOT NULL,
        last_active_at INTEGER NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // Habits
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE habits (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        type INTEGER NOT NULL DEFAULT 0,
        frequency INTEGER NOT NULL DEFAULT 0,
        current_streak INTEGER DEFAULT 0,
        longest_streak INTEGER DEFAULT 0,
        xp_reward INTEGER DEFAULT 10,
        reminder_time TEXT,
        sort_order INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Habit daily completions (one row per habit per day)
    await db.execute('''
      CREATE TABLE habit_completions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        habit_id TEXT NOT NULL,
        completed_at INTEGER NOT NULL,
        date_key TEXT NOT NULL,
        FOREIGN KEY (habit_id) REFERENCES habits(id) ON DELETE CASCADE,
        UNIQUE(habit_id, date_key)
      )
    ''');

    // ═══════════════════════════════════════════
    // Focus Sessions
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE focus_sessions (
        id TEXT PRIMARY KEY,
        duration_minutes INTEGER NOT NULL,
        started_at INTEGER NOT NULL,
        completed_at INTEGER,
        was_completed INTEGER DEFAULT 0,
        xp_earned INTEGER DEFAULT 0
      )
    ''');

    // ═══════════════════════════════════════════
    // Behavior Records (aggregated)
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE behavior_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp INTEGER NOT NULL,
        productive_seconds INTEGER DEFAULT 0,
        neutral_seconds INTEGER DEFAULT 0,
        distracting_seconds INTEGER DEFAULT 0,
        session_count INTEGER DEFAULT 0,
        top_distracting_app TEXT,
        date_key TEXT UNIQUE
      )
    ''');

    // App usage records (one row per app per day).
    // Canonical writer: Android NativeUsageSnapshotStore.
    await db.execute('''
      CREATE TABLE app_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        package_name TEXT NOT NULL,
        app_name TEXT NOT NULL,
        category INTEGER DEFAULT 1,
        start_time INTEGER NOT NULL,
        duration_seconds INTEGER DEFAULT 0,
        launch_count INTEGER DEFAULT 0,
        last_time_used INTEGER DEFAULT 0,
        date_key TEXT DEFAULT '',
        UNIQUE(package_name, date_key)
      )
    ''');

    // ═══════════════════════════════════════════
    // App Blacklist/Whitelist
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE app_list (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        package_name TEXT DEFAULT '',
        list_type TEXT NOT NULL DEFAULT 'blacklist',
        tag TEXT DEFAULT '',
        is_enabled INTEGER DEFAULT 1,
        daily_limit_minutes INTEGER DEFAULT 0,
        category_override INTEGER,
        notes TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // Escalation Events
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE escalation_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        runtime_event_id TEXT,
        event_type TEXT DEFAULT 'transition',
        from_level INTEGER NOT NULL,
        to_level INTEGER NOT NULL,
        stage INTEGER DEFAULT 0,
        timestamp INTEGER NOT NULL,
        reason TEXT DEFAULT '',
        package_name TEXT DEFAULT '',
        risk_score REAL DEFAULT 0.0,
        reentry_count INTEGER DEFAULT 0,
        xp_penalty INTEGER DEFAULT 0,
        created_by TEXT DEFAULT 'native'
      )
    ''');

    await db.execute('''
      CREATE TABLE runtime_active_state (
        id TEXT PRIMARY KEY,
        contract_version INTEGER DEFAULT 1,
        engine_activation_requested INTEGER DEFAULT 0,
        engine_running INTEGER DEFAULT 0,
        focus_mode_active INTEGER DEFAULT 0,
        current_stage INTEGER DEFAULT 0,
        current_app_package TEXT,
        overlay_visible INTEGER DEFAULT 0,
        risk_score REAL DEFAULT 0.0,
        blocked_app_package TEXT,
        lock_until_ms INTEGER DEFAULT 0,
        reentry_count INTEGER DEFAULT 0,
        is_limited_access INTEGER DEFAULT 0,
        limited_access_until_ms INTEGER DEFAULT 0,
        limited_access_app_package TEXT,
        active_intervention_id TEXT,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE progression_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_key TEXT NOT NULL UNIQUE,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        effective_xp_delta INTEGER NOT NULL DEFAULT 0,
        earned_xp_delta INTEGER NOT NULL DEFAULT 0,
        self_control_delta INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        metadata_json TEXT DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE message_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_key TEXT NOT NULL UNIQUE,
        runtime_event_id TEXT DEFAULT '',
        source TEXT NOT NULL DEFAULT 'local',
        request_kind TEXT NOT NULL,
        output_channel TEXT NOT NULL,
        stage INTEGER DEFAULT 0,
        package_name TEXT DEFAULT '',
        app_name TEXT DEFAULT '',
        app_category INTEGER DEFAULT 1,
        headline TEXT NOT NULL,
        body TEXT NOT NULL,
        action_label TEXT,
        recommendation_title TEXT,
        recommendation_text TEXT,
        tone TEXT DEFAULT '',
        language TEXT DEFAULT 'en',
        delivery_status TEXT DEFAULT 'generated',
        generated_at INTEGER NOT NULL,
        shown_at INTEGER,
        context_json TEXT DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE message_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_key TEXT NOT NULL,
        feedback_type TEXT NOT NULL,
        feedback_note TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        UNIQUE(history_key, feedback_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE behavior_assessments (
        assessment_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        assessor_kind TEXT NOT NULL,
        assessor_version TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT DEFAULT '',
        app_category INTEGER DEFAULT 1,
        effective_policy TEXT DEFAULT 'neutral_monitor',
        current_stage INTEGER DEFAULT 0,
        runtime_event_id TEXT,
        risk_score REAL NOT NULL DEFAULT 0.0,
        risk_tier TEXT NOT NULL,
        confidence REAL,
        reasoning TEXT DEFAULT '',
        deterministic_facts_json TEXT DEFAULT '{}',
        feature_snapshot_json TEXT DEFAULT '{}',
        label_state TEXT DEFAULT 'unlabeled'
      )
    ''');

    await db.execute('''
      CREATE TABLE behavior_assessment_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id TEXT NOT NULL,
        feedback_type TEXT NOT NULL,
        feedback_value TEXT NOT NULL,
        package_name TEXT DEFAULT '',
        note TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        created_by TEXT DEFAULT 'user',
        UNIQUE(assessment_id, feedback_type, created_by)
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_chat_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        language TEXT NOT NULL DEFAULT 'en',
        last_preview TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE ai_chat_messages (
        id TEXT PRIMARY KEY,
        thread_id TEXT NOT NULL,
        role TEXT NOT NULL,
        body TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'local',
        provider_name TEXT,
        model_name TEXT,
        status TEXT NOT NULL DEFAULT 'complete',
        created_at INTEGER NOT NULL,
        context_json TEXT DEFAULT '{}',
        error_text TEXT
      )
    ''');

    // ═══════════════════════════════════════════
    // Settings (key-value store for misc config)
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // Skills (Gamification)
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE skills (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        branch TEXT NOT NULL,
        is_unlocked INTEGER DEFAULT 0,
        level INTEGER DEFAULT 0,
        max_level INTEGER DEFAULT 5,
        sort_order INTEGER DEFAULT 0,
        requires_skill_id TEXT,
        icon_name TEXT DEFAULT 'star',
        xp_reward INTEGER DEFAULT 25,
        last_upgraded_at INTEGER,
        created_at INTEGER NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // User Identities (Gamification)
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE user_identities (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        subtitle TEXT DEFAULT '',
        icon_code INTEGER DEFAULT 0,
        color_hex INTEGER DEFAULT 0,
        selected INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // Dungeon Quests (Gamification)
    // ═══════════════════════════════════════════
    await db.execute('''
      CREATE TABLE dungeon_quests (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        description TEXT DEFAULT '',
        boss_name TEXT DEFAULT '',
        icon_name TEXT DEFAULT 'dangerous',
        color_hex INTEGER DEFAULT 0xFFE11D48,
        reward_xp INTEGER DEFAULT 50,
        is_ai_generated INTEGER DEFAULT 0,
        status TEXT DEFAULT 'available',
        started_at INTEGER,
        completed_at INTEGER,
        duration_days INTEGER DEFAULT 3,
        current_day INTEGER DEFAULT 0,
        condition_type TEXT DEFAULT 'manual',
        condition_value TEXT DEFAULT '',
        daily_progress TEXT DEFAULT '[]',
        weaknesses TEXT DEFAULT '[]',
        is_default INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');

    // ═══════════════════════════════════════════
    // Create default profile
    // ═══════════════════════════════════════════
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('user_profile', {
      'id': 'default',
      'account_uid': null,
      'display_name': 'User',
      'identity_statement': '',
      'email': '',
      'level': 1,
      'current_xp': 0,
      'total_xp_earned': 0,
      'self_control_score': 50,
      'system_sensitivity': 0.5,
      'escalation_strength': 0.5,
      'notifications_enabled': 1,
      'occupation': '',
      'primary_identity': '',
      'frustration_points_json': '[]',
      'distraction_categories_json': '[]',
      'weakness_window': '',
      'emotional_trigger': '',
      'target_habits_json': '[]',
      'break_target': '',
      'install_reason': '',
      'strictness_preference': '',
      'message_style_preference': '',
      'intervention_preference': '',
      'preferred_habit_size': '',
      'open_reflections_json': '{}',
      'survey_language': 'en',
      'observed_profile_json': '{}',
      'reconciliation_confidence': 1.0,
      'created_at': now,
      'last_active_at': now,
    });

    await _seedDefaultSettings(db);
    await _createIndexes(db);
    await _createAIChatIndexes(db);
    await _createBehaviorModelIndexes(db);
  }

  Future<void> _migrateToV5(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await _addColumnIfMissing(db, 'user_profile', 'account_uid TEXT');
    await _addColumnIfMissing(
      db,
      'user_profile',
      "occupation TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "primary_identity TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "frustration_points_json TEXT DEFAULT '[]'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "distraction_categories_json TEXT DEFAULT '[]'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "weakness_window TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "emotional_trigger TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "target_habits_json TEXT DEFAULT '[]'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "break_target TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "install_reason TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "strictness_preference TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "message_style_preference TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "intervention_preference TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "preferred_habit_size TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "open_reflections_json TEXT DEFAULT '{}'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "survey_language TEXT DEFAULT 'en'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      "observed_profile_json TEXT DEFAULT '{}'",
    );
    await _addColumnIfMissing(
      db,
      'user_profile',
      'reconciliation_confidence REAL DEFAULT 1.0',
    );

    await _addColumnIfMissing(db, 'app_list', 'category_override INTEGER');
    await _addColumnIfMissing(db, 'app_list', "notes TEXT DEFAULT ''");
    await _addColumnIfMissing(
      db,
      'app_list',
      'updated_at INTEGER NOT NULL DEFAULT 0',
    );

    final defaultCount = Sqflite.firstIntValue(
          await db.rawQuery(
            "SELECT COUNT(*) FROM user_profile WHERE id = 'default'",
          ),
        ) ??
        0;
    if (defaultCount == 0) {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('user_profile', {
        'id': 'default',
        'display_name': 'User',
        'identity_statement': '',
        'email': '',
        'level': 1,
        'current_xp': 0,
        'total_xp_earned': 0,
        'self_control_score': 50,
        'system_sensitivity': 0.5,
        'escalation_strength': 0.5,
        'notifications_enabled': 1,
        'created_at': now,
        'last_active_at': now,
      });
    }

    await db.execute(
      'UPDATE app_list SET updated_at = created_at WHERE updated_at = 0',
    );
    await _seedDefaultSettings(db);
    await _createIndexes(db);
  }

  Future<void> _migrateToV6(Database db) async {
    await _addColumnIfMissing(db, 'escalation_events', 'runtime_event_id TEXT');
    await _addColumnIfMissing(
      db,
      'escalation_events',
      "event_type TEXT DEFAULT 'transition'",
    );
    await _addColumnIfMissing(
        db, 'escalation_events', 'stage INTEGER DEFAULT 0');
    await _addColumnIfMissing(
      db,
      'escalation_events',
      "package_name TEXT DEFAULT ''",
    );
    await _addColumnIfMissing(
      db,
      'escalation_events',
      'risk_score REAL DEFAULT 0.0',
    );
    await _addColumnIfMissing(
      db,
      'escalation_events',
      'reentry_count INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'escalation_events',
      'xp_penalty INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'escalation_events',
      "created_by TEXT DEFAULT 'native'",
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS runtime_active_state (
        id TEXT PRIMARY KEY,
        contract_version INTEGER DEFAULT 1,
        engine_activation_requested INTEGER DEFAULT 0,
        engine_running INTEGER DEFAULT 0,
        focus_mode_active INTEGER DEFAULT 0,
        current_stage INTEGER DEFAULT 0,
        current_app_package TEXT,
        overlay_visible INTEGER DEFAULT 0,
        risk_score REAL DEFAULT 0.0,
        blocked_app_package TEXT,
        lock_until_ms INTEGER DEFAULT 0,
        reentry_count INTEGER DEFAULT 0,
        is_limited_access INTEGER DEFAULT 0,
        limited_access_until_ms INTEGER DEFAULT 0,
        limited_access_app_package TEXT,
        active_intervention_id TEXT,
        updated_at INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _migrateToV7(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS progression_ledger (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        event_key TEXT NOT NULL UNIQUE,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        effective_xp_delta INTEGER NOT NULL DEFAULT 0,
        earned_xp_delta INTEGER NOT NULL DEFAULT 0,
        self_control_delta INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        metadata_json TEXT DEFAULT '{}'
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _migrateToV8(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_key TEXT NOT NULL UNIQUE,
        runtime_event_id TEXT DEFAULT '',
        source TEXT NOT NULL DEFAULT 'local',
        request_kind TEXT NOT NULL,
        output_channel TEXT NOT NULL,
        stage INTEGER DEFAULT 0,
        package_name TEXT DEFAULT '',
        app_name TEXT DEFAULT '',
        app_category INTEGER DEFAULT 1,
        headline TEXT NOT NULL,
        body TEXT NOT NULL,
        action_label TEXT,
        recommendation_title TEXT,
        recommendation_text TEXT,
        tone TEXT DEFAULT '',
        language TEXT DEFAULT 'en',
        delivery_status TEXT DEFAULT 'generated',
        generated_at INTEGER NOT NULL,
        shown_at INTEGER,
        context_json TEXT DEFAULT '{}'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS message_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        history_key TEXT NOT NULL,
        feedback_type TEXT NOT NULL,
        feedback_note TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        UNIQUE(history_key, feedback_type)
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _migrateToV9(Database db) async {
    await _createIndexes(db);
  }

  Future<void> _migrateToV10(Database db) async {
    await _addColumnIfMissing(
      db,
      'app_usage',
      'launch_count INTEGER DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      'app_usage',
      'last_time_used INTEGER DEFAULT 0',
    );
    await _createIndexes(db);
  }

  Future<void> _migrateToV11(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_chat_threads (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        language TEXT NOT NULL DEFAULT 'en',
        last_preview TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ai_chat_messages (
        id TEXT PRIMARY KEY,
        thread_id TEXT NOT NULL,
        role TEXT NOT NULL,
        body TEXT NOT NULL,
        source TEXT NOT NULL DEFAULT 'local',
        provider_name TEXT,
        model_name TEXT,
        status TEXT NOT NULL DEFAULT 'complete',
        created_at INTEGER NOT NULL,
        context_json TEXT DEFAULT '{}',
        error_text TEXT
      )
    ''');

    await _createIndexes(db);
    await _createAIChatIndexes(db);
  }

  Future<void> _migrateToV12(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS behavior_assessments (
        assessment_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        source TEXT NOT NULL,
        assessor_kind TEXT NOT NULL,
        assessor_version TEXT NOT NULL,
        package_name TEXT NOT NULL,
        app_name TEXT DEFAULT '',
        app_category INTEGER DEFAULT 1,
        effective_policy TEXT DEFAULT 'neutral_monitor',
        current_stage INTEGER DEFAULT 0,
        runtime_event_id TEXT,
        risk_score REAL NOT NULL DEFAULT 0.0,
        risk_tier TEXT NOT NULL,
        confidence REAL,
        reasoning TEXT DEFAULT '',
        deterministic_facts_json TEXT DEFAULT '{}',
        feature_snapshot_json TEXT DEFAULT '{}',
        label_state TEXT DEFAULT 'unlabeled'
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS behavior_assessment_feedback (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id TEXT NOT NULL,
        feedback_type TEXT NOT NULL,
        feedback_value TEXT NOT NULL,
        package_name TEXT DEFAULT '',
        note TEXT DEFAULT '',
        created_at INTEGER NOT NULL,
        created_by TEXT DEFAULT 'user',
        UNIQUE(assessment_id, feedback_type, created_by)
      )
    ''');

    await _createIndexes(db);
    await _createBehaviorModelIndexes(db);
  }

  Future<void> _migrateToV13(Database db) async {
    // Dungeon quests: add tracking columns
    await _addColumnIfMissing(db, 'dungeon_quests', "boss_name TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'dungeon_quests', "icon_name TEXT DEFAULT 'dangerous'");
    await _addColumnIfMissing(db, 'dungeon_quests', 'color_hex INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'dungeon_quests', "status TEXT DEFAULT 'available'");
    await _addColumnIfMissing(db, 'dungeon_quests', 'started_at INTEGER');
    await _addColumnIfMissing(db, 'dungeon_quests', 'completed_at INTEGER');
    await _addColumnIfMissing(db, 'dungeon_quests', 'duration_days INTEGER DEFAULT 3');
    await _addColumnIfMissing(db, 'dungeon_quests', 'current_day INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'dungeon_quests', "condition_type TEXT DEFAULT 'manual'");
    await _addColumnIfMissing(db, 'dungeon_quests', "condition_value TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'dungeon_quests', "daily_progress TEXT DEFAULT '[]'");
    await _addColumnIfMissing(db, 'dungeon_quests', "weaknesses TEXT DEFAULT '[]'");
    await _addColumnIfMissing(db, 'dungeon_quests', 'is_default INTEGER DEFAULT 0');
    // Migrate old is_completed to new status
    await db.execute("UPDATE dungeon_quests SET status = 'completed' WHERE is_completed = 1 AND status = 'available'");

    // Skills: add new columns
    await _addColumnIfMissing(db, 'skills', "description TEXT DEFAULT ''");
    await _addColumnIfMissing(db, 'skills', 'sort_order INTEGER DEFAULT 0');
    await _addColumnIfMissing(db, 'skills', 'requires_skill_id TEXT');
    await _addColumnIfMissing(db, 'skills', "icon_name TEXT DEFAULT 'star'");
    await _addColumnIfMissing(db, 'skills', 'xp_reward INTEGER DEFAULT 25');
  }

  Future<void> _migrateToV14(Database db) async {
    await _addColumnIfMissing(db, 'skills', 'last_upgraded_at INTEGER');
  }

  Future<void> _seedDefaultSettings(Database db) async {
    final profile = await db.query(
      'user_profile',
      columns: [
        'system_sensitivity',
        'escalation_strength',
        'notifications_enabled',
      ],
      where: 'id = ?',
      whereArgs: ['default'],
      limit: 1,
    );
    final row = profile.isNotEmpty ? profile.first : const <String, Object?>{};

    await _seedSettingIfMissing(
      db,
      'system_sensitivity',
      ((row['system_sensitivity'] as num?)?.toDouble() ?? 0.5).toString(),
    );
    await _seedSettingIfMissing(
      db,
      'escalation_strength',
      ((row['escalation_strength'] as num?)?.toDouble() ?? 0.5).toString(),
    );
    await _seedSettingIfMissing(
      db,
      'notifications_enabled',
      ((row['notifications_enabled'] as int?) == 1 ? '1' : '0'),
    );
    await _seedSettingIfMissing(db, 'warning_delay', '3');
    await _seedSettingIfMissing(db, 'overlay_duration', '10');
    await _seedSettingIfMissing(db, 'hard_lock_duration', '45');
  }

  Future<void> _seedSettingIfMissing(
    Database db,
    String key,
    String value,
  ) async {
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_list_package_name ON app_list(package_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_list_list_type ON app_list(list_type)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_usage_date_key ON app_usage(date_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_usage_date_package ON app_usage(date_key, package_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_app_usage_date_last_used ON app_usage(date_key, last_time_used DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_focus_sessions_started_completed ON focus_sessions(started_at, was_completed)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_habit_completions_date_key ON habit_completions(date_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_escalation_events_timestamp ON escalation_events(timestamp)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_escalation_events_package_name ON escalation_events(package_name)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_escalation_events_runtime_event_id ON escalation_events(runtime_event_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_progression_ledger_event_key ON progression_ledger(event_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_progression_ledger_created_at ON progression_ledger(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_progression_ledger_source_type ON progression_ledger(source_type)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_message_history_key ON message_history(history_key)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_message_history_generated_at ON message_history(generated_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_message_history_runtime_event_id ON message_history(runtime_event_id)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_message_feedback_history_type ON message_feedback(history_key, feedback_type)',
    );
  }

  Future<void> _createAIChatIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chat_threads_updated_at ON ai_chat_threads(updated_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_ai_chat_messages_thread_created ON ai_chat_messages(thread_id, created_at ASC)',
    );
  }

  Future<void> _createBehaviorModelIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_assessments_created_at ON behavior_assessments(created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_assessments_package_created ON behavior_assessments(package_name, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_assessments_risk_tier ON behavior_assessments(risk_tier, created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_behavior_assessment_feedback_assessment ON behavior_assessment_feedback(assessment_id, created_at DESC)',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String table,
    String columnDefinition,
  ) async {
    final columnName = columnDefinition.split(' ').first;
    final exists = await _columnExists(db, table, columnName);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnDefinition');
    }
  }

  Future<bool> _columnExists(Database db, String table, String column) async {
    final result = await db.rawQuery('PRAGMA table_info($table)');
    return result.any((row) => row['name'] == column);
  }

  // ═══════════════════════════════════════════
  // Generic helpers
  // ═══════════════════════════════════════════

  Future<int> insert(String table, Map<String, dynamic> row) async {
    final db = await database;
    return await db.insert(table, row,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> queryAll(String table) async {
    final db = await database;
    return await db.query(table);
  }

  Future<List<Map<String, dynamic>>> queryWhere(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(table,
        where: where, whereArgs: whereArgs, orderBy: orderBy, limit: limit);
  }

  Future<int> update(
    String table,
    Map<String, dynamic> row, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, row, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<Map<String, dynamic>?> queryFirst(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final results =
        await db.query(table, where: where, whereArgs: whereArgs, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> count(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM $table${where != null ? ' WHERE $where' : ''}',
      whereArgs,
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Execute a raw INSERT/REPLACE SQL statement.
  Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawInsert(sql, arguments);
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
