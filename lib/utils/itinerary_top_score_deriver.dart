import '../models/itinerary_analysis.dart';
import '../models/planned_trip.dart';
import '../models/travel_score.dart';
import '../theme/app_colors.dart';
import 'travel_score_calculator.dart';

class ItineraryTopScoreDeriver {
  static TravelScore derive({
    required PlannedTrip trip,
    required ItineraryStopAnalysis firstStopAnalysis,
    required int totalStops,
    TravelScore? fallbackScore,
  }) {
    final stop = firstStopAnalysis.stop;
    final segment = firstStopAnalysis.routeFromPrevious;

    final TravelScore baseScore;
    if (fallbackScore != null) {
      baseScore = fallbackScore;
    } else if (firstStopAnalysis.weather != null) {
      baseScore = TravelScoreCalculator.calculateScore(
        weather: firstStopAnalysis.weather,
        route: segment?.route,
        preferredPeriod: null,
        travelDate: trip.travelDate,
      );
    } else if (firstStopAnalysis.weatherSuitability != null) {
      final weatherScore = firstStopAnalysis.weatherSuitability!;
      final journeyScore = segment?.route != null
          ? TravelScoreCalculator.calculateJourneyPracticality(segment!.route!)
          : null;
      final overall = journeyScore != null
          ? ((weatherScore * 0.60) + (journeyScore * 0.40)).round().clamp(0, 100)
          : weatherScore;
      final suitability = overall >= 80
          ? TravelSuitability.ideal
          : (overall >= 60 ? TravelSuitability.moderate : TravelSuitability.challenging);
      final levelName = overall >= 90
          ? 'Excellent'
          : (overall >= 80
              ? 'Very Good'
              : (overall >= 70
                  ? 'Good'
                  : (overall >= 60 ? 'Moderate' : 'Less Ideal')));
      final color = overall >= 80
          ? AppColors.safeGreen
          : (overall >= 60
              ? (overall >= 70 ? AppColors.accentCyan : AppColors.cautionAmber)
              : AppColors.dangerRed);

      const recPeriod = 'Morning';

      baseScore = TravelScore(
        score: overall,
        weatherSubscore: weatherScore,
        journeySubscore: journeyScore,
        suitability: suitability,
        levelName: levelName,
        bestTravelPeriod: recPeriod,
        recommendedPeriod: recPeriod,
        bestWeatherWindow: 'Around 8:00 AM',
        recommendedDeparture: segment?.durationMinutes != null ? 'Around 6:00 AM' : null,
        recommendation: '',
        highlights: const [],
        color: color,
        breakdown: TravelScoreBreakdown(
          weatherScore: weatherScore,
          journeyScore: journeyScore,
        ),
      );
    } else {
      baseScore = TravelScore.initial();
    }

    final bullets = <String>[];
    if (totalStops == 1) {
      if (segment != null && segment.isRouteAvailable) {
        bullets.add('${segment.distanceFormatted} (${segment.durationFormatted} drive) from ${segment.fromName} to ${stop.locationName}.');
      }
      if (firstStopAnalysis.weatherDescriptionFormatted != null) {
        final rain = firstStopAnalysis.rainProbabilityFormatted;
        bullets.add('Expected weather at arrival: ${firstStopAnalysis.weatherDescriptionFormatted}${rain != null ? ' · $rain' : ''}.');
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
      score: baseScore.score,
      weatherSubscore: baseScore.weatherSubscore,
      journeySubscore: baseScore.journeySubscore,
      suitability: baseScore.suitability,
      levelName: baseScore.levelName,
      bestTravelPeriod: baseScore.bestTravelPeriod,
      recommendedPeriod: baseScore.recommendedPeriod ?? baseScore.bestTravelPeriod,
      bestWeatherWindow: baseScore.bestWeatherWindow ?? fallbackScore?.bestWeatherWindow,
      recommendedDeparture: baseScore.recommendedDeparture ?? fallbackScore?.recommendedDeparture,
      departureReason: baseScore.departureReason ?? fallbackScore?.departureReason,
      recommendation: summary,
      highlights: bullets.isNotEmpty ? bullets : baseScore.highlights,
      explanationBullets: bullets.isNotEmpty ? bullets : baseScore.explanationBullets,
      breakdown: baseScore.breakdown,
      color: baseScore.color,
      isInitial: baseScore.isInitial,
    );
  }
}
