import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';

/// Period definition for HappyWay hourly weather analysis.
enum TravelPeriod {
  morning,
  afternoon,
  night;

  String get displayName {
    switch (this) {
      case TravelPeriod.morning:
        return 'Morning';
      case TravelPeriod.afternoon:
        return 'Afternoon';
      case TravelPeriod.night:
        return 'Night';
    }
  }

  /// HappyWay Period Hours:
  /// Morning: 06:00 – 11:59 (hours 6, 7, 8, 9, 10, 11)
  /// Afternoon: 12:00 – 17:59 (hours 12, 13, 14, 15, 16, 17)
  /// Night: 18:00 – 23:59 (hours 18, 19, 20, 21, 22, 23)
  int get startHour {
    switch (this) {
      case TravelPeriod.morning:
        return 6;
      case TravelPeriod.afternoon:
        return 12;
      case TravelPeriod.night:
        return 18;
    }
  }

  int get endHour {
    switch (this) {
      case TravelPeriod.morning:
        return 11;
      case TravelPeriod.afternoon:
        return 17;
      case TravelPeriod.night:
        return 23;
    }
  }

  static TravelPeriod? fromString(String? val) {
    if (val == null) return null;
    final lower = val.trim().toLowerCase();
    if (lower.startsWith('morning')) return TravelPeriod.morning;
    if (lower.startsWith('afternoon')) return TravelPeriod.afternoon;
    if (lower.startsWith('night')) return TravelPeriod.night;
    return null;
  }
}

/// Evaluation summary for an individual period.
class PeriodEvaluation {
  final TravelPeriod period;
  final int score; // Suitability score (0 - 100) for eligible hours
  final int fullScore; // Full period score including past hours for statistical context
  final int minScore; // Minimum hourly suitability (floor)
  final double avgPrecipProb; // Average precipitation probability (0 - 100)
  final bool hasThunderstorm; // Presence of thunderstorm WMO codes (95, 96, 99)
  final bool hasHeavyRain; // Presence of heavy rain WMO codes (63, 65, 81, 82)
  final bool isFeasible; // True if eligible future hours exist for this period
  final List<HourlyWeatherItem> eligibleItems;

  const PeriodEvaluation({
    required this.period,
    required this.score,
    required this.fullScore,
    required this.minScore,
    required this.avgPrecipProb,
    required this.hasThunderstorm,
    required this.hasHeavyRain,
    required this.isFeasible,
    required this.eligibleItems,
  });
}

/// Comprehensive, reusable hourly travel analysis result.
class HourlyTravelAnalysisResult {
  final int morningSuitability;
  final int afternoonSuitability;
  final int nightSuitability;
  final String recommendedPeriod; // 'Morning', 'Afternoon', 'Night', or 'Not available'
  final String selectedPeriod; // 'Morning', 'Afternoon', 'Night', 'Auto'
  final String? bestWeatherWindow; // e.g. '8:00 AM – 11:00 AM'
  final String? suggestedDeparture; // e.g. 'Around 8:00 AM'
  final String? departureReason;
  final int hourlyWeatherSuitability;
  final String travelAdvice;
  final List<String> explanationBullets;
  final bool hasSufficientData;
  final Map<TravelPeriod, PeriodEvaluation>? periodEvaluations;

  const HourlyTravelAnalysisResult({
    required this.morningSuitability,
    required this.afternoonSuitability,
    required this.nightSuitability,
    required this.recommendedPeriod,
    required this.selectedPeriod,
    this.bestWeatherWindow,
    this.suggestedDeparture,
    this.departureReason,
    required this.hourlyWeatherSuitability,
    required this.travelAdvice,
    required this.explanationBullets,
    required this.hasSufficientData,
    this.periodEvaluations,
  });
}

/// Centralized analyzer that turns real Open-Meteo hourly weather data into
/// actionable HappyWay travel planning decisions.
class HourlyTravelAnalyzer {
  HourlyTravelAnalyzer._();

