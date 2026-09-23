import 'package:sqflite/sqflite.dart';

import '../../core/database/database_helper.dart';
import '../../domain/contracts/runtime_contract.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/user_profile.dart';

class SettingsRepository {
  final DatabaseHelper _db = DatabaseHelper.instance;

  Future<AppSettings> getSettings() async {
    final rows = await _db.queryAll('settings');
    final keyValues = <String, String>{
      for (final row in rows)
        row['key'] as String: row['value'] as String? ?? '',
    };
    final legacyProfileRow = await _db.queryFirst(
      'user_profile',
      where: 'id = ?',
      whereArgs: [UserProfile.canonicalLocalId],
    );
    return AppSettings.fromStorage(
      keyValues: keyValues,
      legacyProfileRow: legacyProfileRow,
    );
  }

  Future<void> saveSettings(AppSettings settings) async {
    final db = await _db.database;
    final batch = db.batch();
    for (final entry in settings.toStorageMap().entries) {
      batch.insert(
        'settings',
        {'key': entry.key, 'value': entry.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    batch.update(
      'user_profile',
      {
        RuntimeSettingKeys.systemSensitivity: settings.systemSensitivity,
        RuntimeSettingKeys.escalationStrength: settings.escalationStrength,
        RuntimeSettingKeys.notificationsEnabled:
            settings.notificationsEnabled ? 1 : 0,
      },
      where: 'id = ?',
      whereArgs: [UserProfile.canonicalLocalId],
    );
    await batch.commit(noResult: true);
  }

  Future<double?> getDouble(String key) async {
    final row = await _db.queryFirst(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return row == null ? null : double.tryParse(row['value'] as String);
  }

  Future<String?> getString(String key) async {
    final row = await _db.queryFirst(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    return row?['value'] as String?;
  }

  Future<void> setDouble(String key, double value) async {
    await _setValue(key, value.toString());
  }

  Future<void> setBool(String key, bool value) async {
    await _setValue(key, value ? '1' : '0');
  }

  Future<void> _setValue(String key, String value) async {
    await _db.insert('settings', {'key': key, 'value': value});
  }
}
