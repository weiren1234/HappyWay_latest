import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../theme/app_colors.dart';

class TravelScoreCalculator {
    static TravelScore calculateScore({
    required WeatherInfo? weather,
    TravelRoute? route,
    String? preferredPeriod,
    List<String>? activityTags,
  }) {
    if (weather == null) {
      return TravelScore.initial();
    }

        final (weatherSubscore, isWeatherComplete, morningScore, afternoonScore, nightScore) =
        _calculateWeatherSuitabilityWithBreakdown(weather);

       final journeySubscore = route != null ? _calculateJourneyPracticality(route) : null;
    final isRouteAvailable = journeySubscore != null;

        final int overallScore = isRouteAvailable
        ? ((weatherSubscore * 0.60) + (journeySubscore * 0.40)).round().clamp(0, 100)
        : weatherSubscore;

    final TravelSuitability suitability;
    final String levelName;
    final Color color;

    if (overallScore >= 90) {
      suitability = TravelSuitability.ideal;
      levelName = 'Excellent';
      color = AppColors.safeGreen;
    } else if (overallScore >= 80) {
      suitability = TravelSuitability.ideal;
      levelName = 'Very Good';
      color = AppColors.safeGreen;
    } else if (overallScore >= 70) {
      suitability = TravelSuitability.moderate;
      levelName = 'Good';
      color = AppColors.accentCyan;
    } else if (overallScore >= 60) {
      suitability = TravelSuitability.moderate;
      levelName = 'Moderate';
      color = AppColors.cautionAmber;
    } else {
      suitability = TravelSuitability.challenging;
      levelName = 'Less Ideal';
      color = AppColors.dangerRed;
    }

    //Calculate Best Travel Period
    final bestPeriod = _calculateBestTravelPeriod(weather, isWeatherComplete);

    //Calculate Recommended Departure & Reason
    final (departure, departureReason) = _calculateRecommendedDeparture(weather, route, isWeatherComplete);

    //Preferred Period Matching
    final (preferredMatchReason, preferredComparisonText) =
        _comparePreferredPeriod(preferredPeriod, bestPeriod);

    //Generate Reasons & Explanations
    final (reasons, explanationBullets) = _generateReasonsAndBullets(
      weather: weather,
      route: route,
      bestPeriod: bestPeriod,
      preferredReason: preferredMatchReason,
      preferredComparisonText: preferredComparisonText,
      isWeatherComplete: isWeatherComplete,
    );

    //Generate Weather-informed Activity Suggestions
    final recommendedActivities = _generateActivityRecommendations(
      activityTags: activityTags,
      weather: weather,
      bestPeriod: bestPeriod,
    );

    //Highlights
    final highlights = _generateHighlights(weather, route, bestPeriod);
    final recommendation = _generateRecommendation(overallScore, bestPeriod, isRouteAvailable);

    final breakdown = TravelScoreBreakdown(
      weatherScore: weatherSubscore,
      journeyScore: journeySubscore,
      morningScore: morningScore,
      afternoonScore: afternoonScore,
      nightScore: nightScore,
      isWeatherComplete: isWeatherComplete,
    );

    return TravelScore(
      score: overallScore,
      weatherSubscore: weatherSubscore,
      journeySubscore: journeySubscore,
      suitability: suitability,
      levelName: levelName,
      bestTravelPeriod: bestPeriod,
      recommendedDeparture: departure,
      departureReason: departureReason,
      recommendation: recommendation,
      highlights: highlights,
      explanationBullets: explanationBullets,
      reasons: reasons,
      recommendedActivities: recommendedActivities,
      preferredPeriodComparison: preferredComparisonText,
      isRouteAvailable: isRouteAvailable,
      analysisLimitation: !isRouteAvailable
          ? 'Weather-based analysis only (driving route unavailable)'
          : null,
      breakdown: breakdown,
      color: color,
    );
  }

  //Weather Suitability Algorithm

  /// Calculates Weather Suitability Score (0 - 100) from official MET fields.
  static int calculateWeatherSuitability(WeatherInfo? weather) {
    if (weather == null) return 75;
    final (score, _, _, _, _) = _calculateWeatherSuitabilityWithBreakdown(weather);
    return score;
  }

