import 'package:equatable/equatable.dart';

class AppPolicy extends Equatable {
  static const blacklistType = 'blacklist';
  static const whitelistType = 'whitelist';
  static const limitType = 'limit';

  final int? id;
  final String name;
  final String packageName;
  final String listType;
  final String tag;
  final bool isEnabled;
  final int dailyLimitMinutes;
  final int? categoryOverride;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AppPolicy({
    this.id,
    required this.name,
    required this.packageName,
    required this.listType,
    this.tag = '',
    this.isEnabled = true,
    this.dailyLimitMinutes = 0,
    this.categoryOverride,
    this.notes = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isBlacklist => listType == blacklistType;
  bool get isWhitelist => listType == whitelistType;
  bool get isLimitPolicy => listType == limitType;
  bool get hasLimit => dailyLimitMinutes > 0;
  bool get isBlockRule => isBlacklist && !hasLimit;
  bool get isLimitOnlyRule => isLimitPolicy && hasLimit;

  AppPolicy copyWith({
    int? id,
    String? name,
    String? packageName,
    String? listType,
    String? tag,
    bool? isEnabled,
    int? dailyLimitMinutes,
    int? categoryOverride,
    bool clearCategoryOverride = false,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppPolicy(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      listType: listType ?? this.listType,
      tag: tag ?? this.tag,
      isEnabled: isEnabled ?? this.isEnabled,
      dailyLimitMinutes: dailyLimitMinutes ?? this.dailyLimitMinutes,
      categoryOverride: clearCategoryOverride
          ? null
          : (categoryOverride ?? this.categoryOverride),
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory AppPolicy.fromMap(Map<String, dynamic> row) {
    return AppPolicy(
      id: row['id'] as int?,
      name: row['name'] as String? ?? '',
      packageName: row['package_name'] as String? ?? '',
      listType: row['list_type'] as String? ?? blacklistType,
      tag: row['tag'] as String? ?? '',
      isEnabled: (row['is_enabled'] as int? ?? 1) == 1,
      dailyLimitMinutes: row['daily_limit_minutes'] as int? ?? 0,
      categoryOverride: row['category_override'] as int?,
      notes: row['notes'] as String? ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int? ?? 0,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int? ?? row['created_at'] as int? ?? 0,
      ),
    );
  }

  Map<String, dynamic> toDbMap() => {
        if (id != null) 'id': id,
        'name': name,
        'package_name': packageName,
        'list_type': listType,
        'tag': tag,
        'is_enabled': isEnabled ? 1 : 0,
        'daily_limit_minutes': dailyLimitMinutes,
        'category_override': categoryOverride,
        'notes': notes,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  Map<String, dynamic> toLegacyMap() => toDbMap();

  @override
  List<Object?> get props => [
        id,
        name,
        packageName,
        listType,
        tag,
        isEnabled,
        dailyLimitMinutes,
        categoryOverride,
        notes,
        createdAt,
        updatedAt,
      ];
}
