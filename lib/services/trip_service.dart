import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/planned_trip.dart';

/// TripService manages cloud persistence of user planned trips using Supabase table `planned_trips`.
/// Adheres strictly to Row Level Security (RLS) policies for authenticated users.
///
/// NOTE: Weather, score, and live route duration are NOT stored permanently in Supabase;
/// they are queried dynamically to guarantee official data integrity.
class TripService {
  static final TripService _instance = TripService._internal();
  factory TripService() => _instance;
  TripService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Retrieves all saved planned trips for the given authenticated user from Supabase.
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

  /// Inserts a new planned trip into Supabase and returns the trip with its generated database integer ID.
  Future<PlannedTrip> saveTrip(String userId, PlannedTrip trip) async {
    final payload = trip.toSupabase(userId: userId);
    final response = await _client
        .from('planned_trips')
        .insert(payload)
        .select()
        .single();

    return PlannedTrip.fromJson(response);
  }

  /// Updates an existing planned trip in Supabase.
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

  /// Deletes a planned trip by its integer database ID.
  Future<void> deleteTrip(String userId, int tripId) async {
    await _client
        .from('planned_trips')
        .delete()
        .eq('id', tripId)
        .eq('user_id', userId);
  }

  /// Finds a specific trip by its integer database ID.
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
