import 'package:intl/intl.dart';
import 'trip_stop.dart';
import 'weather_info.dart';
import 'travel_route.dart';

class ItinerarySegmentAnalysis {
  final String fromName;
  final double fromLatitude;
  final double fromLongitude;
  final String toName;
  final double toLatitude;
  final double toLongitude;
  final TravelRoute? route;
  final double? distanceKm;
  final int? durationMinutes;
  final bool isRouteAvailable;
  final bool isLoading;
  final String? errorMessage;

  const ItinerarySegmentAnalysis({
    required this.fromName,
    required this.fromLatitude,
    required this.fromLongitude,
    required this.toName,
    required this.toLatitude,
    required this.toLongitude,
    this.route,
    this.distanceKm,
    this.durationMinutes,
    required this.isRouteAvailable,
    this.isLoading = false,
    this.errorMessage,
  });

  String get distanceFormatted {
    if (distanceKm == null) return 'Distance unavailable';
    if (distanceKm! >= 100) {
      return '${distanceKm!.round()} km';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  String get durationFormatted {
    if (durationMinutes == null) return 'Drive time unavailable';
    final hours = durationMinutes! ~/ 60;
    final minutes = durationMinutes! % 60;
    if (hours > 0) {
      return minutes > 0 ? '$hours hr $minutes min' : '$hours hr';
    }
    return '$minutes min';
  }

  String get summaryText {
    if (isRouteAvailable && distanceKm != null && durationMinutes != null) {
      return '$distanceFormatted · $durationFormatted drive';
    }
    return 'Route unavailable';
  }
}

class ItineraryStopAnalysis {
  final TripStop stop;
  final WeatherInfo? weather;
  final HourlyWeatherItem? weatherAtArrival;
  final int? weatherSuitability;
  final bool isWeatherAvailable;
  final bool isWeatherLoading;
  final ItinerarySegmentAnalysis? routeFromPrevious;
  final DateTime? plannedArrivalDateTime;
  final DateTime? recommendedArrivalDateTime;
  final DateTime? suggestedDepartureDateTime;
  final DateTime? estimatedArrivalDateTime;
  final bool noFeasibleTimeToday;
  final String? timingConflictText;
  final bool hasTimingConflict;
  final String? betterWeatherWindow;

  const ItineraryStopAnalysis({
    required this.stop,
    this.weather,
    this.weatherAtArrival,
    this.weatherSuitability,
    required this.isWeatherAvailable,
    this.isWeatherLoading = false,
    this.routeFromPrevious,
    this.plannedArrivalDateTime,
    this.recommendedArrivalDateTime,
    this.suggestedDepartureDateTime,
    this.estimatedArrivalDateTime,
    this.noFeasibleTimeToday = false,
    this.timingConflictText,
    this.hasTimingConflict = false,
    this.betterWeatherWindow,
  });

  String? get plannedArrivalFormatted {
    if (plannedArrivalDateTime == null) return null;
    return DateFormat('h:mm a').format(plannedArrivalDateTime!);
  }

  String? get recommendedArrivalFormatted {
    if (recommendedArrivalDateTime == null) return null;
    return DateFormat('h:mm a').format(recommendedArrivalDateTime!);
  }

  String? get suggestedDepartureFormatted {
    if (suggestedDepartureDateTime == null) return null;
    final dt = suggestedDepartureDateTime!;
    final roundedMinutes = (dt.minute / 5.0).round() * 5;
    final rounded = DateTime(dt.year, dt.month, dt.day, dt.hour).add(Duration(minutes: roundedMinutes));
    return 'Around ${DateFormat('h:mm a').format(rounded)}';
  }

  String? get estimatedArrivalFormatted {
    if (estimatedArrivalDateTime == null) return null;
    final dt = estimatedArrivalDateTime!;
    if (dt.year != stop.visitDate.year || dt.month != stop.visitDate.month || dt.day != stop.visitDate.day) {
      return DateFormat('d MMM · h:mm a').format(dt);
    }
    return DateFormat('h:mm a').format(dt);
  }

  String? get weatherDescriptionFormatted {
    if (weatherAtArrival == null) {
      return isWeatherAvailable ? null : 'Forecast not available yet';
    }
    final temp = weatherAtArrival!.temperature?.round();
    final cond = weatherAtArrival!.condition;
    final tempStr = temp != null ? '$temp°C' : null;
    if (tempStr != null && cond.isNotEmpty) {
      return '$tempStr · $cond';
    }
    return tempStr ?? cond;
  }

  String? get rainProbabilityFormatted {
    final precip = weatherAtArrival?.precipitationProbability;
    if (precip != null) {
      return 'Rain $precip%';
    }
    return null;
  }
}

class ItineraryDayAnalysis {
  final int dayIndex;
  final DateTime dayDate;
  final List<ItineraryStopAnalysis> stops;
  final List<ItinerarySegmentAnalysis> segments;

  const ItineraryDayAnalysis({
    required this.dayIndex,
    required this.dayDate,
    required this.stops,
    required this.segments,
  });
}

class ItineraryAnalysis {
  final int tripId;
  final List<ItineraryDayAnalysis> days;
  final DateTime analyzedAt;

  const ItineraryAnalysis({
    required this.tripId,
    required this.days,
    required this.analyzedAt,
  });

  ItineraryStopAnalysis? stopAnalysis(int? stopId) {
    if (stopId == null) return null;
    for (final day in days) {
      for (final stopAnalysis in day.stops) {
        if (stopAnalysis.stop.id == stopId) {
          return stopAnalysis;
        }
      }
    }
    return null;
  }

  ItinerarySegmentAnalysis? segmentBeforeStop(int? stopId) {
    if (stopId == null) return null;
    return stopAnalysis(stopId)?.routeFromPrevious;
  }
}
