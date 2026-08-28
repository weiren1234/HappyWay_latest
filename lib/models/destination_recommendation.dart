import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'travel_destination.dart';
import 'travel_route.dart';
import 'weather_info.dart';

/// DestinationRecommendation represents a smart, rule-based recommendation
/// for a curated destination based on user activity preference, official MET Malaysia forecast,
/// and reachability / journey practicality from user origin.
class DestinationRecommendation {
  final TravelDestination destination;
  final String selectedPreference;
  final int recommendationScore; // Destination Match Score (0 - 100)
  final int activityMatchScore; // Activity Match score
  final int weatherSuitabilityScore; // Weather Suitability score
  final int? journeyPracticalityScore; // Journey Practicality score (road-accessible only)
  final TravelRoute? route;
  final String matchLevel; // "Great Match", "Good Match", "Moderate Match", "Less Recommended"
  final Color matchColor;
  final String bestTravelPeriod; // e.g. "Morning", "Afternoon", "All Day"
  final String reason; // Rule-based explanation derived from official MET forecast fields + route
  final bool isRoadAccessible; // True if direct road driving is feasible from user's location
  final String reachabilityNote; // e.g. "Direct road route available" or "Direct driving route unavailable"
  final WeatherInfo? weather;

  const DestinationRecommendation({
    required this.destination,
    required this.selectedPreference,
    required this.recommendationScore,
    required this.activityMatchScore,
    required this.weatherSuitabilityScore,
    this.journeyPracticalityScore,
    this.route,
    required this.matchLevel,
    required this.matchColor,
    required this.bestTravelPeriod,
    required this.reason,
    required this.isRoadAccessible,
    required this.reachabilityNote,
    this.weather,
  });

  /// Factory helper to build recommendation with score calculation:
  /// - For road-accessible with route/journey score:
  ///   30% Activity Match + 45% Weather Suitability + 25% Journey Practicality
  /// - For getaways or when journey score is unavailable:
  ///   40% Activity Match + 60% Weather Suitability
  factory DestinationRecommendation.build({
    required TravelDestination destination,
    required String selectedPreference,
    required int activityMatchScore,
    required int weatherSuitabilityScore,
    int? journeyPracticalityScore,
    TravelRoute? route,
    required String bestTravelPeriod,
    required String reason,
    required bool isRoadAccessible,
    required String reachabilityNote,
    WeatherInfo? weather,
  }) {
    final int overallScore = (isRoadAccessible && journeyPracticalityScore != null)
        ? ((activityMatchScore * 0.30) +
           (weatherSuitabilityScore * 0.45) +
           (journeyPracticalityScore * 0.25)).round().clamp(0, 100)
        : ((activityMatchScore * 0.40) +
           (weatherSuitabilityScore * 0.60)).round().clamp(0, 100);

    String level;
    Color color;

    if (overallScore >= 85) {
      level = 'Great Match';
      color = AppColors.safeGreen;
    } else if (overallScore >= 70) {
      level = 'Good Match';
      color = AppColors.accentCyan;
    } else if (overallScore >= 50) {
      level = 'Moderate Match';
      color = AppColors.cautionAmber;
    } else {
      level = 'Less Recommended';
      color = AppColors.dangerRed;
    }

    return DestinationRecommendation(
      destination: destination,
      selectedPreference: selectedPreference,
      recommendationScore: overallScore,
      activityMatchScore: activityMatchScore,
      weatherSuitabilityScore: weatherSuitabilityScore,
      journeyPracticalityScore: journeyPracticalityScore,
      route: route,
      matchLevel: level,
      matchColor: color,
      bestTravelPeriod: bestTravelPeriod,
      reason: reason,
      isRoadAccessible: isRoadAccessible,
      reachabilityNote: reachabilityNote,
      weather: weather,
    );
  }
}

