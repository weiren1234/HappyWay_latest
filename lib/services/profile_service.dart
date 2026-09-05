import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_preferences.dart';

class ProfileService {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      return data;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateDisplayName(String userId, String displayName) async {
    await _client.from('profiles').update({
      'display_name': displayName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<UserPreferences?> getUserPreferences(String userId) async {
    try {
      final data = await _client
          .from('user_preferences')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (data == null) return null;
      return UserPreferences.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUserPreferences(
    String userId, {
    bool? tripRemindersEnabled,
    String? themeMode,
  }) async {
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (tripRemindersEnabled != null) {
      updates['trip_reminders_enabled'] = tripRemindersEnabled;
    }
    if (themeMode != null) {
      updates['theme_mode'] = themeMode;
    }

    await _client
        .from('user_preferences')
        .update(updates)
        .eq('user_id', userId);
  }
}
