import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';

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

class PeriodEvaluation {
  final TravelPeriod period;
  final int score;
  final int fullScore;
  final int minScore;
  final double avgPrecipProb;
  final bool hasThunderstorm;
  final bool hasHeavyRain;
  final bool isFeasible;
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

class HourlyTravelAnalysisResult {
  final int morningSuitability;
  final int afternoonSuitability;
  final int nightSuitability;
  final String recommendedPeriod;
  final String selectedPeriod;
  final String? bestWeatherWindow;
  final String? suggestedDeparture;
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

class HourlyTravelAnalyzer {
  HourlyTravelAnalyzer._();

  static int calculateHourSuitability(HourlyWeatherItem item) {
    int penalty = 0;

    final wCode = item.weatherCode;
    if (wCode != null) {
      if (wCode == 0 || wCode == 1) {

        penalty += 0;
      } else if (wCode == 2) {

        penalty += 5;
      } else if (wCode == 3) {

        penalty += 12;
      } else if (wCode == 45 || wCode == 48) {

        penalty += 15;
      } else if (wCode == 51 || wCode == 53 || wCode == 55) {

        penalty += 28;
      } else if (wCode == 61 || wCode == 80) {

        penalty += 40;
      } else if (wCode == 63 || wCode == 65 || wCode == 81 || wCode == 82) {

        penalty += 60;
      } else if (wCode == 95) {

        penalty += 75;
      } else if (wCode == 96 || wCode == 99) {

        penalty += 85;
      } else {
        penalty += 10;
      }
    } else {

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

    final feels = item.apparentTemperature ?? item.temperature;
    if (feels != null) {
      if (feels > 35.0) {
        penalty += 8;
      } else if (feels > 32.0) {
        penalty += 3;
      } else if (feels < 16.0) {
        penalty += 5;
      }
    }

    final h = item.time.hour;
    if (h >= 8 && h <= 16 && item.uvIndex != null) {
      final uv = item.uvIndex!;
      if (uv > 10.0) {
        penalty += 5;
      } else if (uv >= 8.0) {
        penalty += 3;
      }
    }

    final vis = item.visibility;
    if (vis != null) {
      if (vis < 1000.0) {
        penalty += 10;
      } else if (vis < 3000.0) {
        penalty += 5;
      }
    }

    return (100 - penalty).clamp(10, 100);
  }

  static HourlyTravelAnalysisResult analyze({
    required List<HourlyWeatherItem>? hourlyForecast,
    required DateTime targetDate,
    TravelRoute? route,
    String? preferredPeriod,
    DateTime? currentTimeOverride,
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

    final morningEval = _evaluatePeriod(TravelPeriod.morning, validHourlyItems, isToday, now, targetDate, route);
    final afternoonEval = _evaluatePeriod(TravelPeriod.afternoon, validHourlyItems, isToday, now, targetDate, route);
    final nightEval = _evaluatePeriod(TravelPeriod.night, validHourlyItems, isToday, now, targetDate, route);

    final recommendedPeriod = _determineRecommendedPeriod([morningEval, afternoonEval, nightEval]);

    final prefClean = (preferredPeriod ?? 'Auto').trim();
    final prefPeriod = TravelPeriod.fromString(prefClean);
    final isAuto = prefPeriod == null || prefClean.toLowerCase().startsWith('auto');
    final activePeriod = isAuto ? TravelPeriod.fromString(recommendedPeriod) ?? TravelPeriod.morning : prefPeriod;

    final activeEval = activePeriod == TravelPeriod.morning
        ? morningEval
        : activePeriod == TravelPeriod.afternoon
            ? afternoonEval
            : nightEval;

    final hourlyWeatherSuitability = activeEval.score > 0
        ? activeEval.score
        : (isAuto ? [morningEval.score, afternoonEval.score, nightEval.score].reduce((a, b) => a > b ? a : b) : activeEval.fullScore);

    final depResult = _calculateDepartureWindowAndSuggestion(
      targetDate: targetDate,
      activePeriod: activePeriod,
      validHourlyItems: validHourlyItems,
      route: route,
      isToday: isToday,
      now: now,
    );

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

    final fullScores = periodItems.map(calculateHourSuitability).toList();
    final fullAvg = (fullScores.reduce((a, b) => a + b) / fullScores.length).round();

    final eligibleItems = isToday
        ? periodItems.where((i) => i.time.hour >= now.hour).toList()
        : periodItems;

    final isFeasible = eligibleItems.isNotEmpty;

    if (!isFeasible) {
      return PeriodEvaluation(
        period: period,
        score: 0,
        fullScore: fullAvg,
        minScore: fullScores.reduce((a, b) => a < b ? a : b),
        avgPrecipProb: _avgPrecip(periodItems),
        hasThunderstorm: _checkThunderstorm(periodItems),
        hasHeavyRain: _checkHeavyRain(periodItems),
        isFeasible: false,
        eligibleItems: const [],
      );
    }

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

  static String _determineRecommendedPeriod(List<PeriodEvaluation> periods) {
    final feasible = periods.where((p) => p.isFeasible).toList();
    if (feasible.isEmpty) {
      return 'Not available';
    }

    feasible.sort((a, b) {

      if (a.score != b.score) {
        return b.score.compareTo(a.score);
      }

      if (a.minScore != b.minScore) {
        return b.minScore.compareTo(a.minScore);
      }

      if ((a.avgPrecipProb - b.avgPrecipProb).abs() > 2.0) {
        return a.avgPrecipProb.compareTo(b.avgPrecipProb);
      }

      if (a.hasThunderstorm != b.hasThunderstorm) {
        return a.hasThunderstorm ? 1 : -1;
      }

      if (a.hasHeavyRain != b.hasHeavyRain) {
        return a.hasHeavyRain ? 1 : -1;
      }

      return a.period.startHour.compareTo(b.period.startHour);
    });

    return feasible.first.period.displayName;
  }

  static _DepartureResult _calculateDepartureWindowAndSuggestion({
    required DateTime targetDate,
    required TravelPeriod activePeriod,
    required List<HourlyWeatherItem> validHourlyItems,
    required TravelRoute? route,
    required bool isToday,
    required DateTime now,
  }) {

    final List<DateTime> candidateTimes = [];
    for (int h = activePeriod.startHour; h <= activePeriod.endHour; h++) {
      for (final m in [0, 15, 30, 45]) {
        final depTime = DateTime(targetDate.year, targetDate.month, targetDate.day, h, m);

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

    final candidates = <_DepartureCandidate>[];
    for (final depTime in candidateTimes) {

      final arrivalTime = depTime.add(Duration(minutes: route?.durationMinutes ?? 0));

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

    if (route == null) {
      return _DepartureResult(
        bestWindow: bestWindowFormatted,
        suggestedDeparture: null,
        departureReason: 'Direct driving route unavailable. Optimal destination weather window: $bestWindowFormatted.',
      );
    }

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