  static (int score, bool isComplete, int morning, int afternoon, int night)
      _calculateWeatherSuitabilityWithBreakdown(WeatherInfo weather) {
    final (morningPenalty, morningScore) = _evaluatePeriod(weather.morningCondition, 1.0);
    final (afternoonPenalty, afternoonScore) = _evaluatePeriod(weather.afternoonCondition, 1.0);
    final (nightPenalty, nightScore) = _evaluatePeriod(weather.nightCondition, 0.6);

    final hasMorning = weather.morningCondition != null && weather.morningCondition!.trim().isNotEmpty;
    final hasAfternoon = weather.afternoonCondition != null && weather.afternoonCondition!.trim().isNotEmpty;
    final hasNight = weather.nightCondition != null && weather.nightCondition!.trim().isNotEmpty;

    final isComplete = hasMorning && hasAfternoon;

    // If all period conditions are missing, weather data is insufficient -> neutral baseline
    if (!hasMorning && !hasAfternoon && !hasNight) {
      return (50, false, 50, 50, 50);
    }

    int score = 100 - morningPenalty - afternoonPenalty - nightPenalty;

    // Significant Weather / Alert evaluation
    final sig = (weather.significantWeather ?? '').toLowerCase();
    if (sig.contains('warning') || sig.contains('amaran')) {
      score -= 20;
    } else if (sig.contains('heavy rain') || sig.contains('hujan lebat')) {
      score -= 20;
    }

    // Extreme Temperature Penalties
    if (weather.maxTemperature != null) {
      if (weather.maxTemperature! >= 35.0) {
        score -= 6; // Very hot afternoon
      }
    }

    return (score.clamp(10, 100), isComplete, morningScore, afternoonScore, nightScore);
  }

  static (int penalty, int subscore) _evaluatePeriod(String? condition, double weight) {
    if (condition == null || condition.trim().isEmpty) {
      // Missing period receives a neutral uncertainty deduction (-6) so it does NOT act like 100% dry
      final penalty = (6 * weight).round();
      return (penalty, 70);
    }

    final c = condition.toLowerCase().trim();

    // 1. Explicit positive dry conditions (0 penalty)
    if (_isExplicitDry(c)) {
      return (0, 100);
    }

    // 2. Severe conditions
    if (c.contains('thunderstorm') || c.contains('ribut petir')) {
      final penalty = (18 * weight).round();
      return (penalty, 35);
    }
    if (c.contains('heavy rain') || c.contains('hujan lebat')) {
      final penalty = (16 * weight).round();
      return (penalty, 40);
    }
    if (c.contains('scattered rain') || c.contains('hujan berterusan')) {
      final penalty = (12 * weight).round();
      return (penalty, 55);
    }
    if (c.contains('isolated rain') ||
        c.contains('hujan') ||
        c.contains('showers') ||
        c.contains('rain') ||
        c.contains('drizzle') ||
        c.contains('gerimis')) {
      final penalty = (7 * weight).round();
      return (penalty, 75);
    }
    if (c.contains('cloudy') || c.contains('berawan') || c.contains('mendung') || c.contains('overcast')) {
      final penalty = (2 * weight).round();
      return (penalty, 90);
    }
    if (c.contains('hazy') ||
        c.contains('haze') ||
        c.contains('jerebu') ||
        c.contains('berjerebu') ||
        c.contains('fog') ||
        c.contains('kabut') ||
        c.contains('berkabut') ||
        c.contains('mist')) {
      final penalty = (4 * weight).round();
      return (penalty, 85);
    }

    // 3. Unknown condition text -> neutral handling (do not crash, log in debug)
    if (kDebugMode) {
      debugPrint('[TravelScoreCalculator] Unknown MET condition encountered: "$condition"');
    }
    final penalty = (3 * weight).round();
    return (penalty, 80);
  }

  /// Strictly checks for explicit positive dry keywords from official MET Malaysia vocabulary.
  static bool _isExplicitDry(String conditionLower) {
    return conditionLower.contains('tiada hujan') ||
        conditionLower.contains('no rain') ||
        conditionLower.contains('cerah') ||
        conditionLower.contains('clear') ||
        conditionLower.contains('fair') ||
        conditionLower.contains('panas') ||
        conditionLower.contains('sunny') ||
        conditionLower.contains('fine');
  }

  /// Evaluates whether a condition is dry. Null/empty returns false (missing != dry).
  static bool _isDryCondition(String? cond) {
    if (cond == null || cond.trim().isEmpty) return false;
    final lower = cond.toLowerCase().trim();
    if (_isExplicitDry(lower)) return true;
    return false;
  }

