import '../models/itinerary_analysis.dart';
import '../models/planned_trip.dart';
import '../models/travel_score.dart';
import '../theme/app_colors.dart';

class ItineraryTopScoreDeriver {
  static TravelScore derive({
    required PlannedTrip trip,
    required ItineraryStopAnalysis firstStopAnalysis,
    required int totalStops,
    TravelScore? fallbackScore,
  }) {
    final stop = firstStopAnalysis.stop;
    final segment = firstStopAnalysis.routeFromPrevious;

    final rawScore = firstStopAnalysis.weatherSuitability ?? fallbackScore?.score ?? 80;
    final score = rawScore.clamp(10, 100);

    final suitability = score >= 80
        ? TravelSuitability.ideal
        : (score >= 60 ? TravelSuitability.moderate : TravelSuitability.challenging);

    final levelName = score >= 90
        ? 'Excellent'
        : (score >= 80
            ? 'Very Good'
            : (score >= 70
                ? 'Good'
                : (score >= 60 ? 'Moderate' : 'Less Ideal')));

    final color = score >= 80
        ? AppColors.safeGreen
        : (score >= 60
            ? (score >= 70 ? AppColors.accentCyan : AppColors.cautionAmber)
            : AppColors.dangerRed);

    final arr = stop.isExactTime
        ? (firstStopAnalysis.plannedArrivalDateTime ?? firstStopAnalysis.recommendedArrivalDateTime)
        : (firstStopAnalysis.recommendedArrivalDateTime ?? firstStopAnalysis.plannedArrivalDateTime);

    String recPeriod;
    if (arr != null) {
      if (arr.hour < 12) {
        recPeriod = 'Morning';
      } else if (arr.hour < 18) {
        recPeriod = 'Afternoon';
      } else {
        recPeriod = 'Night';
      }
    } else {
      final pref = stop.preferredPeriod?.trim();
      if (pref != null && pref.isNotEmpty && pref.toLowerCase() != 'auto') {
        recPeriod = pref[0].toUpperCase() + pref.substring(1).toLowerCase();
      } else {
        recPeriod = fallbackScore?.recommendedPeriod ?? 'Morning';
      }
    }

    String? bestWindow;
    if (firstStopAnalysis.betterWeatherWindow != null &&
        firstStopAnalysis.betterWeatherWindow!.trim().isNotEmpty) {
      bestWindow = firstStopAnalysis.betterWeatherWindow!.trim();
    } else {
      final arrStr = stop.isExactTime
          ? firstStopAnalysis.plannedArrivalFormatted
          : firstStopAnalysis.recommendedArrivalFormatted;
      if (arrStr != null) {
        bestWindow = arrStr.startsWith('Around') ? arrStr : 'Around $arrStr';
      } else {
        bestWindow = fallbackScore?.bestWeatherWindow;
      }
    }

    final depFormatted = firstStopAnalysis.suggestedDepartureFormatted ?? fallbackScore?.recommendedDeparture;

    final bullets = <String>[];
    if (totalStops == 1) {
      if (segment != null && segment.isRouteAvailable) {
        bullets.add('${segment.distanceFormatted} (${segment.durationFormatted} drive) from ${segment.fromName} to ${stop.locationName}.');
      }
      if (firstStopAnalysis.weatherDescriptionFormatted != null) {
        final rain = firstStopAnalysis.rainProbabilityFormatted;
        bullets.add('Expected weather at arrival: ${firstStopAnalysis.weatherDescriptionFormatted}${rain != null ? ' · $rain' : ''}.');
      }
      if (stop.isExactTime) {
        if (firstStopAnalysis.plannedArrivalFormatted != null) {
          bullets.add('Planned arrival scheduled for ${firstStopAnalysis.plannedArrivalFormatted}.');
        }
      } else {
        if (firstStopAnalysis.recommendedArrivalFormatted != null) {
          bullets.add('Optimal weather arrival recommended around ${firstStopAnalysis.recommendedArrivalFormatted}.');
        }
      }
    } else {
      if (segment != null && segment.isRouteAvailable) {
        bullets.add('Leg 1: ${segment.distanceFormatted} (${segment.durationFormatted} drive) to ${stop.locationName}.');
      }
      bullets.add('$totalStops stops scheduled across ${trip.totalDays} ${trip.totalDays == 1 ? 'day' : 'days'}.');
      if (firstStopAnalysis.weatherDescriptionFormatted != null) {
        bullets.add('Leg 1 arrival weather: ${firstStopAnalysis.weatherDescriptionFormatted}.');
      }
    }

    final summary = totalStops == 1
        ? 'Favorable conditions planned for your trip to ${stop.locationName}.'
        : 'Trip start conditions and recommendations for Leg 1 to ${stop.locationName}.';

    return TravelScore(
      score: score,
      suitability: suitability,
      levelName: levelName,
      bestTravelPeriod: recPeriod,
      recommendedPeriod: recPeriod,
      bestWeatherWindow: bestWindow,
      recommendedDeparture: depFormatted,
      departureReason: firstStopAnalysis.suggestedDepartureDateTime != null
          ? 'Suggested departure for ${stop.locationName}'
          : fallbackScore?.departureReason,
      recommendation: summary,
      highlights: bullets,
      explanationBullets: bullets,
      color: color,
    );
  }
}
