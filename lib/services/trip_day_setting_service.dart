import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_day_setting.dart';

class TripDaySettingService {
  static final TripDaySettingService _instance = TripDaySettingService._internal();
  factory TripDaySettingService() => _instance;
  TripDaySettingService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id ?? _client.auth.currentSession?.user.id;
    } catch (_) {
      return null;
    }
  }

  Future<List<TripDaySetting>> getSettingsForTrip(int tripId) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('trip_day_settings')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .order('visit_date', ascending: true);

      final List<dynamic> list = response as List<dynamic>;
      final List<TripDaySetting> settings = [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            settings.add(TripDaySetting.fromJson(item));
          } catch (e, stack) {
            debugPrint('[TripDaySettingService] Failed to parse day setting: $e\n$stack');
          }
        }
      }
      return settings;
    } catch (e, stack) {
      debugPrint('[TripDaySettingService] Error getSettingsForTrip: $e\n$stack');
      return [];
    }
  }

  Future<TripDaySetting?> saveDayStartOverride({
    required int tripId,
    required DateTime visitDate,
    required String locationName,
    required double latitude,
    required double longitude,
    String? locationId,
    String? sourceType,
    String? address,
  }) async {
    final userId = currentUserId;
    if (userId == null) return null;

    final dateStr = DateFormat('yyyy-MM-dd').format(visitDate);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    final payload = {
      'trip_id': tripId,
      'user_id': userId,
      'visit_date': dateStr,
      'start_location_id': locationId,
      'start_location_name': locationName,
      'start_latitude': latitude,
      'start_longitude': longitude,
      'source_type': sourceType,
      'address': address,
      'updated_at': nowIso,
    };

    try {
      final response = await _client
          .from('trip_day_settings')
          .upsert(payload, onConflict: 'trip_id,visit_date')
          .select()
          .single();

      return TripDaySetting.fromJson(response);
    } catch (e, stack) {
      debugPrint('[TripDaySettingService] Error saveDayStartOverride: $e\n$stack');
      return null;
    }
  }

  Future<bool> deleteDayStartOverride(int tripId, DateTime visitDate) async {
    final userId = currentUserId;
    if (userId == null) return false;

    final dateStr = DateFormat('yyyy-MM-dd').format(visitDate);

    try {
      await _client
          .from('trip_day_settings')
          .delete()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .eq('visit_date', dateStr);
      return true;
    } catch (e, stack) {
      debugPrint('[TripDaySettingService] Error deleteDayStartOverride: $e\n$stack');
      return false;
    }
  }

  Future<void> deleteSettingsForTrip(int tripId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await _client
          .from('trip_day_settings')
          .delete()
          .eq('trip_id', tripId)
          .eq('user_id', userId);
    } catch (e, stack) {
      debugPrint('[TripDaySettingService] Error deleteSettingsForTrip: $e\n$stack');
    }
  }
}