  // ─── Journey Practicality Algorithm ──────────────────────────────────────────

  /// Calculates Journey Practicality Score (0 - 100) from OSRM driving duration.
  static int? calculateJourneyPracticality(TravelRoute? route) {
    return _calculateJourneyPracticality(route);
  }

  static int? _calculateJourneyPracticality(TravelRoute? route) {
    if (route == null) return null;
    final minutes = route.durationMinutes;

    if (minutes <= 90) {
      return 95; // <= 1.5 hours
    } else if (minutes <= 180) {
      return 88; // <= 3.0 hours
    } else if (minutes <= 270) {
      return 78; // <= 4.5 hours
    } else if (minutes <= 360) {
      return 68; // <= 6.0 hours
    } else {
      return math.max(45, 68 - ((minutes - 360) ~/ 30) * 3);
    }
  }

  // ─── Best Travel Period Calculation ─────────────────────────────────────────

  static String _calculateBestTravelPeriod(WeatherInfo weather, bool isWeatherComplete) {
    final morning = weather.morningCondition?.toLowerCase().trim() ?? '';
    final afternoon = weather.afternoonCondition?.toLowerCase().trim() ?? '';
    final night = weather.nightCondition?.toLowerCase().trim() ?? '';

    if (morning.isEmpty && afternoon.isEmpty && night.isEmpty) {
      return 'Recommended period unavailable';
    }

    final isMorningDry = _isDryCondition(morning);
    final isAfternoonDry = _isDryCondition(afternoon);
    final isNightDry = _isDryCondition(night);

    if (isMorningDry && isAfternoonDry && isNightDry) {
      return 'All Day (Dry & Clear)';
    } else if (isMorningDry && !isAfternoonDry && isNightDry) {
      return 'Morning or Night';
    } else if (isMorningDry && !isAfternoonDry) {
      return 'Morning';
    } else if (!isMorningDry && isAfternoonDry) {
      return 'Afternoon';
    } else if (!isMorningDry && !isAfternoonDry && isNightDry) {
      return 'Night';
    } else if (!isMorningDry && !isAfternoonDry && !isNightDry) {
      return 'Indoor Activities Recommended';
    } else {
      return isMorningDry ? 'Morning' : (isAfternoonDry ? 'Afternoon' : 'Morning');
    }
  }

  // ─── Recommended Departure Calculation ──────────────────────────────────────

  static (String, String) _calculateRecommendedDeparture(
    WeatherInfo weather,
    TravelRoute? route,
    bool isWeatherComplete,
  ) {
    final morning = weather.morningCondition?.toLowerCase().trim() ?? '';
    final afternoon = weather.afternoonCondition?.toLowerCase().trim() ?? '';

    final isMorningDry = _isDryCondition(morning);
    final isAfternoonDry = _isDryCondition(afternoon);

    if (isMorningDry && !isAfternoonDry) {
      final hours = route != null ? (route.durationMinutes / 60.0) : 2.5;
      if (hours <= 4.0) {
        return (
          'Around 8:00 AM',
          'Departing in the morning allows completing the drive before afternoon rain or thunderstorms develop at the destination (planning advice).',
        );
      } else {
        return (
          'Early Morning (Around 7:00 AM)',
          'Early departure recommended due to the longer driving duration, helping you arrive before afternoon weather worsens (planning advice).',
        );
      }
    } else if (!isMorningDry && isAfternoonDry) {
      return (
        'Around 1:00 PM',
        'Conditions at destination are forecast to improve in the afternoon as morning showers ease (planning advice).',
      );
    } else if (isMorningDry && isAfternoonDry) {
      return (
        'Flexible Departure',
        'Dry and stable weather conditions are forecast throughout the day (planning advice).',
      );
    } else {
      return (
        'Plan with Caution',
        'Showers or thunderstorms are forecast during multiple periods. Consider allowing extra travel time or choosing indoor activities.',
      );
    }
  }

  // ─── Preferred Period Matching ─────────────────────────────────────────────

