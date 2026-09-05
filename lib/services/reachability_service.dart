
enum MalaysianRegion {
  peninsular,
  sabah,
  sarawak,
  labuan,
  unknown,
}

class ReachabilityService {
  ReachabilityService._();

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

    if (latitude != null && longitude != null) {

      if (latitude >= 1.0 && latitude <= 7.0 && longitude >= 99.5 && longitude <= 104.5) {
        return MalaysianRegion.peninsular;
      }

      if (latitude >= 0.8 && latitude <= 5.0 && longitude >= 109.5 && longitude <= 115.8) {
        return MalaysianRegion.sarawak;
      }

      if (latitude >= 4.0 && latitude <= 7.5 && longitude >= 115.0 && longitude <= 119.5) {
        return MalaysianRegion.sabah;
      }
    }

    return MalaysianRegion.unknown;
  }

  static bool isOffshoreIsland({required String destinationName, String? category}) {
    final lowerName = destinationName.trim().toLowerCase();
    

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

    if (isOffshoreIsland(destinationName: destinationName, category: destinationCategory)) {
      return false;
    }

    final originRegion = resolveRegion(state: originState, latitude: originLat, longitude: originLng);
    final destRegion = resolveRegion(state: destinationState, latitude: destLat, longitude: destLng);

    if (originRegion != MalaysianRegion.unknown && destRegion != MalaysianRegion.unknown) {
      if (originRegion != destRegion) {

        final isOriginPeninsular = originRegion == MalaysianRegion.peninsular;
        final isDestPeninsular = destRegion == MalaysianRegion.peninsular;
        if (isOriginPeninsular != isDestPeninsular) {
          return false;
        }
      }
    }

    return true;
  }

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