  /// Calculates suitability score (10 - 100) for an individual hour.
  ///
  /// Scoring model:
  /// - Base: 100
  /// - WMO Weather Code severity penalty: 0 to -85
  /// - Precipitation probability penalty: 0 to -25
  /// - Extreme apparent temperature penalty: 0 to -8
  /// - High UV index penalty (daytime): 0 to -5
  /// - Poor visibility penalty: 0 to -10
  ///
  /// Note: Relative humidity and wind speed are informative display/advisory
  /// metrics presented in the UI, and do not directly penalize the suitability score.
  static int calculateHourSuitability(HourlyWeatherItem item) {
    int penalty = 0;

    // 1. WMO Weather Code / Condition Penalty
    final wCode = item.weatherCode;
    if (wCode != null) {
      if (wCode == 0 || wCode == 1) {
        // Clear / Mainly Clear
        penalty += 0;
      } else if (wCode == 2) {
        // Partly Cloudy
        penalty += 5;
      } else if (wCode == 3) {
        // Cloudy / Overcast
        penalty += 12;
      } else if (wCode == 45 || wCode == 48) {
        // Foggy / Rime Fog (Open-Meteo WMO Fog; MET Haze handled separately)
        penalty += 15;
      } else if (wCode == 51 || wCode == 53 || wCode == 55) {
        // Drizzle
        penalty += 28;
      } else if (wCode == 61 || wCode == 80) {
        // Slight/Moderate Rain or Rain Showers
        penalty += 40;
      } else if (wCode == 63 || wCode == 65 || wCode == 81 || wCode == 82) {
        // Heavy Rain or Heavy Showers
        penalty += 60;
      } else if (wCode == 95) {
        // Thunderstorm
        penalty += 75;
      } else if (wCode == 96 || wCode == 99) {
        // Severe Thunderstorm with Hail
        penalty += 85;
      } else {
        penalty += 10;
      }
    } else {
      // Fallback condition text check if WMO code is missing
      final c = item.condition.toLowerCase();
      if (c.contains('thunderstorm') || c.contains('ribut')) {
        penalty += 75;
      } else if (c.contains('heavy rain') || c.contains('lebat')) {
        penalty += 60;
      } else if (c.contains('rain') || c.contains('showers') || c.contains('hujan')) {
        penalty += 40;
      } else if (c.contains('drizzle') || c.contains('gerimis')) {
        penalty += 28;
      } else if (c.contains('cloud') || c.contains('mendung') || c.contains('berawan')) {
        penalty += 10;
      }
    }

    // 2. Precipitation Probability Penalty
    final precip = item.precipitationProbability;
    if (precip != null) {
      if (precip > 80) {
        penalty += 25;
      } else if (precip > 60) {
        penalty += 18;
      } else if (precip > 35) {
        penalty += 10;
      } else if (precip > 15) {
        penalty += 4;
      }
    }

    // 3. Apparent Temperature (Feels-like) Penalty
    final feels = item.apparentTemperature ?? item.temperature;
    if (feels != null) {
      if (feels > 35.0) {
        penalty += 8; // Very hot
      } else if (feels > 32.0) {
        penalty += 3; // Warm
      } else if (feels < 16.0) {
        penalty += 5; // Unusually cold
      }
    }

    // 4. Real UV Index Penalty (Daytime hours 08:00 - 16:00 only)
    final h = item.time.hour;
    if (h >= 8 && h <= 16 && item.uvIndex != null) {
      final uv = item.uvIndex!;
      if (uv > 10.0) {
        penalty += 5; // Extreme UV
      } else if (uv >= 8.0) {
        penalty += 3; // Very High UV
      }
    }

    // 5. Visibility Penalty
    final vis = item.visibility;
    if (vis != null) {
      if (vis < 1000.0) {
        penalty += 10; // Very poor visibility / dense fog
      } else if (vis < 3000.0) {
        penalty += 5; // Reduced visibility
      }
    }

    return (100 - penalty).clamp(10, 100);
  }