  static (TravelRecommendationReason?, String?) _comparePreferredPeriod(
    String? preferredPeriod,
    String bestPeriod,
  ) {
    if (preferredPeriod == null || preferredPeriod.isEmpty || preferredPeriod == 'Auto Recommend') {
      return (null, null);
    }

    final prefClean = preferredPeriod.trim().toLowerCase();
    final bestClean = bestPeriod.toLowerCase();

    if (bestClean.contains(prefClean) || bestClean.contains('all day')) {
      return (
        TravelRecommendationReason.preferredPeriodMatch,
        'Your preferred $preferredPeriod travel window matches HappyWay\'s recommended period ($bestPeriod).',
      );
    } else {
      return (
        TravelRecommendationReason.preferredPeriodMismatch,
        '$bestPeriod currently has more favourable forecast conditions than your preferred $preferredPeriod.',
      );
    }
  }

  // ─── Reason Codes & Bullet Generation ──────────────────────────────────────

  static (List<TravelRecommendationReason>, List<String>) _generateReasonsAndBullets({
    required WeatherInfo weather,
    required TravelRoute? route,
    required String bestPeriod,
    required TravelRecommendationReason? preferredReason,
    required String? preferredComparisonText,
    required bool isWeatherComplete,
  }) {
    final reasons = <TravelRecommendationReason>[];
    final bullets = <String>[];

    final morning = weather.morningCondition?.toLowerCase() ?? '';
    final afternoon = weather.afternoonCondition?.toLowerCase() ?? '';
    final night = weather.nightCondition?.toLowerCase() ?? '';

    // Weather condition bullets
    if (_isDryCondition(morning)) {
      reasons.add(TravelRecommendationReason.favourableMorning);
      bullets.add('Morning conditions (${weather.morningCondition}) are favourable for outdoor travel.');
    } else if (morning.contains('thunderstorm') || morning.contains('ribut')) {
      reasons.add(TravelRecommendationReason.morningShowers);
      bullets.add('Morning thunderstorms forecast (${weather.morningCondition}); exercise caution.');
    } else if (morning.contains('hazy') || morning.contains('haze') || morning.contains('jerebu')) {
      bullets.add('Morning haze forecast (${weather.morningCondition}); visibility may be reduced.');
    } else if (morning.isNotEmpty) {
      bullets.add('Morning weather: ${weather.morningCondition}.');
    }

    if (_isDryCondition(afternoon)) {
      reasons.add(TravelRecommendationReason.favourableAfternoon);
      bullets.add('Afternoon weather (${weather.afternoonCondition}) is clear and stable.');
    } else if (afternoon.contains('thunderstorm') || afternoon.contains('ribut') || afternoon.contains('heavy rain')) {
      reasons.add(TravelRecommendationReason.afternoonThunderstorms);
      bullets.add('Afternoon thunderstorms or rain forecast (${weather.afternoonCondition}); plan indoor options.');
    } else if (afternoon.contains('hazy') || afternoon.contains('haze') || afternoon.contains('jerebu')) {
      bullets.add('Afternoon haze forecast (${weather.afternoonCondition}); visibility may be reduced.');
    } else if (afternoon.isNotEmpty) {
      bullets.add('Afternoon weather: ${weather.afternoonCondition}.');
    }

    if (_isDryCondition(morning) && _isDryCondition(afternoon) && _isDryCondition(night)) {
      reasons.add(TravelRecommendationReason.allDayDry);
    }

    // Significant Weather
    final sig = (weather.significantWeather ?? '').toLowerCase();
    if (sig.contains('warning') || sig.contains('amaran') || sig.contains('heavy rain')) {
      reasons.add(TravelRecommendationReason.significantWeatherWarning);
      bullets.add('MET advisory: ${weather.significantWeather}.');
    }

    // Temperatures
    if (weather.maxTemperature != null && weather.maxTemperature! >= 35.0) {
      reasons.add(TravelRecommendationReason.hotTemperature);
      bullets.add('High afternoon temperature expected (${weather.maxTemperature!.round()}°C); stay hydrated.');
    } else if (weather.maxTemperature != null && weather.maxTemperature! <= 24.0) {
      reasons.add(TravelRecommendationReason.coolHighlands);
      bullets.add('Cool climate (${weather.minTemperature?.round() ?? 16}°C – ${weather.maxTemperature!.round()}°C) suitable for sightseeing.');
    }

    // Route / Journey bullets
    if (route != null) {
      if (route.durationMinutes <= 120) {
        reasons.add(TravelRecommendationReason.comfortableDrive);
        bullets.add('Direct driving route available (${route.distanceFormatted}, approx. ${route.durationFormatted}).');
      } else {
        reasons.add(TravelRecommendationReason.longDrive);
        bullets.add('Longer road journey (${route.distanceFormatted}, approx. ${route.durationFormatted}); plan rest stops.');
      }
    } else {
      reasons.add(TravelRecommendationReason.drivingRouteUnavailable);
      bullets.add('Direct driving route unavailable; score reflects weather suitability only.');
    }

    // Preferred period bullet
    if (preferredReason != null && preferredComparisonText != null) {
      reasons.add(preferredReason);
      bullets.add(preferredComparisonText);
    }

    return (reasons, bullets);
  }

