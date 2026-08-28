import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TravelSuitability {
  ideal,      // 80 - 100
  moderate,   // 50 - 79
  challenging // 0 - 49
}

/// Reason codes explaining why a particular Travel Score or recommendation was generated.
enum TravelRecommendationReason {
  allDayDry,
  favourableMorning,
  favourableAfternoon,
  favourableNight,
  afternoonThunderstorms,
  morningShowers,
  nightRain,
  significantWeatherWarning,
  hotTemperature,
  coolHighlands,
  comfortableDrive,
  longDrive,
  drivingRouteUnavailable,
  preferredPeriodMatch,
  preferredPeriodMismatch,
  insufficientWeatherData,
}

/// Breakdown of individual scoring components contributing to the overall Travel Score.
class TravelScoreBreakdown {
  final int weatherScore; // 0 - 100
  final int? journeyScore; // 0 - 100 (null if route is unavailable)
  final int? morningScore; // 0 - 100
  final int? afternoonScore; // 0 - 100
  final int? nightScore; // 0 - 100
  final bool isWeatherComplete;

  const TravelScoreBreakdown({
    required this.weatherScore,
    this.journeyScore,
    this.morningScore,
    this.afternoonScore,
    this.nightScore,
    this.isWeatherComplete = true,
  });

  Map<String, dynamic> toJson() => {
        'weatherScore': weatherScore,
        'journeyScore': journeyScore,
        'morningScore': morningScore,
        'afternoonScore': afternoonScore,
        'nightScore': nightScore,
        'isWeatherComplete': isWeatherComplete,
      };

  factory TravelScoreBreakdown.fromJson(Map<String, dynamic> json) =>
      TravelScoreBreakdown(
        weatherScore: (json['weatherScore'] as num?)?.toInt() ?? 75,
        journeyScore: (json['journeyScore'] as num?)?.toInt(),
        morningScore: (json['morningScore'] as num?)?.toInt(),
        afternoonScore: (json['afternoonScore'] as num?)?.toInt(),
        nightScore: (json['nightScore'] as num?)?.toInt(),
        isWeatherComplete: json['isWeatherComplete'] as bool? ?? true,
      );
}

/// TravelScore represents HappyWay's rule-based travel suitability index.
///
/// NOTE: This is NOT an official MET Malaysia metric. It is HappyWay's own rule-based
/// assessment calculated strictly from official MET forecasts and optional driving route duration.
class TravelScore {
  final int score;                     // Overall Score (0 - 100)
  final int weatherSubscore;           // Weather Suitability (0 - 100)
  final int? journeySubscore;          // Journey Practicality (0 - 100, null if no route)
  final TravelSuitability suitability;
  final String levelName;              // "Excellent", "Very Good", "Good", "Moderate", "Less Ideal"
  final String bestTravelPeriod;       // "Morning", "Afternoon", "Night", "All Day", etc.
  final String? recommendedDeparture;  // e.g. "Around 8:00 AM" (deterministic planning advice)
  final String? departureReason;       // e.g. "Arrive before afternoon thunderstorms."
  final String recommendation;         // Detailed travel advice summary
  final List<String> highlights;       // Bullet points explaining the conditions
  final List<String> explanationBullets; // "Why this score?" bullets
  final List<TravelRecommendationReason> reasons; // Typed reason codes
  final List<String> recommendedActivities; // Curated destination activities (empty for arbitrary geocoded places)
  final String? preferredPeriodComparison; // Matching status with user preference
  final bool isRouteAvailable;         // True if a valid driving route was factored in
  final String? analysisLimitation;    // Note if analysis is weather-only due to missing route
  final TravelScoreBreakdown breakdown;
  final Color color;

