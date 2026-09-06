import 'package:intl/intl.dart';
import '../models/planned_trip.dart';
import '../models/trip_stop.dart';
import '../models/weather_info.dart';
import '../models/itinerary_analysis.dart';
import '../utils/hourly_travel_analyzer.dart';
import 'route_service.dart';
import 'weather_service.dart';

class ItineraryAnalyzer {
  static const int preparationBufferMinutes = 5;
  static const int conflictMinorMinutes = 5;
  static const int conflictMajorMinutes = 15;

  final RouteService _routeService;
  final WeatherService _weatherService;

  ItineraryAnalyzer({
    RouteService? routeService,
    WeatherService? weatherService,
  })  : _routeService = routeService ?? RouteService(),
        _weatherService = weatherService ?? WeatherService();

  Future<ItineraryAnalysis> analyzeTrip({
    required PlannedTrip trip,
    required List<TripStop> stops,
    bool forceRefresh = false,
    DateTime? currentTimeOverride,
    Map<DateTime, ({String name, double lat, double lng})>? dayStartOverrides,
  }) async {
    final now = currentTimeOverride ?? DateTime.now();
    final tripDays = _generateTripDays(trip);
    final dayAnalyses = <ItineraryDayAnalysis>[];

    String lastDayEndName = trip.originName.isNotEmpty ? trip.originName : 'Current Location';
    double lastDayEndLat = trip.originLatitude ?? 0.0;
    double lastDayEndLng = trip.originLongitude ?? 0.0;

    for (int dayIdx = 0; dayIdx < tripDays.length; dayIdx++) {
      final dayDate = tripDays[dayIdx];
      final dayNumber = dayIdx + 1;

      final dayStops = stops.where((s) {
        return s.visitDate.year == dayDate.year &&
            s.visitDate.month == dayDate.month &&
            s.visitDate.day == dayDate.day;
      }).toList();

      dayStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

      final stopAnalyses = <ItineraryStopAnalysis>[];
      final segmentAnalyses = <ItinerarySegmentAnalysis>[];

      ({String name, double lat, double lng})? dayOverride;
      if (dayStartOverrides != null) {
        for (final entry in dayStartOverrides.entries) {
          if (entry.key.year == dayDate.year &&
              entry.key.month == dayDate.month &&
              entry.key.day == dayDate.day) {
            dayOverride = entry.value;
            break;
          }
        }
      }

      String segmentOriginName;
      double segmentOriginLat;
      double segmentOriginLng;

      if (dayOverride != null) {
        segmentOriginName = dayOverride.name;
        segmentOriginLat = dayOverride.lat;
        segmentOriginLng = dayOverride.lng;
      } else if (dayIdx == 0) {
        segmentOriginName = trip.originName.isNotEmpty ? trip.originName : 'Current Location';
        segmentOriginLat = trip.originLatitude ?? 0.0;
        segmentOriginLng = trip.originLongitude ?? 0.0;
      } else {
        segmentOriginName = lastDayEndName;
        segmentOriginLat = lastDayEndLat;
        segmentOriginLng = lastDayEndLng;
      }

      DateTime? previousStopDeparture;

      for (int stopIdx = 0; stopIdx < dayStops.length; stopIdx++) {
        final stop = dayStops[stopIdx];

        final segment = await _analyzeSegment(
          fromName: segmentOriginName,
          fromLat: segmentOriginLat,
          fromLng: segmentOriginLng,
          toName: stop.locationName,
          toLat: stop.latitude,
          toLng: stop.longitude,
          forceRefresh: forceRefresh,
        );
        segmentAnalyses.add(segment);

        WeatherInfo? weather;
        if (stop.latitude != 0.0 && stop.longitude != 0.0) {
          try {
            weather = await _weatherService.fetchWeatherForCoordinates(
              latitude: stop.latitude,
              longitude: stop.longitude,
              targetDate: stop.visitDate,
              locationId: stop.effectiveMetLocationId,
              forceRefresh: forceRefresh,
            );
          } catch (_) {
            weather = null;
          }
        }

        final stopAnalysis = _analyzeStopTiming(
          stop: stop,
          segment: segment,
          weather: weather,
          previousDeparture: previousStopDeparture,
          now: now,
          isFirstStopOfDay: stopIdx == 0,
        );

        stopAnalyses.add(stopAnalysis);

        previousStopDeparture = _resolveStopDeparture(stop, stopAnalysis);
        segmentOriginName = stop.locationName;
        segmentOriginLat = stop.latitude;
        segmentOriginLng = stop.longitude;
      }

      if (dayStops.isNotEmpty) {
        final lastStop = dayStops.last;
        lastDayEndName = lastStop.locationName;
        lastDayEndLat = lastStop.latitude;
        lastDayEndLng = lastStop.longitude;
      } else if (dayOverride != null) {
        lastDayEndName = dayOverride.name;
        lastDayEndLat = dayOverride.lat;
        lastDayEndLng = dayOverride.lng;
      }

      dayAnalyses.add(ItineraryDayAnalysis(
        dayIndex: dayNumber,
        dayDate: dayDate,
        stops: stopAnalyses,
        segments: segmentAnalyses,
      ));
    }

    return ItineraryAnalysis(
      tripId: trip.id ?? 0,
      days: dayAnalyses,
      analyzedAt: now,
    );
  }