  // ─── Weather-Informed Activity Suggestions (Curated Destinations Only) ───────

  static List<String> _generateActivityRecommendations({
    required List<String>? activityTags,
    required WeatherInfo weather,
    required String bestPeriod,
  }) {
    // If destination has no curated tags (e.g. arbitrary geocoded address), return empty list (no fake tags)
    if (activityTags == null || activityTags.isEmpty) {
      return [];
    }

    final activities = <String>[];
    final tagsLower = activityTags.map((t) => t.toLowerCase()).toSet();
    final morningDry = _isDryCondition(weather.morningCondition);
    final afternoonDry = _isDryCondition(weather.afternoonCondition);

    if (tagsLower.contains('beach') || tagsLower.contains('island')) {
      if (morningDry) {
        activities.add('Beach strolls & water activities in the morning');
      }
      if (!afternoonDry) {
        activities.add('Indoor seaside dining & relaxation in the afternoon');
      } else {
        activities.add('Afternoon sunset viewing and coastal exploration');
      }
    }

    if (tagsLower.contains('highlands')) {
      if (morningDry) {
        activities.add('Tea plantation visits and mountain viewpoints in the morning');
      }
      activities.add('Strawberry picking, cafes & indoor markets');
    }

    if (tagsLower.contains('nature') || tagsLower.contains('hiking')) {
      if (morningDry) {
        activities.add('Nature trail walking and canopy exploration in the morning');
      } else {
        activities.add('Nature discovery centres and covered observation walks');
      }
    }

    if (tagsLower.contains('sightseeing') || tagsLower.contains('family trip')) {
      if (morningDry) {
        activities.add('Outdoor sightseeing and landmarks in the morning');
      }
      if (!afternoonDry) {
        activities.add('Museums, shopping galleries & indoor family entertainment');
      }
    }

    if (activities.isEmpty) {
      if (morningDry) {
        activities.add('Outdoor exploration recommended during the morning window');
      }
      if (!afternoonDry) {
        activities.add('Indoor activities recommended during afternoon periods');
      }
    }

    return activities.take(3).toList();
  }

  // ─── Highlights & Recommendation Text ───────────────────────────────────────

  static List<String> _generateHighlights(
    WeatherInfo weather,
    TravelRoute? route,
    String bestPeriod,
  ) {
    final items = <String>[];

    if (route != null) {
      items.add(
        'Driving route: ${route.distanceFormatted}, estimated normal drive: ${route.durationFormatted}.',
      );
    } else {
      items.add('Direct driving route unavailable from this origin.');
    }

    if (weather.morningCondition != null && weather.morningCondition!.isNotEmpty) {
      items.add('Morning: ${weather.morningCondition}');
    }
    if (weather.afternoonCondition != null && weather.afternoonCondition!.isNotEmpty) {
      items.add('Afternoon: ${weather.afternoonCondition}');
    }
    if (weather.nightCondition != null && weather.nightCondition!.isNotEmpty) {
      items.add('Night: ${weather.nightCondition}');
    }
    if (weather.minTemperature != null && weather.maxTemperature != null) {
      items.add('Temperature Range: ${weather.minTemperature!.round()}°C – ${weather.maxTemperature!.round()}°C');
    }

    return items;
  }

  static String _generateRecommendation(
    int score,
    String bestPeriod,
    bool isRouteAvailable,
  ) {
    final routeNote = isRouteAvailable ? '' : ' (weather-based analysis)';
    if (score >= 80) {
      return 'Conditions are favourable for travel$routeNote. $bestPeriod is the optimal window for outdoor activities.';
    } else if (score >= 60) {
      return 'Moderate travel conditions$routeNote. We recommend planning activities around the $bestPeriod window.';
    } else {
      return 'Challenging weather forecast$routeNote. Prioritize indoor activities and check official MET updates.';
    }
  }
}