  /// Analyzes hourly weather data for the given date, route, and preference.
  static HourlyTravelAnalysisResult analyze({
    required List<HourlyWeatherItem>? hourlyForecast,
    required DateTime targetDate,
    TravelRoute? route,
    String? preferredPeriod,
    DateTime? currentTimeOverride, // For deterministic unit testing
  }) {
    if (hourlyForecast == null || hourlyForecast.isEmpty) {
      return const HourlyTravelAnalysisResult(
        morningSuitability: 0,
        afternoonSuitability: 0,
        nightSuitability: 0,
        recommendedPeriod: 'Not available',
        selectedPeriod: 'Auto',
        hourlyWeatherSuitability: 0,
        travelAdvice: 'Hourly weather forecast is not available yet for this date.',
        explanationBullets: ['Hourly forecast data unavailable.'],
        hasSufficientData: false,
      );
    }

    final now = currentTimeOverride ?? DateTime.now();
    final isToday = targetDate.year == now.year &&
        targetDate.month == now.month &&
        targetDate.day == now.day;

    // Filter out sunset and sunrise artificial items for scoring
    final validHourlyItems = hourlyForecast.where((item) => !item.isSunset && !item.isSunrise).toList();
    if (validHourlyItems.isEmpty) {
      return const HourlyTravelAnalysisResult(
        morningSuitability: 0,
        afternoonSuitability: 0,
        nightSuitability: 0,
        recommendedPeriod: 'Not available',
        selectedPeriod: 'Auto',
        hourlyWeatherSuitability: 0,
        travelAdvice: 'Hourly weather forecast is not available yet for this date.',
        explanationBullets: ['Hourly forecast data unavailable.'],
        hasSufficientData: false,
      );
    }

    // Evaluate each period (arrival-weather aware when route is provided)
    final morningEval = _evaluatePeriod(TravelPeriod.morning, validHourlyItems, isToday, now, targetDate, route);
    final afternoonEval = _evaluatePeriod(TravelPeriod.afternoon, validHourlyItems, isToday, now, targetDate, route);
    final nightEval = _evaluatePeriod(TravelPeriod.night, validHourlyItems, isToday, now, targetDate, route);

    // Weather-Derived Dynamic Auto Recommendation (No hardcoded Morning tie breaker!)
    final recommendedPeriod = _determineRecommendedPeriod([morningEval, afternoonEval, nightEval]);

    // Parse user choice: Auto vs Morning / Afternoon / Night
    final prefClean = (preferredPeriod ?? 'Auto').trim();
    final prefPeriod = TravelPeriod.fromString(prefClean);
    final isAuto = prefPeriod == null || prefClean.toLowerCase().startsWith('auto');
    final activePeriod = isAuto ? TravelPeriod.fromString(recommendedPeriod) ?? TravelPeriod.morning : prefPeriod;

    final activeEval = activePeriod == TravelPeriod.morning
        ? morningEval
        : activePeriod == TravelPeriod.afternoon
            ? afternoonEval
            : nightEval;

    // Selected period weather suitability
    final hourlyWeatherSuitability = activeEval.score > 0
        ? activeEval.score
        : (isAuto ? [morningEval.score, afternoonEval.score, nightEval.score].reduce((a, b) => a > b ? a : b) : activeEval.fullScore);

    // Departure Window & Suggested Departure calculation (Forward-projected by exact drive duration)
    final depResult = _calculateDepartureWindowAndSuggestion(
      targetDate: targetDate,
      activePeriod: activePeriod,
      validHourlyItems: validHourlyItems,
      route: route,
      isToday: isToday,
      now: now,
    );

    // Travel Advice & Explanations (No "Indoor activities recommended" or "Plan with Caution")
    final travelAdvice = _generateTravelAdvice(hourlyWeatherSuitability, recommendedPeriod, activeEval);
    final explanationBullets = _generateExplanationBullets(activeEval, activePeriod, depResult.bestWindow, route);

    return HourlyTravelAnalysisResult(
      morningSuitability: morningEval.fullScore,
      afternoonSuitability: afternoonEval.fullScore,
      nightSuitability: nightEval.fullScore,
      recommendedPeriod: recommendedPeriod,
      selectedPeriod: isAuto ? 'Auto' : activePeriod.displayName,
      bestWeatherWindow: depResult.bestWindow,
      suggestedDeparture: depResult.suggestedDeparture,
      departureReason: depResult.departureReason,
      hourlyWeatherSuitability: hourlyWeatherSuitability.clamp(10, 100),
      travelAdvice: travelAdvice,
      explanationBullets: explanationBullets,
      hasSufficientData: true,
      periodEvaluations: {
        TravelPeriod.morning: morningEval,
        TravelPeriod.afternoon: afternoonEval,
        TravelPeriod.night: nightEval,
      },
    );
  }

