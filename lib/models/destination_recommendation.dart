import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'travel_destination.dart';
import 'travel_route.dart';
import 'weather_info.dart';

class DestinationRecommendation {
  final TravelDestination destination;
  final String selectedPreference;
  final int recommendationScore;
  final int activityMatchScore;
  final int weatherSuitabilityScore;
  final int? journeyPracticalityScore;
  final TravelRoute? route;
  final String matchLevel;
  final Color matchColor;
  final String bestTravelPeriod;
  final String reason;
  final bool isRoadAccessible;
  final String reachabilityNote;
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

  DestinationRecommendation copyWith({
    TravelDestination? destination,
    String? selectedPreference,
    int? recommendationScore,
    int? activityMatchScore,
    int? weatherSuitabilityScore,
    int? journeyPracticalityScore,
    TravelRoute? route,
    String? matchLevel,
    Color? matchColor,
    String? bestTravelPeriod,
    String? reason,
    bool? isRoadAccessible,
    String? reachabilityNote,
    WeatherInfo? weather,
  }) {
    return DestinationRecommendation(
      destination: destination ?? this.destination,
      selectedPreference: selectedPreference ?? this.selectedPreference,
      recommendationScore: recommendationScore ?? this.recommendationScore,
      activityMatchScore: activityMatchScore ?? this.activityMatchScore,
      weatherSuitabilityScore: weatherSuitabilityScore ?? this.weatherSuitabilityScore,
      journeyPracticalityScore: journeyPracticalityScore ?? this.journeyPracticalityScore,
      route: route ?? this.route,
      matchLevel: matchLevel ?? this.matchLevel,
      matchColor: matchColor ?? this.matchColor,
      bestTravelPeriod: bestTravelPeriod ?? this.bestTravelPeriod,
      reason: reason ?? this.reason,
      isRoadAccessible: isRoadAccessible ?? this.isRoadAccessible,
      reachabilityNote: reachabilityNote ?? this.reachabilityNote,
      weather: weather ?? this.weather,
    );
  }
}

