import 'dart:math' as math;
import '../models/travel_destination.dart';
import '../models/destination_recommendation.dart';
import '../models/travel_route.dart';
import '../models/weather_info.dart';
import '../models/user_location.dart';
import '../services/weather_service.dart';
import '../services/route_service.dart';
import '../services/reachability_service.dart';
import '../utils/travel_score_calculator.dart';

class RecommendationService {
  final WeatherService _weatherService;
  final RouteService _routeService;

  RecommendationService({
    WeatherService? weatherService,
    RouteService? routeService,
  })  : _weatherService = weatherService ?? WeatherService(),
        _routeService = routeService ?? RouteService();

  Future<List<DestinationRecommendation>> getRecommendations({
    required String preference,
    required List<TravelDestination> allDestinations,
    UserLocation? userOrigin,
    double targetDistanceKm = 50.0,
  }) async {
    final prefLower = preference.trim().toLowerCase();

    final originState = userOrigin?.state ?? 'Kuala Lumpur';
    final originLat = (userOrigin?.latitude != null && userOrigin!.latitude != 0.0)
        ? userOrigin.latitude
        : 3.1950;
    final originLng = (userOrigin?.longitude != null && userOrigin!.longitude != 0.0)
        ? userOrigin.longitude
        : 101.7100;

    final roadCandidates = <_CandidateItem>[];
    final getawayCandidates = <_CandidateItem>[];

    for (final dest in allDestinations) {
      final activityMatch = _calculateActivityMatch(dest, prefLower);
      if (activityMatch > 0) {
        final isRoadAccessible = ReachabilityService.isDirectRoadFeasible(
          originState: originState,
          originLat: originLat,
          originLng: originLng,
          destinationName: dest.name,
          destinationState: dest.state,
          destLat: dest.latitude,
          destLng: dest.longitude,
          destinationCategory: dest.category,
        );

        double distanceKm = double.infinity;
        if (dest.latitude != null && dest.longitude != null) {
          distanceKm = _haversineKm(
            originLat, originLng,
            dest.latitude!, dest.longitude!,
          );
        }

        final item = _CandidateItem(
          destination: dest,
          activityScore: activityMatch,
          isRoadAccessible: isRoadAccessible,
          distanceKm: distanceKm,
        );

        if (isRoadAccessible) {
          roadCandidates.add(item);
        } else {
          getawayCandidates.add(item);
        }
      }
    }

    if (targetDistanceKm <= 50.0) {
      roadCandidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    } else {

      final targetStraightKm = targetDistanceKm / 1.3;
      roadCandidates.sort((a, b) =>
          (a.distanceKm - targetStraightKm).abs().compareTo((b.distanceKm - targetStraightKm).abs()));
    }
    getawayCandidates.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));

    final roadBatch = roadCandidates.take(35).toList();
    final getawayBatch = getawayCandidates.take(6).toList();

    final processedRoadRecs = <DestinationRecommendation>[];

    if (roadBatch.isNotEmpty) {

      final scoredRoadCandidates = <_ScoredPreCandidate>[];
      for (final item in roadBatch) {
        final dest = item.destination;
        WeatherInfo? weather = dest.weather;

        if (weather == null && dest.metLocationId.isNotEmpty) {
          weather = await _weatherService.fetchWeatherForLocationId(dest.metLocationId);
        }

        final weatherScore = TravelScoreCalculator.calculateWeatherSuitability(weather);

        scoredRoadCandidates.add(_ScoredPreCandidate(
          item: item,
          weather: weather,
          weatherScore: weatherScore,
          preRankScore: 0,
        ));
      }

      for (final scored in scoredRoadCandidates) {
        final dest = scored.item.destination;
        final weather = scored.weather;
        final bestPeriod = _calculateBestPeriod(weather);

        TravelRoute? route;
        int? journeyScore;

        if (dest.latitude != null &&
            dest.longitude != null &&
            dest.latitude != 0.0 &&
            dest.longitude != 0.0) {
          try {
            final routeRes = await _routeService.calculateRouteDetails(
              originName: originState,
              originLat: originLat,
              originLng: originLng,
              destName: dest.name,
              destLat: dest.latitude!,
              destLng: dest.longitude!,
            );
            if (routeRes.isSuccess && routeRes.route != null) {
              route = routeRes.route;
              journeyScore = TravelScoreCalculator.calculateJourneyPracticality(route);
            }
          } catch (_) {}
        }

        final reachabilityNote = ReachabilityService.getReachabilityLabel(
          isRoadAccessible: true,
          destinationName: dest.name,
        );

        final reason = _generateRecommendationReason(
          destName: dest.name,
          preference: preference,
          weather: weather,
          bestPeriod: bestPeriod,
          isRoadAccessible: true,
          route: route,
        );

        final rec = DestinationRecommendation.build(
          destination: weather != null ? dest.copyWith(weather: weather) : dest,
          selectedPreference: preference,
          activityMatchScore: scored.item.activityScore,
          weatherSuitabilityScore: scored.weatherScore,
          journeyPracticalityScore: journeyScore,
          route: route,
          bestTravelPeriod: bestPeriod,
          reason: reason,
          isRoadAccessible: true,
          reachabilityNote: reachabilityNote,
          weather: weather,
        );

        processedRoadRecs.add(rec);
      }

      processedRoadRecs.sort((a, b) => b.recommendationScore.compareTo(a.recommendationScore));
    }

    final finalRoadRecs = processedRoadRecs;

    final processedGetawayRecs = <DestinationRecommendation>[];

    if (getawayBatch.isNotEmpty) {
      for (final item in getawayBatch) {
        final dest = item.destination;
        WeatherInfo? weather = dest.weather;

        if (weather == null && dest.metLocationId.isNotEmpty) {
          weather = await _weatherService.fetchWeatherForLocationId(dest.metLocationId);
        }

        final weatherScore = TravelScoreCalculator.calculateWeatherSuitability(weather);
        final bestPeriod = _calculateBestPeriod(weather);

        final reachabilityNote = ReachabilityService.getReachabilityLabel(
          isRoadAccessible: false,
          destinationName: dest.name,
        );

        final reason = _generateRecommendationReason(
          destName: dest.name,
          preference: preference,
          weather: weather,
          bestPeriod: bestPeriod,
          isRoadAccessible: false,
        );

        final rec = DestinationRecommendation.build(
          destination: weather != null ? dest.copyWith(weather: weather) : dest,
          selectedPreference: preference,
          activityMatchScore: item.activityScore,
          weatherSuitabilityScore: weatherScore,
          journeyPracticalityScore: null,
          route: null,
          bestTravelPeriod: bestPeriod,
          reason: reason,
          isRoadAccessible: false,
          reachabilityNote: reachabilityNote,
          weather: weather,
        );

        processedGetawayRecs.add(rec);
      }

      processedGetawayRecs.sort((a, b) => b.recommendationScore.compareTo(a.recommendationScore));
    }

    final finalGetawayRecs = processedGetawayRecs;

    return [...finalRoadRecs, ...finalGetawayRecs];
  }

  static double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final sinDLat = math.sin(dLat / 2);
    final sinDLng = math.sin(dLng / 2);
    final a = sinDLat * sinDLat +
        math.cos(lat1 * math.pi / 180.0) *
        math.cos(lat2 * math.pi / 180.0) *
        sinDLng * sinDLng;
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  static int _calculateActivityMatch(TravelDestination dest, String preferenceLower) {
    for (final tag in dest.activityTags) {
      if (tag.toLowerCase() == preferenceLower) {
        return 100;
      }
    }

    for (final tag in dest.activityTags) {
      if (tag.toLowerCase().contains(preferenceLower) || preferenceLower.contains(tag.toLowerCase())) {
        return 80;
      }
    }

    if (dest.category.toLowerCase().contains(preferenceLower) ||
        preferenceLower.contains(dest.category.toLowerCase())) {
      return 75;
    }

    return 0;
  }

  static String _calculateBestPeriod(WeatherInfo? weather) {
    if (weather == null) return 'Not available';

    final morning = weather.morningCondition?.toLowerCase().trim() ?? '';
    final afternoon = weather.afternoonCondition?.toLowerCase().trim() ?? '';
    final night = weather.nightCondition?.toLowerCase().trim() ?? '';

    if (morning.isEmpty && afternoon.isEmpty && night.isEmpty) {
      return 'Not available';
    }

    final isMorningDry = _isDry(morning);
    final isAfternoonDry = _isDry(afternoon);
    final isNightDry = _isDry(night);

    if (isMorningDry && isAfternoonDry && isNightDry) {
      return 'All Day';
    } else if (isMorningDry && isAfternoonDry) {
      return 'Morning & Afternoon';
    } else if (isMorningDry) {
      return 'Morning';
    } else if (isAfternoonDry) {
      return 'Afternoon';
    } else if (isNightDry) {
      return 'Night';
    } else {
      return 'Morning';
    }
  }

  static bool _isDry(String cond) {
    if (cond.isEmpty) return false;
    final lower = cond.toLowerCase().trim();
    if (lower.contains('tiada hujan') ||
        lower.contains('no rain') ||
        lower.contains('cerah') ||
        lower.contains('clear') ||
        lower.contains('fair') ||
        lower.contains('fine')) {
      return true;
    }
    return false;
  }

  static String _generateRecommendationReason({
    required String destName,
    required String preference,
    required WeatherInfo? weather,
    required String bestPeriod,
    required bool isRoadAccessible,
    TravelRoute? route,
  }) {
    if (weather == null) {
      return 'Curated $preference destination in Malaysia. Awaiting official MET Malaysia forecast update.';
    }

    final morning = weather.morningCondition ?? '';
    final afternoon = weather.afternoonCondition ?? '';
    final isMorningDry = _isDry(morning);
    final isAfternoonDry = _isDry(afternoon);
    final pref = preference.toLowerCase();

    final String routeSuffix;
    if (isRoadAccessible && route != null) {
      routeSuffix = ' Approx. ${route.durationFormatted} drive (${route.distanceFormatted}).';
    } else if (!isRoadAccessible) {
      routeSuffix = ' Reached via flight or ferry.';
    } else {
      routeSuffix = '';
    }

    if (pref == 'beach' || pref == 'island') {
      if (isMorningDry && isAfternoonDry) {
        return 'Dry and clear conditions forecast across morning and afternoon make $destName ideal for coastal trips.$routeSuffix';
      } else if (isMorningDry && !isAfternoonDry) {
        return 'Optimal for morning activities ($morning) before afternoon showers or thunderstorms develop.$routeSuffix';
      } else if (!isMorningDry && isAfternoonDry) {
        return 'Conditions improve in the afternoon ($afternoon) as morning showers clear out.$routeSuffix';
      } else {
        return 'Rain or thunderstorms forecast across multiple periods today; outdoor coastal activities may be limited.$routeSuffix';
      }
    }

    if (pref == 'nature' || pref == 'hiking') {
      if (isMorningDry && isAfternoonDry) {
        return 'Clear dry conditions forecast throughout the day, optimal for nature walks and outdoor exploration.$routeSuffix';
      } else if (isMorningDry && !isAfternoonDry) {
        return 'Morning is the optimal window for outdoor nature trails ($morning) before afternoon rain.$routeSuffix';
      } else {
        return 'Rain or thunderstorms forecast; exercise caution on trails and consider covered exhibits.$routeSuffix';
      }
    }

    if (pref == 'highlands') {
      final tempStr = weather.minTemperature != null && weather.maxTemperature != null
          ? ' (${weather.minTemperature!.round()}°C – ${weather.maxTemperature!.round()}°C)'
          : '';
      if (isMorningDry) {
        return 'Cool highland climate$tempStr with pleasant morning conditions, ideal for sightseeing and tea plantations.$routeSuffix';
      } else {
        return 'Cool highland air$tempStr with intermittent showers; ideal for cafes and indoor attractions.$routeSuffix';
      }
    }

    if (isMorningDry && isAfternoonDry) {
      return 'Stable and clear weather forecast throughout the day makes $destName a great choice for $preference.$routeSuffix';
    } else if (isMorningDry) {
      return 'Optimal for morning $preference activities ($morning) before afternoon showers develop.$routeSuffix';
    } else {
      return 'Afternoon provides the clearest window for $preference as morning conditions ease.$routeSuffix';
    }
  }
}

class _CandidateItem {
  final TravelDestination destination;
  final int activityScore;
  final bool isRoadAccessible;
  final double distanceKm;

  _CandidateItem({
    required this.destination,
    required this.activityScore,
    required this.isRoadAccessible,
    this.distanceKm = double.infinity,
  });
}

class _ScoredPreCandidate {
  final _CandidateItem item;
  final WeatherInfo? weather;
  final int weatherScore;
  final double preRankScore;

  _ScoredPreCandidate({
    required this.item,
    required this.weather,
    required this.weatherScore,
    required this.preRankScore,
  });
}