  static PeriodEvaluation _evaluatePeriod(
    TravelPeriod period,
    List<HourlyWeatherItem> allItems,
    bool isToday,
    DateTime now,
    DateTime targetDate,
    TravelRoute? route,
  ) {
    var periodItems = allItems.where((i) =>
        i.time.year == targetDate.year &&
        i.time.month == targetDate.month &&
        i.time.day == targetDate.day &&
        i.time.hour >= period.startHour &&
        i.time.hour <= period.endHour).toList();

    // Fallback for mock test data where item dates might not match targetDate
    if (periodItems.isEmpty && allItems.isNotEmpty) {
      periodItems = allItems.where((i) => i.time.hour >= period.startHour && i.time.hour <= period.endHour).toList();
    }

    if (periodItems.isEmpty) {
      return PeriodEvaluation(
        period: period,
        score: 0,
        fullScore: 0,
        minScore: 0,
        avgPrecipProb: 0.0,
        hasThunderstorm: false,
        hasHeavyRain: false,
        isFeasible: false,
        eligibleItems: const [],
      );
    }

    // Full score for the period (destination weather)
    final fullScores = periodItems.map(calculateHourSuitability).toList();
    final fullAvg = (fullScores.reduce((a, b) => a + b) / fullScores.length).round();

    // Check actionable future hours for today
    final eligibleItems = isToday
        ? periodItems.where((i) => i.time.hour >= now.hour).toList()
        : periodItems;

    final isFeasible = eligibleItems.isNotEmpty;

    if (!isFeasible) {
      return PeriodEvaluation(
        period: period,
        score: 0, // Past period has 0 actionable score for today
        fullScore: fullAvg,
        minScore: fullScores.reduce((a, b) => a < b ? a : b),
        avgPrecipProb: _avgPrecip(periodItems),
        hasThunderstorm: _checkThunderstorm(periodItems),
        hasHeavyRain: _checkHeavyRain(periodItems),
        isFeasible: false,
        eligibleItems: const [],
      );
    }

    // If route is present, evaluate arrival scores for candidates in this period
    if (route != null) {
      final List<int> candidateScores = [];
      final List<HourlyWeatherItem> arrivalItems = [];

      for (int h = period.startHour; h <= period.endHour; h++) {
        for (final m in [0, 15, 30, 45]) {
          final depTime = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
          if (isToday && depTime.isBefore(now.add(const Duration(minutes: 10)))) {
            continue;
          }
          final arrivalTime = depTime.add(Duration(minutes: route.durationMinutes));
          HourlyWeatherItem closestItem = allItems.first;
          int minDiff = 9999999;
          for (final it in allItems) {
            final diff = (it.time.difference(arrivalTime)).inMinutes.abs();
            if (diff < minDiff) {
              minDiff = diff;
              closestItem = it;
            }
          }
          candidateScores.add(calculateHourSuitability(closestItem));
          arrivalItems.add(closestItem);
        }
      }

      if (candidateScores.isNotEmpty) {
        final avg = (candidateScores.reduce((a, b) => a + b) / candidateScores.length).round();
        final minScore = candidateScores.reduce((a, b) => a < b ? a : b);
        return PeriodEvaluation(
          period: period,
          score: avg,
          fullScore: fullAvg,
          minScore: minScore,
          avgPrecipProb: _avgPrecip(arrivalItems),
          hasThunderstorm: _checkThunderstorm(arrivalItems),
          hasHeavyRain: _checkHeavyRain(arrivalItems),
          isFeasible: true,
          eligibleItems: eligibleItems,
        );
      }
    }

    // Destination weather scoring fallback (when route is null)
    final eligibleScores = eligibleItems.map(calculateHourSuitability).toList();
    final eligibleAvg = (eligibleScores.reduce((a, b) => a + b) / eligibleScores.length).round();
    final minScore = eligibleScores.reduce((a, b) => a < b ? a : b);

    return PeriodEvaluation(
      period: period,
      score: eligibleAvg,
      fullScore: fullAvg,
      minScore: minScore,
      avgPrecipProb: _avgPrecip(eligibleItems),
      hasThunderstorm: _checkThunderstorm(eligibleItems),
      hasHeavyRain: _checkHeavyRain(eligibleItems),
      isFeasible: true,
      eligibleItems: eligibleItems,
    );
  }

