import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/main.dart';
import 'package:self_leveling/services/habit_reminder_service.dart';

void main() {
  testWidgets('App boots correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          habitReminderOrchestratorProvider.overrideWith((ref) {}),
        ],
        child: const SelfLevelingApp(),
      ),
    );
    expect(find.byType(SelfLevelingApp), findsOneWidget);

    // Dispose the app tree and let one-shot startup/background timers drain.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 3));
  });
}
