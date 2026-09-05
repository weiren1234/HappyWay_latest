import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum TravelSuitability {
  ideal,
  moderate,
  challenging
}

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

class TravelScoreBreakdown {
  final int weatherScore;
  final int? journeyScore;
  final int? morningScore;
  final int? afternoonScore;
  final int? nightScore;
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
        weatherScore: (json['weatherScore'] as num?)?.toInt() ?? 0,
        journeyScore: (json['journeyScore'] as num?)?.toInt(),
        morningScore: (json['morningScore'] as num?)?.toInt(),
        afternoonScore: (json['afternoonScore'] as num?)?.toInt(),
        nightScore: (json['nightScore'] as num?)?.toInt(),
        isWeatherComplete: json['isWeatherComplete'] as bool? ?? true,
      );
}

class TravelScore {
  final int score;
  final int weatherSubscore;
  final int? journeySubscore;
  final TravelSuitability suitability;
  final String levelName;
  final String bestTravelPeriod;
  final String? recommendedDeparture;
  final String? departureReason;
  final String? bestWeatherWindow;
  final String? selectedPeriod;
  final String? recommendedPeriod;
  final String recommendation;
  final List<String> highlights;
  final List<String> explanationBullets;
  final List<TravelRecommendationReason> reasons;
  final List<String> recommendedActivities;
  final String? preferredPeriodComparison;
  final bool isRouteAvailable;
  final String? analysisLimitation;
  final TravelScoreBreakdown breakdown;
  final Color color;
  final bool isInitial;

  TravelScore({
    required this.score,
    int? weatherSubscore,
    this.journeySubscore,
    required this.suitability,
    String? levelName,
    required this.bestTravelPeriod,
    this.recommendedDeparture,
    this.departureReason,
    this.bestWeatherWindow,
    this.selectedPeriod,
    this.recommendedPeriod,
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
    this.isInitial = false,
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

  String get consumerSummary {
    switch (levelName) {
      case 'Excellent':
      case 'Very Good':
        return 'Great conditions expected for your trip.';
      case 'Good':
        return 'Good conditions expected for your trip.';
      case 'Moderate':
      case 'Fair':
        return 'Conditions are generally suitable for your trip.';
      case 'Less Ideal':
      case 'Challenging':
      case 'Poor':
      default:
        return 'Less favorable conditions expected for your trip.';
    }
  }

  factory TravelScore.initial() {
    return TravelScore(
      score: 0,
      weatherSubscore: 0,
      journeySubscore: null,
      suitability: TravelSuitability.moderate,
      levelName: 'Calculating...',
      bestTravelPeriod: 'Not available',
      recommendedDeparture: null,
      departureReason: null,
      bestWeatherWindow: null,
      selectedPeriod: 'Auto',
      recommendedPeriod: 'Not available',
      recommendation: 'Calculating travel recommendations based on latest weather and route conditions...',
      highlights: [],
      explanationBullets: const ['Awaiting live forecast data.'],
      reasons: const [TravelRecommendationReason.insufficientWeatherData],
      isRouteAvailable: false,
      analysisLimitation: 'Calculating...',
      isInitial: true,
      color: Colors.grey,
    );
  }

  factory TravelScore.fromJson(Map<String, dynamic> json) {
    final score = (json['score'] as num?)?.toInt() ?? 0;
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
      bestTravelPeriod: json['bestTravelPeriod'] as String? ?? 'Not available',
      recommendedDeparture: json['recommendedDeparture'] as String?,
      departureReason: json['departureReason'] as String?,
      bestWeatherWindow: json['bestWeatherWindow'] as String?,
      selectedPeriod: json['selectedPeriod'] as String?,
      recommendedPeriod: json['recommendedPeriod'] as String?,
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
      'bestWeatherWindow': bestWeatherWindow,
      'selectedPeriod': selectedPeriod,
      'recommendedPeriod': recommendedPeriod,
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