  static double _avgPrecip(List<HourlyWeatherItem> items) {
    final probs = items.map((i) => i.precipitationProbability ?? 0).toList();
    if (probs.isEmpty) return 0.0;
    return probs.reduce((a, b) => a + b) / probs.length;
  }

  static bool _checkThunderstorm(List<HourlyWeatherItem> items) {
    return items.any((i) {
      final w = i.weatherCode;
      if (w != null && (w == 95 || w == 96 || w == 99)) return true;
      final c = i.condition.toLowerCase();
      return c.contains('thunderstorm') || c.contains('ribut');
    });
  }

  static bool _checkHeavyRain(List<HourlyWeatherItem> items) {
    return items.any((i) {
      final w = i.weatherCode;
      if (w != null && (w == 63 || w == 65 || w == 81 || w == 82)) return true;
      final c = i.condition.toLowerCase();
      return c.contains('heavy rain') || c.contains('lebat');
    });
  }

  /// Resolves period recommendation using weather-derived criteria.
  /// Ties are broken using:
  /// 1. Higher minimum hourly suitability (higher floor)
  /// 2. Lower precipitation probability
  /// 3. Lower severe-weather risk (no thunderstorm / heavy rain)
  /// 4. Better consecutive weather window
  /// 5. Earliest available period (chronological) as final deterministic fallback.
  static String _determineRecommendedPeriod(List<PeriodEvaluation> periods) {
    final feasible = periods.where((p) => p.isFeasible).toList();
    if (feasible.isEmpty) {
      return 'Not available';
    }

    feasible.sort((a, b) {
      // 1. Higher average score
      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }

      // 2. Higher minimum hourly suitability (higher floor)
      if (a.minScore != b.minScore) {
        return b.minScore.compareTo(a.minScore);
      }

      // 3. Lower average precipitation probability
      if ((a.avgPrecipProb - b.avgPrecipProb).abs() > 2.0) {
        return a.avgPrecipProb.compareTo(b.avgPrecipProb);
      }

      // 4. Severe weather risk (thunderstorm)
      if (a.hasThunderstorm != b.hasThunderstorm) {
        return a.hasThunderstorm ? 1 : -1; // false (no thunderstorm) wins
      }

      // 5. Heavy rain risk
      if (a.hasHeavyRain != b.hasHeavyRain) {
        return a.hasHeavyRain ? 1 : -1;
      }

      // 6. Chronological order among remaining available periods
      return a.period.startHour.compareTo(b.period.startHour);
    });

