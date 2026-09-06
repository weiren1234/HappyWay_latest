import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planned_trip.dart';

class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  Future<List<PlannedTrip>> getTrips(String userId) async {
    debugPrint('[TripService] ========================================');
    debugPrint('[TripService] AUTH USER ID: $userId');
    final response = await _client
        .from('planned_trips')
        .select()
        .eq('user_id', userId)
        .order('travel_date', ascending: true);

    final List<dynamic> list = response as List<dynamic>;
    debugPrint('[TripService] TRIP ROWS RETURNED: ${list.length}');

    final List<PlannedTrip> trips = [];
    for (final item in list) {
      if (item is Map<String, dynamic>) {
        final rowId = item['id'];
        final rowDest = item['destination_name'];
        final rowDate = item['travel_date'];
        debugPrint('[TripService] Raw row -> id: $rowId, destination_name: $rowDest, travel_date: $rowDate');
        debugPrint('[TripService] Existing row columns: ${item.keys.toList()}');
        try {
          final trip = PlannedTrip.fromJson(item);
          trips.add(trip);
        } catch (e, stack) {
          debugPrint('[TripService] Failed to parse planned_trip ID $rowId: $e\nOffending row: $item\n$stack');
        }
      }
    }
    debugPrint('[TripService] PARSED TRIPS: ${trips.length}');
    debugPrint('[TripService] ========================================');
    return trips;
  }

  Future<PlannedTrip> saveTrip(String userId, PlannedTrip trip) async {
    final payload = trip.toSupabase(userId: userId);
    debugPrint('[TripService] ════════════════════════════════════════');
    debugPrint('[TripService] saveTrip payload keys: ${payload.keys.toList()}');
    debugPrint('[TripService] saveTrip payload entries:');
    payload.forEach((key, value) {
      debugPrint('   $key: $value (${value?.runtimeType})');
    });
    debugPrint('[TripService] ════════════════════════════════════════');

    try {
      final response = await _client
          .from('planned_trips')
          .insert(payload)
          .select()
          .single();

      debugPrint('[TripService] saveTrip SUCCESS -> generated ID: ${response['id']}');
      return PlannedTrip.fromJson(response);
    } catch (e, stack) {
      debugPrint('[TripService] ❌ saveTrip FAILED: ${e.runtimeType}');
      if (e is PostgrestException) {
        debugPrint('[TripService] PostgrestException CODE: ${e.code}');
        debugPrint('[TripService] PostgrestException MESSAGE: ${e.message}');
        debugPrint('[TripService] PostgrestException DETAILS: ${e.details}');
        debugPrint('[TripService] PostgrestException HINT: ${e.hint}');
      } else {
        debugPrint('[TripService] General Exception: $e');
      }
      debugPrint('[TripService] Stack trace: $stack');
      rethrow;
    }
  }

  Future<void> updateTrip(String userId, PlannedTrip trip) async {
    if (trip.id == null) return;
    final payload = trip.toSupabase(userId: userId);
    payload['updated_at'] = DateTime.now().toIso8601String();

    await _client
        .from('planned_trips')
        .update(payload)
        .eq('id', trip.id!)
        .eq('user_id', userId);
  }

  Future<void> deleteTrip(String userId, int tripId) async {
    await _client
        .from('planned_trips')
        .delete()
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  Future<PlannedTrip?> getTripById(String userId, int tripId) async {
    try {
      final response = await _client
          .from('planned_trips')
          .select()
          .eq('id', tripId)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;
      return PlannedTrip.fromJson(response);
    } catch (_) {
      return null;
    }
  }
}
