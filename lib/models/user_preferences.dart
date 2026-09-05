
class UserPreferences {
  final String userId;
  final bool tripRemindersEnabled;
  final String themeMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserPreferences({
    required this.userId,
    this.tripRemindersEnabled = true,
    this.themeMode = 'dark',
    this.createdAt,
    this.updatedAt,
  });

  UserPreferences copyWith({
    String? userId,
    bool? tripRemindersEnabled,
    String? themeMode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserPreferences(
      userId: userId ?? this.userId,
      tripRemindersEnabled: tripRemindersEnabled ?? this.tripRemindersEnabled,
      themeMode: themeMode ?? this.themeMode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      userId: json['user_id'] as String? ?? '',
      tripRemindersEnabled: json['trip_reminders_enabled'] as bool? ?? true,
      themeMode: json['theme_mode'] as String? ?? 'dark',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'trip_reminders_enabled': tripRemindersEnabled,
      'theme_mode': themeMode,
    };
  }
}