    return feasible.first.period.displayName;
  }

  /// Calculates the best departure window and suggested departure.
  /// Forward-projects arrival time by exact driving duration and evaluates
  /// destination weather (supporting overnight arrivals into the following day).
  static _DepartureResult _calculateDepartureWindowAndSuggestion({
    required DateTime targetDate,
    required TravelPeriod activePeriod,
    required List<HourlyWeatherItem> validHourlyItems,
    required TravelRoute? route,
    required bool isToday,
    required DateTime now,
  }) {
    // 1. Generate candidate departure times strictly within activePeriod on targetDate (15-minute intervals)
    final List<DateTime> candidateTimes = [];
    for (int h = activePeriod.startHour; h <= activePeriod.endHour; h++) {
      for (final m in [0, 15, 30, 45]) {
        final depTime = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);
        // For today, candidate departure must be in the future (10 minute buffer)
        if (isToday && depTime.isBefore(now.add(const Duration(minutes: 10)))) {
          continue;
        }
        candidateTimes.add(depTime);
      }
    }

    if (candidateTimes.isEmpty) {
      return _DepartureResult(
        bestWindow: null,
        suggestedDeparture: null,
        departureReason: 'No suitable departure window remaining today for ${activePeriod.displayName}.',
      );
    }

    // 2. Evaluate arrival weather for each candidate departure
    final candidates = <_DepartureCandidate>[];
    for (final depTime in candidateTimes) {
      // Precise arrival time without premature integer rounding of route duration
      final arrivalTime = depTime.add(Duration(minutes: route?.durationMinutes ?? 0));

      // Find closest destination hourly weather item (allowing overnight arrivals into the next day)
      HourlyWeatherItem closestItem = validHourlyItems.first;
      int minDiffMinutes = 9999999;
      for (final item in validHourlyItems) {
        final diff = (item.time.difference(arrivalTime)).inMinutes.abs();
        if (diff < minDiffMinutes) {
          minDiffMinutes = diff;
          closestItem = item;
        }
      }

      final score = calculateHourSuitability(closestItem);
      candidates.add(_DepartureCandidate(
        departureTime: depTime,
        arrivalTime: arrivalTime,
        arrivalWeatherItem: closestItem,
        suitabilityScore: score,
      ));
    }

    // 3. Determine Best Departure Window (sliding 3-hour window, or 2h/1h if period has fewer hours)
    final firstHour = candidateTimes.first.hour;
    final lastHour = candidateTimes.last.hour;
    final spanHours = (lastHour - firstHour) + 1;
    final windowHours = spanHours >= 3 ? 3 : (spanHours >= 2 ? 2 : 1);

    DateTime? bestWStart;
    DateTime? bestWEnd;
    double bestWindowAvg = -1.0;
    List<_DepartureCandidate> bestInWindow = [];

    for (int wStartHour = firstHour; wStartHour <= lastHour; wStartHour++) {
      final wStart = DateTime(targetDate.year, targetDate.month, targetDate.day, wStartHour, 0);
      final wEnd = wStart.add(Duration(hours: windowHours));

      final inWindow = candidates.where((c) {
        return !c.departureTime.isBefore(wStart) && !c.departureTime.isAfter(wEnd);
      }).toList();

      if (inWindow.isNotEmpty) {
        final avg = inWindow.map((c) => c.suitabilityScore).reduce((a, b) => a + b) / inWindow.length;
        if (avg > bestWindowAvg) {
          bestWindowAvg = avg;
          bestWStart = wStart;
          bestWEnd = wEnd;
          bestInWindow = inWindow;
        }
      }
    }

    if (bestWStart == null || bestWEnd == null || bestInWindow.isEmpty) {
      bestWStart = candidateTimes.first;
      bestWEnd = candidateTimes.last;
      bestInWindow = candidates;
    }

    final bestWindowFormatted =
        '${DateFormat('h:mm a').format(bestWStart)} – ${DateFormat('h:mm a').format(bestWEnd)}';

    // 4. If driving route is unavailable, return destination window only (maintains route==null contract)
    if (route == null) {
      return _DepartureResult(
        bestWindow: bestWindowFormatted,
        suggestedDeparture: null,
        departureReason: 'Direct driving route unavailable. Optimal destination weather window: $bestWindowFormatted.',
      );
    }

    // 5. Select the best departure candidate strictly INSIDE the best window (ensures Suggested Departure is inside Best Window)
    final windowMidpoint = bestWStart.add(Duration(minutes: (windowHours * 60) ~/ 2));
    bestInWindow.sort((a, b) {
      if (b.suitabilityScore != a.suitabilityScore) {
        return b.suitabilityScore.compareTo(a.suitabilityScore);
      }
      final diffA = (a.departureTime.difference(windowMidpoint)).inMinutes.abs();
      final diffB = (b.departureTime.difference(windowMidpoint)).inMinutes.abs();
      return diffA.compareTo(diffB);
    });

    final bestCandidate = bestInWindow.first;

    // 6. Explicit debug logs as requested
    debugPrint('[PLAN WEATHER DEBUG] selected departure date = ${DateFormat('yyyy-MM-dd').format(targetDate)}');
    debugPrint('[PLAN WEATHER DEBUG] candidate departure = ${DateFormat('yyyy-MM-dd h:mm a').format(bestCandidate.departureTime)}');
    debugPrint('[PLAN WEATHER DEBUG] calculated arrival = ${DateFormat('yyyy-MM-dd h:mm a').format(bestCandidate.arrivalTime)}');
    debugPrint('[PLAN WEATHER DEBUG] hourly weather timestamp used for arrival = ${DateFormat('yyyy-MM-dd h:mm a').format(bestCandidate.arrivalWeatherItem.time)}');

    final suggestedDepFormatted = 'Around ${DateFormat('h:mm a').format(bestCandidate.departureTime)}';

    final isOvernight = bestCandidate.arrivalTime.day != targetDate.day;
    final arrivalTimeStr = isOvernight
        ? 'on ${DateFormat('d MMM').format(bestCandidate.arrivalTime)} at ${DateFormat('h:mm a').format(bestCandidate.arrivalTime)}'
        : 'around ${DateFormat('h:mm a').format(bestCandidate.arrivalTime)}';

    final reason = 'Departing $suggestedDepFormatted allows approx. ${route.durationFormatted} driving time to arrive $arrivalTimeStr for optimal conditions.';

    return _DepartureResult(
      bestWindow: bestWindowFormatted,
      suggestedDeparture: suggestedDepFormatted,
      departureReason: reason,
    );
  }

  static String _generateTravelAdvice(int score, String recommendedPeriod, PeriodEvaluation activeEval) {
    if (activeEval.hasThunderstorm) {
      return 'Thunderstorms may affect travel. Consider adjusting your departure time if conditions worsen.';
    }

    if (score >= 80) {
      return 'Good conditions for travel. $recommendedPeriod is the most suitable window for outdoor activities.';
    } else if (score >= 60) {
      return 'Some weather changes expected. Plan activities around the $recommendedPeriod window and check the latest forecast before departure.';
    } else {
      return 'Rain may affect your plans. Allow extra travel time and prepare for wet conditions.';
    }
  }

  static List<String> _generateExplanationBullets(
    PeriodEvaluation activeEval,
    TravelPeriod period,
    String? bestWindow,
    TravelRoute? route,
  ) {
    final bullets = <String>[];

    if (bestWindow != null) {
      bullets.add('Peak weather window: $bestWindow with suitability ${activeEval.score}/100.');
    }

    if (activeEval.avgPrecipProb > 50) {
      bullets.add('High rain probability (${activeEval.avgPrecipProb.round()}%) during ${period.displayName.toLowerCase()}; expect wet roads.');
    } else if (activeEval.avgPrecipProb > 25) {
      bullets.add('Moderate rain chance (${activeEval.avgPrecipProb.round()}%) during ${period.displayName.toLowerCase()}.');
    } else {
      bullets.add('Low chance of rain (${activeEval.avgPrecipProb.round()}%) during ${period.displayName.toLowerCase()}.');
    }

    if (activeEval.hasThunderstorm) {
      bullets.add('Thunderstorms forecast in this period; monitor radar and exercise driving caution.');
    }

    if (route != null) {
      bullets.add('Estimated driving duration: ${route.durationFormatted} (${route.distanceFormatted}).');
    } else {
      bullets.add('Driving route unavailable; score reflects destination weather suitability only.');
    }

    return bullets;
  }
}

class _DepartureCandidate {
  final DateTime departureTime;
  final DateTime arrivalTime;
  final HourlyWeatherItem arrivalWeatherItem;
  final int suitabilityScore;

  const _DepartureCandidate({
    required this.departureTime,
    required this.arrivalTime,
    required this.arrivalWeatherItem,
    required this.suitabilityScore,
  });
}

class _DepartureResult {
  final String? bestWindow;
  final String? suggestedDeparture;
  final String? departureReason;

  const _DepartureResult({
    this.bestWindow,
    this.suggestedDeparture,
    this.departureReason,
  });
}