  DateTime? _resolveStopDeparture(TripStop stop, ItineraryStopAnalysis analysis) {
    final depTime = stop.plannedDepartureTime;
    if (depTime != null && depTime.isNotEmpty) {
      final parts = depTime.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null) {
          return DateTime(
            stop.visitDate.year,
            stop.visitDate.month,
            stop.visitDate.day,
            h,
            m,
          );
        }
      }
    }
    return null;
  }

  List<DateTime> _generateTripDays(PlannedTrip trip) {
    final start = DateTime(
      trip.effectiveStartDate.year,
      trip.effectiveStartDate.month,
      trip.effectiveStartDate.day,
    );
    final end = DateTime(
      trip.effectiveEndDate.year,
      trip.effectiveEndDate.month,
      trip.effectiveEndDate.day,
    );

    final days = <DateTime>[];
    DateTime cur = start;
    while (!cur.isAfter(end)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days.isNotEmpty ? days : [start];
  }

  Future<ItinerarySegmentAnalysis> _analyzeSegment({
    required String fromName,
    required double fromLat,
    required double fromLng,
    required String toName,
    required double toLat,
    required double toLng,
    required bool forceRefresh,
  }) async {
    if (fromLat == 0.0 || fromLng == 0.0 || toLat == 0.0 || toLng == 0.0) {
      return ItinerarySegmentAnalysis(
        fromName: fromName,
        fromLatitude: fromLat,
        fromLongitude: fromLng,
        toName: toName,
        toLatitude: toLat,
        toLongitude: toLng,
        isRouteAvailable: false,
        errorMessage: 'Coordinates missing for route calculation.',
      );
    }

    try {
      final res = await _routeService.calculateRouteDetails(
        originName: fromName,
        originLat: fromLat,
        originLng: fromLng,
        destName: toName,
        destLat: toLat,
        destLng: toLng,
        forceRefresh: forceRefresh,
      );

      if (res.isSuccess && res.route != null) {
        return ItinerarySegmentAnalysis(
          fromName: fromName,
          fromLatitude: fromLat,
          fromLongitude: fromLng,
          toName: toName,
          toLatitude: toLat,
          toLongitude: toLng,
          route: res.route,
          distanceKm: res.route!.distanceKm,
          durationMinutes: res.route!.durationMinutes,
          isRouteAvailable: true,
        );
      }

      return ItinerarySegmentAnalysis(
        fromName: fromName,
        fromLatitude: fromLat,
        fromLongitude: fromLng,
        toName: toName,
        toLatitude: toLat,
        toLongitude: toLng,
        isRouteAvailable: false,
        errorMessage: res.errorMessage ?? 'Route unavailable',
      );
    } catch (e) {
      return ItinerarySegmentAnalysis(
        fromName: fromName,
        fromLatitude: fromLat,
        fromLongitude: fromLng,
        toName: toName,
        toLatitude: toLat,
        toLongitude: toLng,
        isRouteAvailable: false,
        errorMessage: e.toString(),
      );
    }
  }

  ItineraryStopAnalysis _analyzeStopTiming({
    required TripStop stop,
    required ItinerarySegmentAnalysis segment,
    required WeatherInfo? weather,
    required DateTime? previousDeparture,
    required DateTime now,
    required bool isFirstStopOfDay,
  }) {
    final isToday = stop.visitDate.year == now.year &&
        stop.visitDate.month == now.month &&
        stop.visitDate.day == now.day;

    final driveMinutes = segment.isRouteAvailable ? (segment.durationMinutes ?? 0) : 0;

    DateTime earliestArrival;
    if (isFirstStopOfDay) {
      if (isToday) {
        earliestArrival = now.add(Duration(minutes: driveMinutes + preparationBufferMinutes));
      } else {
        earliestArrival = DateTime(stop.visitDate.year, stop.visitDate.month, stop.visitDate.day, 6, 0);
      }
    } else if (previousDeparture != null) {
      earliestArrival = previousDeparture.add(Duration(minutes: driveMinutes));
    } else {
      earliestArrival = DateTime(stop.visitDate.year, stop.visitDate.month, stop.visitDate.day, 6, 0);
    }

    if (stop.isExactTime) {
      return _analyzeExactStop(
        stop: stop,
        segment: segment,
        weather: weather,
        previousDeparture: previousDeparture,
        driveMinutes: driveMinutes,
        earliestArrival: earliestArrival,
        isFirstStopOfDay: isFirstStopOfDay,
        isToday: isToday,
        now: now,
      );
    } else {
      return _analyzeFlexibleStop(
        stop: stop,
        segment: segment,
        weather: weather,
        previousDeparture: previousDeparture,
        driveMinutes: driveMinutes,
        earliestArrival: earliestArrival,
        isToday: isToday,
        now: now,
        isFirstStopOfDay: isFirstStopOfDay,
      );
    }
  }

  ItineraryStopAnalysis _analyzeExactStop({
    required TripStop stop,
    required ItinerarySegmentAnalysis segment,
    required WeatherInfo? weather,
    required DateTime? previousDeparture,
    required int driveMinutes,
    required DateTime earliestArrival,
    required bool isFirstStopOfDay,
    required bool isToday,
    required DateTime now,
  }) {
    DateTime? plannedArrival;
    final tod = stop.arrivalTimeOfDay;
    if (tod != null) {
      plannedArrival = DateTime(
        stop.visitDate.year,
        stop.visitDate.month,
        stop.visitDate.day,
        tod.hour,
        tod.minute,
      );
    }

    DateTime? suggestedDeparture;
    if (plannedArrival != null && segment.isRouteAvailable) {
      suggestedDeparture = plannedArrival.subtract(
        Duration(minutes: driveMinutes + preparationBufferMinutes),
      );
    }

    DateTime? estimatedArrival;
    if (suggestedDeparture != null && segment.isRouteAvailable) {
      estimatedArrival = suggestedDeparture.add(Duration(minutes: driveMinutes));
    } else if (previousDeparture != null && segment.isRouteAvailable) {
      estimatedArrival = previousDeparture.add(Duration(minutes: driveMinutes));
    }

    bool hasConflict = false;
    String? conflictText;
    if (previousDeparture != null && plannedArrival != null && segment.isRouteAvailable) {
      final conflictArrival = previousDeparture.add(Duration(minutes: driveMinutes));
      final diffMinutes = conflictArrival.difference(plannedArrival).inMinutes;
      if (diffMinutes > conflictMajorMinutes) {
        hasConflict = true;
        final formattedEstimated = DateFormat('h:mm a').format(conflictArrival);
        conflictText = 'You may arrive around $formattedEstimated. Consider leaving earlier or adjusting this stop.';
      } else if (diffMinutes > conflictMinorMinutes) {
        hasConflict = true;
        final formattedEstimated = DateFormat('h:mm a').format(conflictArrival);
        conflictText = 'Estimated arrival is around $formattedEstimated.';
      }
    }

    HourlyWeatherItem? weatherAtArrival;
    int? suitability;
    if (weather != null && plannedArrival != null) {
      weatherAtArrival = _findWeatherItem(weather.hourlyForecast, plannedArrival);
      if (weatherAtArrival != null) {
        suitability = HourlyTravelAnalyzer.calculateHourSuitability(weatherAtArrival);
      }
    }

    return ItineraryStopAnalysis(
      stop: stop,
      weather: weather,
      weatherAtArrival: weatherAtArrival,
      weatherSuitability: suitability,
      isWeatherAvailable: weather != null,
      routeFromPrevious: segment,
      plannedArrivalDateTime: plannedArrival,
      recommendedArrivalDateTime: plannedArrival,
      suggestedDepartureDateTime: suggestedDeparture,
      estimatedArrivalDateTime: estimatedArrival,
      hasTimingConflict: hasConflict,
      timingConflictText: conflictText,
    );
  }

  ItineraryStopAnalysis _analyzeFlexibleStop({
    required TripStop stop,
    required ItinerarySegmentAnalysis segment,
    required WeatherInfo? weather,
    required DateTime? previousDeparture,
    required int driveMinutes,
    required DateTime earliestArrival,
    required bool isToday,
    required DateTime now,
    required bool isFirstStopOfDay,
  }) {
    final periodHours = _candidateHoursForPeriod(stop.preferredPeriod);

    final feasibleCandidates = <_CandidateArrival>[];

    for (final hour in periodHours) {
      final candidateArrival = DateTime(
        stop.visitDate.year,
        stop.visitDate.month,
        stop.visitDate.day,
        hour,
        0,
      );

      final candidateDep = candidateArrival.subtract(
        Duration(minutes: driveMinutes + preparationBufferMinutes),
      );

      if (isToday) {
        if (!candidateArrival.isAfter(now)) continue;
        if (candidateDep.isBefore(now.subtract(const Duration(minutes: 5)))) continue;
      }

      if (candidateArrival.isBefore(earliestArrival)) continue;

      int score = 70;
      double avgPrecip = 0.0;

      if (weather != null && weather.hourlyForecast != null) {
        final arrivalItem = _findWeatherItem(weather.hourlyForecast, candidateArrival);
        if (arrivalItem != null) {
          score = HourlyTravelAnalyzer.calculateHourSuitability(arrivalItem);
          if (arrivalItem.precipitationProbability != null) {
            avgPrecip = arrivalItem.precipitationProbability!.toDouble();
          }
        }
      }

      feasibleCandidates.add(_CandidateArrival(
        arrival: candidateArrival,
        score: score,
        precipProb: avgPrecip,
      ));
    }

    DateTime? recommendedArrival;
    int? suitability;
    bool noFeasibleTime = false;

    if (feasibleCandidates.isNotEmpty) {
      feasibleCandidates.sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        final precipCmp = a.precipProb.compareTo(b.precipProb);
        if (precipCmp != 0) return precipCmp;
        return a.arrival.compareTo(b.arrival);
      });

      recommendedArrival = feasibleCandidates.first.arrival;
      suitability = feasibleCandidates.first.score;
    } else if (isToday) {
      noFeasibleTime = true;
      recommendedArrival = earliestArrival;
    } else {
      final defaultHour = _defaultHourForPeriod(stop.preferredPeriod);
      final fallback = DateTime(
        stop.visitDate.year,
        stop.visitDate.month,
        stop.visitDate.day,
        defaultHour,
        0,
      );
      recommendedArrival = fallback.isBefore(earliestArrival) ? earliestArrival : fallback;
    }

    DateTime? suggestedDeparture;
    if (segment.isRouteAvailable) {
      suggestedDeparture = recommendedArrival.subtract(
        Duration(minutes: driveMinutes + preparationBufferMinutes),
      );
    }

    DateTime? estimatedArrival;
    if (suggestedDeparture != null && segment.isRouteAvailable) {
      estimatedArrival = suggestedDeparture.add(Duration(minutes: driveMinutes));
    } else if (previousDeparture != null && segment.isRouteAvailable) {
      estimatedArrival = previousDeparture.add(Duration(minutes: driveMinutes));
    }

    HourlyWeatherItem? weatherAtArrival;
    if (weather != null) {
      weatherAtArrival = _findWeatherItem(weather.hourlyForecast, recommendedArrival);
      if (weatherAtArrival != null && suitability == null) {
        suitability = HourlyTravelAnalyzer.calculateHourSuitability(weatherAtArrival);
      }
    }

    return ItineraryStopAnalysis(
      stop: stop,
      weather: weather,
      weatherAtArrival: weatherAtArrival,
      weatherSuitability: suitability,
      isWeatherAvailable: weather != null,
      routeFromPrevious: segment,
      recommendedArrivalDateTime: recommendedArrival,
      suggestedDepartureDateTime: suggestedDeparture,
      estimatedArrivalDateTime: estimatedArrival,
      noFeasibleTimeToday: noFeasibleTime,
    );
  }

  List<int> _candidateHoursForPeriod(String? preferredPeriod) {
    final lower = (preferredPeriod ?? 'morning').trim().toLowerCase();
    if (lower == 'auto') {
      return List<int>.generate(18, (i) => i + 6);
    }
    if (lower.startsWith('afternoon')) {
      return [12, 13, 14, 15, 16, 17];
    }
    if (lower.startsWith('night')) {
      return [18, 19, 20, 21, 22, 23];
    }
    return [6, 7, 8, 9, 10, 11];
  }

  int _defaultHourForPeriod(String? preferredPeriod) {
    final lower = (preferredPeriod ?? 'morning').trim().toLowerCase();
    if (lower.startsWith('afternoon')) return 14;
    if (lower.startsWith('night')) return 19;
    return 9;
  }

  HourlyWeatherItem? _findWeatherItem(List<HourlyWeatherItem>? hourlyForecast, DateTime target) {
    if (hourlyForecast == null || hourlyForecast.isEmpty) return null;
    for (final item in hourlyForecast) {
      if (item.time.year == target.year &&
          item.time.month == target.month &&
          item.time.day == target.day &&
          item.time.hour == target.hour) {
        return item;
      }
    }
    return null;
  }
}

class _CandidateArrival {
  final DateTime arrival;
  final int score;
  final double precipProb;

  const _CandidateArrival({
    required this.arrival,
    required this.score,
    required this.precipProb,
  });
}
