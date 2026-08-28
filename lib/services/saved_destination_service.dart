import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_location.dart';

/// SavedDestinationService manages cloud persistence of saved destinations in Supabase table `saved_destinations`.
/// Adheres strictly to Row Level Security (RLS) policies for authenticated users.
class SavedDestinationService {
  static final SavedDestinationService _instance = SavedDestinationService._internal();
  factory SavedDestinationService() => _instance;
  SavedDestinationService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  /// Loads all saved destinations for the current authenticated user.
  Future<List<SavedLocation>> getSavedDestinations(String userId) async {
    final response = await _client
        .from('saved_destinations')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final list = response as List<dynamic>;
    return list.map((item) => SavedLocation.fromSupabase(item as Map<String, dynamic>)).toList();
  }

  /// Saves a destination for the authenticated user.
  Future<void> saveDestination(String userId, SavedLocation location) async {
    final payload = location.toSupabase(userId: userId);
    await _client.from('saved_destinations').upsert(
      payload,
      onConflict: 'user_id,location_id',
    );
  }

  /// Removes a saved destination for the authenticated user.
  Future<void> unsaveDestination(String userId, String locationId) async {
    final bareId = locationId.startsWith('met:') ? locationId.substring(4) : locationId;
    final prefixedId = locationId.startsWith('met:') ? locationId : 'met:$locationId';
    await _client
        .from('saved_destinations')
        .delete()
        .eq('user_id', userId)
        .or('location_id.eq.$locationId,location_id.eq.$bareId,location_id.eq.$prefixedId');
  }

  /// Checks if a location is saved by the user.
  Future<bool> isSaved(String userId, String locationId) async {
    try {
      final response = await _client
          .from('saved_destinations')
          .select('location_id')
          .eq('user_id', userId)
          .eq('location_id', locationId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }
}