  TravelScore({
    required this.score,
    int? weatherSubscore,
    this.journeySubscore,
    required this.suitability,
    String? levelName,
    required this.bestTravelPeriod,
    this.recommendedDeparture,
    this.departureReason,
    required this.recommendation,
    required this.highlights,
    this.explanationBullets = const [],
    this.reasons = const [],
    this.recommendedActivities = const [],
    this.preferredPeriodComparison,
    this.isRouteAvailable = true,
    this.analysisLimitation,
    TravelScoreBreakdown? breakdown,
    Color? color,
  })  : weatherSubscore = weatherSubscore ?? score,
        breakdown = breakdown ??
            TravelScoreBreakdown(
              weatherScore: weatherSubscore ?? score,
              journeyScore: journeySubscore,
            ),
        levelName = levelName ??
            (score >= 90
                ? 'Excellent'
                : score >= 80
                    ? 'Very Good'
                    : score >= 70
                        ? 'Good'
                        : score >= 60
                            ? 'Moderate'
                            : 'Less Ideal'),
        color = color ??
            (score >= 80
                ? AppColors.safeGreen
                : score >= 60
                    ? (score >= 70 ? AppColors.accentCyan : AppColors.cautionAmber)
                    : AppColors.dangerRed);

  factory TravelScore.initial() {
    return TravelScore(
      score: 75,
      suitability: TravelSuitability.moderate,
      levelName: 'Good',
      bestTravelPeriod: 'Recommended period unavailable',
      recommendation: 'Awaiting official forecast from MET Malaysia to calculate travel recommendations.',
      highlights: [],
      explanationBullets: ['Awaiting live official forecast from MET Malaysia.'],
      reasons: [TravelRecommendationReason.insufficientWeatherData],
      isRouteAvailable: false,
      analysisLimitation: 'Awaiting official forecast data.',
    );
  }

  factory TravelScore.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toInt() ?? 75;
    final suitabilityStr = json['suitability'] as String? ?? 'moderate';
    final suitability = TravelSuitability.values.firstWhere(
      (e) => e.name == suitabilityStr,
      orElse: () => TravelSuitability.moderate,
    );

    final rawReasons = (json['reasons'] as List<dynamic>?) ?? [];
    final reasons = rawReasons
        .map((r) => TravelRecommendationReason.values.firstWhere(
              (e) => e.name == r,
              orElse: () => TravelRecommendationReason.allDayDry,
            ))
        .toList();

    return TravelScore(
      score: score,
      weatherSubscore: (json['weatherSubscore'] as num?)?.toInt(),
      journeySubscore: (json['journeySubscore'] as num?)?.toInt(),
      suitability: suitability,
      levelName: json['levelName'] as String?,
      bestTravelPeriod: json['bestTravelPeriod'] as String? ?? 'Morning',
      recommendedDeparture: json['recommendedDeparture'] as String?,
      departureReason: json['departureReason'] as String?,
      recommendation: json['recommendation'] as String? ?? '',
      highlights: (json['highlights'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      explanationBullets:
          (json['explanationBullets'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      reasons: reasons,
      recommendedActivities:
          (json['recommendedActivities'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      preferredPeriodComparison: json['preferredPeriodComparison'] as String?,
      isRouteAvailable: json['isRouteAvailable'] as bool? ?? true,
      analysisLimitation: json['analysisLimitation'] as String?,
      breakdown: json['breakdown'] != null
          ? TravelScoreBreakdown.fromJson(json['breakdown'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'weatherSubscore': weatherSubscore,
      'journeySubscore': journeySubscore,
      'suitability': suitability.name,
      'levelName': levelName,
      'bestTravelPeriod': bestTravelPeriod,
      'recommendedDeparture': recommendedDeparture,
      'departureReason': departureReason,
      'recommendation': recommendation,
      'highlights': highlights,
      'explanationBullets': explanationBullets,
      'reasons': reasons.map((r) => r.name).toList(),
      'recommendedActivities': recommendedActivities,
      'preferredPeriodComparison': preferredPeriodComparison,
      'isRouteAvailable': isRouteAvailable,
      'analysisLimitation': analysisLimitation,
      'breakdown': breakdown.toJson(),
    };
  }
}
