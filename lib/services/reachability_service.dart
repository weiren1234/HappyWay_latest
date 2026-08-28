/// Region and landmass classification for Malaysia.
enum MalaysianRegion {
  peninsular,
  sabah,
  sarawak,
  labuan,
  unknown,
}

/// ReachabilityService provides deterministic reachability and transport classification
/// for Malaysian travel destinations based on official geographic boundaries and bridge connectivity.
///
/// Rules:
/// 1. Peninsular Malaysia includes: Kuala Lumpur, Selangor, Putrajaya, Negeri Sembilan,
///    Melaka, Johor, Pahang, Perak, Penang, Kedah, Perlis, Terengganu, Kelantan.
/// 2. East Malaysia includes: Sabah, Sarawak, Labuan.
/// 3. Penang Island is connected to Peninsular mainland by two road bridges (Penang Bridge and Second Bridge),
///    so it IS direct road accessible from Peninsular Malaysia.
/// 4. Offshore islands (Langkawi, Pulau Tioman, Pulau Redang, Pulau Perhentian, Pulau Pangkor, Pulau Kapas, etc.)
///    require ferry or flight, so they are NOT direct road accessible.
/// 5. Travel between Peninsular and East Malaysia crosses the South China Sea and is NOT direct road accessible.
class ReachabilityService {
  ReachabilityService._();

  /// Peninsular Malaysian state names / aliases (normalized lowercase).
  static const Set<String> _peninsularStates = {
    'kuala lumpur',
    'kl',
    'wp kuala lumpur',
    'w.p. kuala lumpur',
    'wilayah persekutuan kuala lumpur',
    'federal territory of kuala lumpur',
    'selangor',
    'putrajaya',
    'wp putrajaya',
    'w.p. putrajaya',
    'wilayah persekutuan putrajaya',
    'federal territory of putrajaya',
    'negeri sembilan',
    'n. sembilan',
    'melaka',
    'malacca',
    'johor',
    'pahang',
    'perak',
    'penang',
    'pulau pinang',
    'kedah',
    'perlis',
    'terengganu',
    'kelantan',
  };

  /// Known offshore islands requiring ferry / flight transport.
  static const Set<String> _offshoreIslandKeywords = {
    'langkawi',
    'pulau tioman',
    'tioman',
    'pulau redang',
    'redang',
    'pulau perhentian',
    'perhentian',
    'pulau pangkor',
    'pangkor',
    'pulau kapas',
    'kapas',
    'pulau rawa',
    'rawa',
    'pulau mabul',
    'mabul',
    'pulau sipadan',
    'sipadan',
    'pulau tenggol',
    'tenggol',
    'pulau besar',
    'pulau layang-layang',
  };

  /// Resolves the [MalaysianRegion] from a state name or coordinates.
  static MalaysianRegion resolveRegion({String? state, double? latitude, double? longitude}) {
    if (state != null && state.isNotEmpty) {
      final clean = state.trim().toLowerCase();
      if (_peninsularStates.any((s) => clean.contains(s))) {
        return MalaysianRegion.peninsular;
      }
      if (clean.contains('sabah')) return MalaysianRegion.sabah;
      if (clean.contains('sarawak')) return MalaysianRegion.sarawak;
      if (clean.contains('labuan')) return MalaysianRegion.labuan;
    }

    // Fallback to coordinate bounding boxes if state string is ambiguous
    if (latitude != null && longitude != null) {
      // Peninsular Malaysia: approx Lat 1.0 - 7.0, Long 99.5 - 104.5
      if (latitude >= 1.0 && latitude <= 7.0 && longitude >= 99.5 && longitude <= 104.5) {
        return MalaysianRegion.peninsular;
      }
      // Sarawak: approx Lat 0.8 - 5.0, Long 109.5 - 115.8
      if (latitude >= 0.8 && latitude <= 5.0 && longitude >= 109.5 && longitude <= 115.8) {
        return MalaysianRegion.sarawak;
      }
      // Sabah & Labuan: approx Lat 4.0 - 7.5, Long 115.0 - 119.5
      if (latitude >= 4.0 && latitude <= 7.5 && longitude >= 115.0 && longitude <= 119.5) {
        return MalaysianRegion.sabah;
      }
    }

    return MalaysianRegion.unknown;
  }

  /// Determines whether a destination is an offshore island requiring water/air transport.
  /// (Note: Penang is road-connected via bridges and returns false).
  static bool isOffshoreIsland({required String destinationName, String? category}) {
    final lowerName = destinationName.trim().toLowerCase();
    
    // Explicit exception: Penang is connected by two bridges
    if (lowerName.contains('penang') || lowerName.contains('batu ferringhi') || lowerName.contains('george town')) {
      return false;
    }

    for (final island in _offshoreIslandKeywords) {
      if (lowerName.contains(island)) {
        return true;
      }
    }

    return false;
  }

  /// Determines whether a direct driving road route is feasible between [origin] and [destination].
  static bool isDirectRoadFeasible({
    required String originState,
    double? originLat,
    double? originLng,
    required String destinationName,
    required String destinationState,
    double? destLat,
    double? destLng,
    String? destinationCategory,
  }) {
    // 1. If destination is an offshore island (e.g. Langkawi, Tioman, Redang), no direct road route exists
    if (isOffshoreIsland(destinationName: destinationName, category: destinationCategory)) {
      return false;
    }

    // 2. Check region compatibility
    final originRegion = resolveRegion(state: originState, latitude: originLat, longitude: originLng);
    final destRegion = resolveRegion(state: destinationState, latitude: destLat, longitude: destLng);

    // If both regions are known and different (e.g. Peninsular -> Sabah), direct road is impossible
    if (originRegion != MalaysianRegion.unknown && destRegion != MalaysianRegion.unknown) {
      if (originRegion != destRegion) {
        // Special case: Sabah & Sarawak share Borneo landmass, but Peninsular <-> East Malaysia does not
        final isOriginPeninsular = originRegion == MalaysianRegion.peninsular;
        final isDestPeninsular = destRegion == MalaysianRegion.peninsular;
        if (isOriginPeninsular != isDestPeninsular) {
          return false;
        }
      }
    }

    return true;
  }

  /// Provides a user-friendly reachability label.
  static String getReachabilityLabel({
    required bool isRoadAccessible,
    required String destinationName,
  }) {
    if (!isRoadAccessible) {
      return 'Direct driving route unavailable';
    }
    return 'Direct road route available';
  }
}
