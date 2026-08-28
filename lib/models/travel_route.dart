/// TravelRoute stores calculated road distance and estimated driving duration
/// retrieved from the OSRM routing engine.
class TravelRoute {
  final String originName;
  final double originLatitude;
  final double originLongitude;
  final String destinationName;
  final double destinationLatitude;
  final double destinationLongitude;
  final double distanceMeters;
  final double distanceKm;
  final double durationSeconds;
  final DateTime fetchedAt;

  const TravelRoute({
    required this.originName,
    required this.originLatitude,
    required this.originLongitude,
    required this.destinationName,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.distanceMeters,
    required this.distanceKm,
    required this.durationSeconds,
    required this.fetchedAt,
  });

  /// Formatted road distance (e.g., "206 km" or "15.4 km").
  String get distanceFormatted {
    if (distanceKm >= 100) {
      return '${distanceKm.round()} km';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Formatted estimated driving duration (e.g., "3 hr 18 min", "45 min").
  /// NOTE: This is normal estimated driving time, not real-time live traffic data.
  String get durationFormatted {
    final totalMinutes = (durationSeconds / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;

    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    } else {
      return '$minutes min';
    }
  }

  int get durationMinutes => (durationSeconds / 60).round();

  factory TravelRoute.fromOsrmJson({
    required Map<String, dynamic> json,
    required String originName,
    required double originLat,
    required double originLng,
    required String destName,
    required double destLat,
    required double destLng,
  }) {
    final routes = json['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      throw Exception('No route found in OSRM response');
    }

    final firstRoute = routes[0] as Map<String, dynamic>;
    final distanceM = (firstRoute['distance'] as num).toDouble();
    final durationSec = (firstRoute['duration'] as num).toDouble();

    return TravelRoute(
      originName: originName,
      originLatitude: originLat,
      originLongitude: originLng,
      destinationName: destName,
      destinationLatitude: destLat,
      destinationLongitude: destLng,
      distanceMeters: distanceM,
      distanceKm: distanceM / 1000.0,
      durationSeconds: durationSec,
      fetchedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'originName': originName,
        'originLatitude': originLatitude,
        'originLongitude': originLongitude,
        'destinationName': destinationName,
        'destinationLatitude': destinationLatitude,
        'destinationLongitude': destinationLongitude,
        'distanceMeters': distanceMeters,
        'distanceKm': distanceKm,
        'durationSeconds': durationSeconds,
        'fetchedAt': fetchedAt.millisecondsSinceEpoch,
      };

  factory TravelRoute.fromJson(Map<String, dynamic> json) => TravelRoute(
        originName: json['originName'] as String? ?? '',
        originLatitude: (json['originLatitude'] as num).toDouble(),
        originLongitude: (json['originLongitude'] as num).toDouble(),
        destinationName: json['destinationName'] as String? ?? '',
        destinationLatitude: (json['destinationLatitude'] as num).toDouble(),
        destinationLongitude: (json['destinationLongitude'] as num).toDouble(),
        distanceMeters: (json['distanceMeters'] as num).toDouble(),
        distanceKm: (json['distanceKm'] as num).toDouble(),
        durationSeconds: (json['durationSeconds'] as num).toDouble(),
        fetchedAt: DateTime.fromMillisecondsSinceEpoch(json['fetchedAt'] as int),
      );
}
