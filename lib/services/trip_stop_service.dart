import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trip_stop.dart';

class TripStopService {
  static final TripStopService _instance = TripStopService._internal();
  factory TripStopService() => _instance;
  TripStopService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  String? get currentUserId {
    try {
      return _client.auth.currentUser?.id ?? _client.auth.currentSession?.user.id;
    } catch (_) {
      return null;
    }
  }

  Future<List<TripStop>> getStopsForTrip(int tripId) async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('trip_stops')
          .select()
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .order('visit_date', ascending: true)
          .order('stop_order', ascending: true);

      final List<dynamic> list = response as List<dynamic>;
      final List<TripStop> stops = [];
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          try {
            stops.add(TripStop.fromJson(item));
          } catch (e, stack) {
            debugPrint('[TripStopService] Failed to parse trip stop: $e\n$stack');
          }
        }
      }
      return stops;
    } catch (e, stack) {
      debugPrint('[TripStopService] Error getStopsForTrip: $e\n$stack');
      return [];
    }
  }

  Future<TripStop> createStop(TripStop stop) async {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('[TripStopService] ❌ createStop: currentUserId is null');
      throw StateError('Cannot create trip stop without authenticated user.');
    }

    final payload = stop.toSupabase();
    payload['user_id'] = userId;

    debugPrint('[TripStopService] ════════════════════════════════════════');
    debugPrint('[TripStopService] createStop AUTH USER ID: $userId');
    debugPrint('[TripStopService] createStop TRIP ID: ${stop.tripId}');
    debugPrint('[TripStopService] createStop payload keys: ${payload.keys.toList()}');
    debugPrint('[TripStopService] createStop payload entries:');
    payload.forEach((key, value) {
      debugPrint('   $key: $value (${value?.runtimeType})');
    });
    debugPrint('[TripStopService] ════════════════════════════════════════');

    try {
      final response = await _client
          .from('trip_stops')
          .insert(payload)
          .select()
          .single();

      debugPrint('[TripStopService] createStop SUCCESS -> generated ID: ${response['id']}');
      return TripStop.fromJson(response);
    } catch (e, stack) {
      debugPrint('[TripStopService] ❌ createStop FAILED: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('[TripStopService] PostgrestException CODE: ${e.code}');
        debugPrint('[TripStopService] PostgrestException MESSAGE: ${e.message}');
        debugPrint('[TripStopService] PostgrestException DETAILS: ${e.details}');
        debugPrint('[TripStopService] PostgrestException HINT: ${e.hint}');
      } else {
        debugPrint('[TripStopService] General Exception: $e');
      }
      debugPrint('[TripStopService] Stack trace: $stack');
      rethrow;
    }
  }

  Future<TripStop> updateStop(TripStop stop) async {
    final userId = currentUserId;
    if (userId == null || stop.id == null) {
      throw StateError('Cannot update trip stop without authenticated user and stop ID.');
    }

    final payload = stop.toSupabase();
    payload['user_id'] = userId;
    payload['updated_at'] = DateTime.now().toUtc().toIso8601String();

    final response = await _client
        .from('trip_stops')
        .update(payload)
        .eq('id', stop.id!)
        .eq('user_id', userId)
        .select()
        .single();

    return TripStop.fromJson(response);
  }

  Future<void> deleteStop(String userId, int stopId) async {
    await _client
        .from('trip_stops')
        .delete()
        .eq('id', stopId)
        .eq('user_id', userId);
  }

  Future<void> reorderStops(
    String userId,
    int tripId,
    DateTime visitDate,
    List<TripStop> orderedStops,
  ) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(visitDate);
    final nowIso = DateTime.now().toUtc().toIso8601String();

    for (int i = 0; i < orderedStops.length; i++) {
      final stop = orderedStops[i];
      if (stop.id != null) {
        await _client
            .from('trip_stops')
            .update({
              'stop_order': 10000 + i + 1,
              'updated_at': nowIso,
            })
            .eq('id', stop.id!)
            .eq('trip_id', tripId)
            .eq('user_id', userId)
            .eq('visit_date', dateStr);
      }
    }

    for (int i = 0; i < orderedStops.length; i++) {
      final stop = orderedStops[i];
      final newOrder = i + 1;
      if (stop.id != null) {
        await _client
            .from('trip_stops')
            .update({
              'stop_order': newOrder,
              'updated_at': nowIso,
            })
            .eq('id', stop.id!)
            .eq('trip_id', tripId)
            .eq('user_id', userId)
            .eq('visit_date', dateStr);
      }
    }
  }

  Future<void> deleteStopsForTrip(String userId, int tripId) async {
    await _client
        .from('trip_stops')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }
}
