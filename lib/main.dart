import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'core/database/database_helper.dart';
import 'core/theme/app_theme.dart';
import 'navigation/app_router.dart';
import 'services/behavior_service.dart';
import 'services/habit_service.dart';
import 'services/xp_service.dart';
import 'services/focus_service.dart';
import 'services/permission_manager.dart';
import 'providers/system_provider.dart';
import 'providers/habit_provider.dart';
import 'providers/focus_provider.dart';
import 'providers/app_init_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/report_provider.dart';
import 'features/ai/services/ai_bridge_service.dart';
import 'services/habit_reminder_service.dart';

import 'core/constants/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST
  try {
    await Firebase.initializeApp();

    // Activate Firebase App Check — secures all Firebase services
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
    );
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  // Load locale preference
  await AppStrings.load();

  // Initialize SQLite database
  await DatabaseHelper.instance.database;

  // Initialize services
  final behaviorService = BehaviorService();
  await behaviorService.init();
  behaviorService.startPolling();

  final habitService = HabitService();
  await habitService.init();

  final xpService = XPService();
  await xpService.init();

  final focusService = FocusService();
  await focusService.init();

  final permissionManager = PermissionManager();
  await permissionManager.init();
  // Phase 1 contract stabilization:
  // Flutter startup prepares UI/services but does NOT auto-activate the native
  // enforcement engine. Runtime activation remains an explicit setup flow.

  // Load initial profile from DB (async)
  final initialProfile = await xpService.getProfile();

  // Reset daily habits if needed
  await habitService.resetDailyCompletions();

  // Allow Google Fonts runtime fetching
  GoogleFonts.config.allowRuntimeFetching = true;

  runApp(
    ProviderScope(
      overrides: [
        behaviorServiceProvider.overrideWithValue(behaviorService),
        habitServiceProvider.overrideWithValue(habitService),
        xpServiceProvider.overrideWithValue(xpService),
        focusServiceProvider.overrideWithValue(focusService),
        permissionManagerProvider.overrideWithValue(permissionManager),
        systemProvider.overrideWith((ref) {
          return SystemNotifier(
            xpService: xpService,
            behaviorService: behaviorService,
            initialProfile: initialProfile,
          );
        }),
      ],
      child: const SelfLevelingApp(),
    ),
  );
}

class SelfLevelingApp extends ConsumerStatefulWidget {
  const SelfLevelingApp({super.key});

  @override
  ConsumerState<SelfLevelingApp> createState() => _SelfLevelingAppState();
}

class _SelfLevelingAppState extends ConsumerState<SelfLevelingApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    unawaited(ref.read(behaviorServiceProvider).refreshTodayUsage(days: 7));
    ref.read(reportRefreshVersionProvider.notifier).markDirty();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);

    // Initialize AI Bridge for Native-Flutter communication
    ref.watch(aiBridgeServiceProvider);
    // Initialize Habit Reminder Pipeline (auto-syncs on state change)
    ref.watch(habitReminderOrchestratorProvider);

    return MaterialApp.router(
      title: 'Self Leveling',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
      locale: locale,
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        return Directionality(
          textDirection: locale.languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: child!,
        );
      },
    );
  }
}
