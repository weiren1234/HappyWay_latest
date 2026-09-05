import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../theme/app_colors.dart';
import 'hourly_travel_analyzer.dart';

class TravelScoreCalculator {
  static TravelScore calculateScore({
    required WeatherInfo? weather,
    TravelRoute? route,
    String? preferredPeriod,
    List<String>? activityTags,
    DateTime? travelDate,
    DateTime? currentTimeOverride,
  }) {
    if (weather == null) {
      return TravelScore.initial();
    }

    final date = travelDate ?? DateTime.now();

    // ── 1. Hourly Weather Integration (Real Open-Meteo Data) ────────────────
    if (weather.hourlyForecast != null && weather.hourlyForecast!.isNotEmpty) {
      final hourlyResult = HourlyTravelAnalyzer.analyze(
        hourlyForecast: weather.hourlyForecast,
        targetDate: date,
        route: route,
        preferredPeriod: preferredPeriod,
        currentTimeOverride: currentTimeOverride,
      );

      int weatherSubscore = hourlyResult.hourlyWeatherSuitability;

      // Official MET Malaysia Significant Weather Warning penalty (FSIGW)
      final sig = (weather.significantWeather ?? '').toLowerCase();
      if (sig.contains('warning') || sig.contains('amaran')) {
        weatherSubscore = (weatherSubscore - 20).clamp(10, 100);
      } else if (sig.contains('heavy rain') || sig.contains('hujan lebat')) {
        weatherSubscore = (weatherSubscore - 20).clamp(10, 100);
      }

      final journeySubscore = route != null ? _calculateJourneyPracticality(route) : null;
      final isRouteAvailable = journeySubscore != null;

      final int overallScore = isRouteAvailable
          ? ((weatherSubscore * 0.60) + (journeySubscore * 0.40)).round().clamp(0, 100)
          : weatherSubscore;

      final (suitability, levelName, color) = _resolveScoreTiers(overallScore);

      final (preferredMatchReason, preferredComparisonText) =
          _comparePreferredPeriod(preferredPeriod, hourlyResult.recommendedPeriod);

      final (reasons, explanationBullets) = _generateReasonsAndBullets(
        weather: weather,
        route: route,
        bestPeriod: hourlyResult.recommendedPeriod,
        preferredReason: preferredMatchReason,
        preferredComparisonText: preferredComparisonText,
        isWeatherComplete: hourlyResult.hasSufficientData,
      );

      final combinedBullets = <String>[
        ...hourlyResult.explanationBullets,
        ...explanationBullets.where((b) => !b.contains('Estimated driving duration') && !b.contains('Driving route unavailable')),
      ];

      final recommendedActivities = _generateActivityRecommendations(
        activityTags: activityTags,
        weather: weather,
        bestPeriod: hourlyResult.recommendedPeriod,
      );

      final highlights = _generateHighlights(weather, route, hourlyResult.recommendedPeriod);

      final breakdown = TravelScoreBreakdown(
        weatherScore: weatherSubscore,
        journeyScore: journeySubscore,
        morningScore: hourlyResult.morningSuitability,
        afternoonScore: hourlyResult.afternoonSuitability,
        nightScore: hourlyResult.nightSuitability,
        isWeatherComplete: hourlyResult.hasSufficientData,
      );

      return TravelScore(
        score: overallScore,
        weatherSubscore: weatherSubscore,
        journeySubscore: journeySubscore,
        suitability: suitability,
        levelName: levelName,
        bestTravelPeriod: hourlyResult.recommendedPeriod,
        recommendedDeparture: hourlyResult.suggestedDeparture,
        departureReason: hourlyResult.departureReason,
        bestWeatherWindow: hourlyResult.bestWeatherWindow,
        selectedPeriod: hourlyResult.selectedPeriod,
        recommendedPeriod: hourlyResult.recommendedPeriod,
        recommendation: hourlyResult.travelAdvice,
        highlights: highlights,
        explanationBullets: combinedBullets,
        reasons: reasons,
        recommendedActivities: recommendedActivities,
        preferredPeriodComparison: preferredComparisonText,
        isRouteAvailable: isRouteAvailable,
        analysisLimitation: !isRouteAvailable
            ? 'Weather-based analysis only (driving route unavailable)'
            : null,
        breakdown: breakdown,
        color: color,
        isInitial: false,
      );
    }

    // ── 2. MET Malaysia 3-Period Fallback (When Hourly Unavailable) ─────────
    final isWeatherComplete = weather.morningCondition != null && weather.afternoonCondition != null;
    final bestPeriod = _calculateBestTravelPeriod(weather, isWeatherComplete);

    final (weatherSubscore, _, morningScore, afternoonScore, nightScore) =
        _calculateWeatherSuitabilityWithBreakdown(weather, preferredPeriod, bestPeriod);

    final journeySubscore = route != null ? _calculateJourneyPracticality(route) : null;
    final isRouteAvailable = journeySubscore != null;

    final int overallScore = isRouteAvailable
        ? ((weatherSubscore * 0.60) + (journeySubscore * 0.40)).round().clamp(0, 100)
        : weatherSubscore;

    final (suitability, levelName, color) = _resolveScoreTiers(overallScore);

    final (departure, departureReason) = _calculateRecommendedDeparture(weather, route, isWeatherComplete);

    final (preferredMatchReason, preferredComparisonText) =
        _comparePreferredPeriod(preferredPeriod, bestPeriod);

    final (reasons, explanationBullets) = _generateReasonsAndBullets(
      weather: weather,
      route: route,
      bestPeriod: bestPeriod,
      preferredReason: preferredMatchReason,
      preferredComparisonText: preferredComparisonText,
      isWeatherComplete: isWeatherComplete,
    );

    final recommendedActivities = _generateActivityRecommendations(
      activityTags: activityTags,
      weather: weather,
      bestPeriod: bestPeriod,
    );

    final highlights = _generateHighlights(weather, route, bestPeriod);
    final recommendation = _generateRecommendation(overallScore, bestPeriod, isRouteAvailable, weather);

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
      bestWeatherWindow: null,
      selectedPeriod: preferredPeriod ?? 'Auto',
      recommendedPeriod: bestPeriod,
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
      isInitial: false,
    );
  }

  static (TravelSuitability, String, Color) _resolveScoreTiers(int overallScore) {
    if (overallScore >= 90) {
      return (TravelSuitability.ideal, 'Excellent', AppColors.safeGreen);
    } else if (overallScore >= 80) {
      return (TravelSuitability.ideal, 'Very Good', AppColors.safeGreen);
    } else if (overallScore >= 70) {
      return (TravelSuitability.moderate, 'Good', AppColors.accentCyan);
    } else if (overallScore >= 60) {
      return (TravelSuitability.moderate, 'Moderate', AppColors.cautionAmber);
    } else {
      return (TravelSuitability.challenging, 'Less Ideal', AppColors.dangerRed);
    }
  }

  // ─── Weather Suitability Algorithm ──────────────────────────────────────────

  /// Calculates Weather Suitability Score (0 - 100) from official MET fields.
  static int calculateWeatherSuitability(WeatherInfo? weather, [String? preferredPeriod]) {
    if (weather == null) return 0;
    final bestPeriod = _calculateBestTravelPeriod(weather, true);
    final (score, _, _, _, _) = _calculateWeatherSuitabilityWithBreakdown(weather, preferredPeriod, bestPeriod);
    return score;
  }

  static (int score, bool isComplete, int morning, int afternoon, int night)
      _calculateWeatherSuitabilityWithBreakdown(
    WeatherInfo weather, [
    String? preferredPeriod,
    String? resolvedBestPeriod,
  ]) {
    final (morningPenalty, morningScore) = _evaluatePeriod(weather.morningCondition, 1.0);
    final (afternoonPenalty, afternoonScore) = _evaluatePeriod(weather.afternoonCondition, 1.0);
    final (nightPenalty, nightScore) = _evaluatePeriod(weather.nightCondition, 0.6);

    final hasMorning = weather.morningCondition != null && weather.morningCondition!.trim().isNotEmpty;
    final hasAfternoon = weather.afternoonCondition != null && weather.afternoonCondition!.trim().isNotEmpty;
    final hasNight = weather.nightCondition != null && weather.nightCondition!.trim().isNotEmpty;

    final isComplete = hasMorning && hasAfternoon;

    if (!hasMorning && !hasAfternoon && !hasNight) {
      return (50, false, 50, 50, 50);
    }

    final int baseDayScore = (100 - morningPenalty - afternoonPenalty - nightPenalty).clamp(10, 100);

    final pClean = (preferredPeriod ?? '').trim().toLowerCase();
    int score;
    if (pClean.startsWith('morning')) {
      // User chose Morning: score reflects morning travel condition
      score = morningScore;
    } else if (pClean.startsWith('afternoon')) {
      // User chose Afternoon: score reflects afternoon travel condition
      score = afternoonScore;
    } else if (pClean.startsWith('night')) {
      // User chose Night: score reflects night travel condition
      score = nightScore;
    } else if (pClean.startsWith('auto')) {
      // Auto / Auto Recommend: optimizes around best travel period while considering overall day
      final best = (resolvedBestPeriod ?? '').toLowerCase();
      if (best.contains('morning')) {
        score = ((morningScore * 0.7) + (baseDayScore * 0.3)).round();
      } else if (best.contains('afternoon')) {
        score = ((afternoonScore * 0.7) + (baseDayScore * 0.3)).round();
      } else if (best.contains('night')) {
        score = ((nightScore * 0.7) + (baseDayScore * 0.3)).round();
      } else {
        score = baseDayScore;
      }
    } else {
      // General destination analysis without a selected travel period
      score = baseDayScore;
    }

    // Significant Weather / Alert evaluation
    final sig = (weather.significantWeather ?? '').toLowerCase();
    if (sig.contains('warning') || sig.contains('amaran')) {
      score -= 20;
    } else if (sig.contains('heavy rain') || sig.contains('hujan lebat')) {
      score -= 20;
    }

    // Extreme Temperature Penalties (relevant for daytime periods)
    if (!pClean.startsWith('night')) {
      if (weather.maxTemperature != null) {
        if (weather.maxTemperature! >= 35.0) {
          score -= 6;
        }
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
      return 'Not available';
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
      // All periods have precipitation — recommend Morning as the least-worst option
      return 'Morning';
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
    final night = weather.nightCondition?.toLowerCase().trim() ?? '';

    final isMorningDry = _isDryCondition(morning);
    final isAfternoonDry = _isDryCondition(afternoon);
    final isNightDry = _isDryCondition(night);

    if (morning.isEmpty && afternoon.isEmpty && night.isEmpty) {
      return ('Not available', 'Weather forecast data is currently unavailable for this destination.');
    }

    if (isMorningDry && !isAfternoonDry) {
      final hours = route != null ? (route.durationMinutes / 60.0) : 2.5;
      if (hours <= 4.0) {
        return (
          'Around 8:00 AM',
          'Departing in the morning lets you complete the drive before afternoon showers develop at the destination.',
        );
      } else {
        return (
          'Early Morning (Around 7:00 AM)',
          'An early start is recommended for this longer journey, so you arrive before afternoon weather changes.',
        );
      }
    } else if (!isMorningDry && isAfternoonDry) {
      return (
        'Afternoon',
        'Conditions are forecast to improve in the afternoon as morning showers ease. Departing after midday is advisable.',
      );
    } else if (isMorningDry && isAfternoonDry) {
      final hours = route != null ? (route.durationMinutes / 60.0) : 2.5;
      final timeStr = hours <= 3.0 ? 'Around 8:30 AM' : 'Around 7:30 AM';
      return (
        timeStr,
        'Dry and stable conditions are forecast throughout the day — morning departure is recommended.',
      );
    } else if (!isMorningDry && !isAfternoonDry && isNightDry) {
      return (
        'Around 7:00 PM',
        'Rain is expected during the day. An evening departure encounters more favourable night conditions.',
      );
    } else {
      // All periods have precipitation — recommend morning as conditions tend to be calmer early
      return (
        'Around 7:30 AM',
        'Rain is forecast throughout the day. Conditions are more suitable earlier in the day — allow extra travel time and prepare for wet conditions.',
      );
    }
  }

  // ─── Preferred Period Matching ─────────────────────────────────────────────

  static (TravelRecommendationReason?, String?) _comparePreferredPeriod(
    String? preferredPeriod,
    String bestPeriod,
  ) {
    if (preferredPeriod == null || preferredPeriod.isEmpty ||
        preferredPeriod == 'Auto Recommend' || preferredPeriod == 'Auto') {
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
      bullets.add('Afternoon thunderstorms or rain forecast (${weather.afternoonCondition}); consider adjusting departure time if conditions worsen.');
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

    // Preferred period reason code
    if (preferredReason != null) {
      reasons.add(preferredReason);
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
      if (afternoonDry) {
        activities.add('Afternoon sightseeing and scenic spots');
      } else {
        activities.add('Local sightseeing and cultural exploration during afternoon');
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
    WeatherInfo? weather,
  ) {
    final allWet = weather != null &&
        !_isDryCondition(weather.morningCondition) &&
        !_isDryCondition(weather.afternoonCondition) &&
        !_isDryCondition(weather.nightCondition);

    if (score >= 80) {
      return 'Good conditions for travel. $bestPeriod is the recommended window for outdoor activities.';
    } else if (score >= 60) {
      return 'Some weather changes expected. Plan your activities around the $bestPeriod window and check the latest forecast before departure.';
    } else if (allWet) {
      return 'Rain may affect your plans. Allow extra travel time and prepare for wet conditions. Conditions are more suitable earlier in the day.';
    } else {
      return 'Thunderstorms may affect travel. Consider adjusting your departure time if conditions worsen.';
    }
  }
}
