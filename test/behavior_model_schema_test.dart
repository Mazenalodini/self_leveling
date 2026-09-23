import 'package:flutter_test/flutter_test.dart';
import 'package:self_leveling/core/database/database_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Phase 10 behavior model tables are available locally', () async {
    final db = await DatabaseHelper.instance.database;

    final tables = await db.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name IN ('behavior_assessments', 'behavior_assessment_feedback')
      ''',
    );

    final tableNames = tables.map((row) => row['name']).toSet();
    expect(tableNames, contains('behavior_assessments'));
    expect(tableNames, contains('behavior_assessment_feedback'));

    final assessmentColumns =
        await db.rawQuery('PRAGMA table_info(behavior_assessments)');
    final assessmentColumnNames =
        assessmentColumns.map((row) => row['name']).toSet();
    expect(assessmentColumnNames, contains('deterministic_facts_json'));
    expect(assessmentColumnNames, contains('feature_snapshot_json'));
    expect(assessmentColumnNames, contains('risk_tier'));
    expect(assessmentColumnNames, contains('label_state'));

    final feedbackColumns =
        await db.rawQuery('PRAGMA table_info(behavior_assessment_feedback)');
    final feedbackColumnNames = feedbackColumns.map((row) => row['name']).toSet();
    expect(feedbackColumnNames, contains('assessment_id'));
    expect(feedbackColumnNames, contains('feedback_type'));
    expect(feedbackColumnNames, contains('feedback_value'));
    expect(feedbackColumnNames, contains('created_by'));
  });
}
