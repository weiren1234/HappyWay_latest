import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripStop {
  final int? id;
  final int tripId;
  final String userId;
  final int stopOrder;
  final String? locationId;
  final String locationName;
  final String? state;
  final String? category;
  final double latitude;
  final double longitude;
  final String? metLocationId;
  final String? metLocationName;
  final String? sourceType;
  final String? address;
  final DateTime visitDate;
  final String timeMode;
  final String? preferredPeriod;
  final String? plannedArrivalTime;
  final String? plannedDepartureTime;
  final int? stayDurationMinutes;
  final String? note;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TripStop({
    this.id,
    required this.tripId,
    required this.userId,
    required this.stopOrder,
    this.locationId,
    required this.locationName,
    this.state,
    this.category,
    required this.latitude,
    required this.longitude,
    this.metLocationId,
    this.metLocationName,
    this.sourceType,
    this.address,
    required this.visitDate,
    this.timeMode = 'exact',
    this.preferredPeriod,
    this.plannedArrivalTime,
    this.plannedDepartureTime,
    this.stayDurationMinutes,
    this.note,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isExactTime => timeMode == 'exact';
  bool get isFlexibleTime => timeMode == 'flexible';

  String? get effectiveMetLocationId {
    if (metLocationId != null && metLocationId!.trim().isNotEmpty) {
      return metLocationId;
    }
    if (locationId != null) {
      if (locationId!.startsWith('LOCATION:')) return locationId;
      if (locationId!.startsWith('met:')) return locationId!.substring(4);
    }
    return null;
  }

  TimeOfDay? get arrivalTimeOfDay {
    if (plannedArrivalTime == null || plannedArrivalTime!.isEmpty) return null;
    return _parseTimeString(plannedArrivalTime!);
  }

  TimeOfDay? get departureTimeOfDay {
    if (plannedDepartureTime == null || plannedDepartureTime!.isEmpty) return null;
    return _parseTimeString(plannedDepartureTime!);
  }

  String? get formattedArrivalTime {
    final tod = arrivalTimeOfDay;
    if (tod == null) return null;
    return _formatTimeOfDay(tod);
  }

  String? get formattedDepartureTime {
    final tod = departureTimeOfDay;
    if (tod == null) return null;
    return _formatTimeOfDay(tod);
  }

  String get displayTimeString {
    if (isExactTime && formattedArrivalTime != null) {
      return formattedArrivalTime!;
    }
    if (preferredPeriod != null && preferredPeriod!.isNotEmpty) {
      return preferredPeriod!;
    }
    return 'Flexible';
  }

  static TimeOfDay? _parseTimeString(String raw) {
    try {
      final parts = raw.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0].trim());
        final minute = int.parse(parts[1].trim());
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (_) {}
    return null;
  }

  static String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  static DateTime _parseDateLocal(dynamic raw) {
    if (raw == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
    if (raw is DateTime) {
      return DateTime(raw.year, raw.month, raw.day);
    }
    final str = raw.toString().trim();
    try {
      if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
        final parts = str.substring(0, 10).split('-');
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      final dt = DateTime.parse(str);
      final local = dt.toLocal();
      return DateTime(local.year, local.month, local.day);
    } catch (_) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day);
    }
  }

  static const _clear = Object();

  TripStop copyWith({
    int? id,
    int? tripId,
    String? userId,
    int? stopOrder,
    Object? locationId = _clear,
    String? locationName,
    Object? state = _clear,
    Object? category = _clear,
    double? latitude,
    double? longitude,
    Object? metLocationId = _clear,
    Object? metLocationName = _clear,
    Object? sourceType = _clear,
    Object? address = _clear,
    DateTime? visitDate,
    String? timeMode,
    Object? preferredPeriod = _clear,
    Object? plannedArrivalTime = _clear,
    Object? plannedDepartureTime = _clear,
    Object? stayDurationMinutes = _clear,
    Object? note = _clear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TripStop(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      userId: userId ?? this.userId,
      stopOrder: stopOrder ?? this.stopOrder,
      locationId: identical(locationId, _clear) ? this.locationId : locationId as String?,
      locationName: locationName ?? this.locationName,
      state: identical(state, _clear) ? this.state : state as String?,
      category: identical(category, _clear) ? this.category : category as String?,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      metLocationId: identical(metLocationId, _clear) ? this.metLocationId : metLocationId as String?,
      metLocationName: identical(metLocationName, _clear) ? this.metLocationName : metLocationName as String?,
      sourceType: identical(sourceType, _clear) ? this.sourceType : sourceType as String?,
      address: identical(address, _clear) ? this.address : address as String?,
      visitDate: visitDate ?? this.visitDate,
      timeMode: timeMode ?? this.timeMode,
      preferredPeriod: identical(preferredPeriod, _clear) ? this.preferredPeriod : preferredPeriod as String?,
      plannedArrivalTime: identical(plannedArrivalTime, _clear) ? this.plannedArrivalTime : plannedArrivalTime as String?,
      plannedDepartureTime: identical(plannedDepartureTime, _clear) ? this.plannedDepartureTime : plannedDepartureTime as String?,
      stayDurationMinutes: identical(stayDurationMinutes, _clear) ? this.stayDurationMinutes : stayDurationMinutes as int?,
      note: identical(note, _clear) ? this.note : note as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory TripStop.fromJson(Map<String, dynamic> json) {
    final rawDate = json['visit_date'] ?? json['visitDate'];
    final rawCreated = json['created_at'] ?? json['createdAt'];
    final rawUpdated = json['updated_at'] ?? json['updatedAt'];

    DateTime createdDate;
    if (rawCreated is DateTime) {
      createdDate = rawCreated;
    } else if (rawCreated != null && rawCreated.toString().isNotEmpty) {
      try {
        createdDate = DateTime.parse(rawCreated.toString()).toLocal();
      } catch (_) {
        createdDate = DateTime.now();
      }
    } else {
      createdDate = DateTime.now();
    }

    DateTime? updatedDate;
    if (rawUpdated is DateTime) {
      updatedDate = rawUpdated;
    } else if (rawUpdated != null && rawUpdated.toString().isNotEmpty) {
      try {
        updatedDate = DateTime.parse(rawUpdated.toString()).toLocal();
      } catch (_) {
        updatedDate = null;
      }
    }

    final dynamic rawId = json['id'];
    int? parsedId;
    if (rawId is num) {
      parsedId = rawId.toInt();
    } else if (rawId != null) {
      parsedId = int.tryParse(rawId.toString());
    }

    final dynamic rawTripId = json['trip_id'] ?? json['tripId'];
    int parsedTripId = 0;
    if (rawTripId is num) {
      parsedTripId = rawTripId.toInt();
    } else if (rawTripId != null) {
      parsedTripId = int.tryParse(rawTripId.toString()) ?? 0;
    }

    final dynamic rawStopOrder = json['stop_order'] ?? json['stopOrder'];
    int parsedStopOrder = 1;
    if (rawStopOrder is num) {
      parsedStopOrder = rawStopOrder.toInt();
    } else if (rawStopOrder != null) {
      parsedStopOrder = int.tryParse(rawStopOrder.toString()) ?? 1;
    }

    final dynamic rawDuration = json['stay_duration_minutes'] ?? json['stayDurationMinutes'];
    int? parsedDuration;
    if (rawDuration is num) {
      parsedDuration = rawDuration.toInt();
    } else if (rawDuration != null) {
      parsedDuration = int.tryParse(rawDuration.toString());
    }

    return TripStop(
      id: parsedId,
      tripId: parsedTripId,
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
      stopOrder: parsedStopOrder,
      locationId: (json['location_id'] ?? json['locationId'])?.toString(),
      locationName: (json['location_name'] ?? json['locationName'])?.toString() ?? '',
      state: (json['state'])?.toString(),
      category: (json['category'])?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble() ??
          double.tryParse(json['latitude']?.toString() ?? '') ??
          0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ??
          double.tryParse(json['longitude']?.toString() ?? '') ??
          0.0,
      metLocationId: (json['met_location_id'] ?? json['metLocationId'])?.toString(),
      metLocationName: (json['met_location_name'] ?? json['metLocationName'])?.toString(),
      sourceType: (json['source_type'] ?? json['sourceType'])?.toString(),
      address: (json['address'])?.toString(),
      visitDate: _parseDateLocal(rawDate),
      timeMode: (json['time_mode'] ?? json['timeMode'])?.toString() ?? 'exact',
      preferredPeriod: (json['preferred_period'] ?? json['preferredPeriod'])?.toString(),
      plannedArrivalTime: (json['planned_arrival_time'] ?? json['plannedArrivalTime'])?.toString(),
      plannedDepartureTime: (json['planned_departure_time'] ?? json['plannedDepartureTime'])?.toString(),
      stayDurationMinutes: parsedDuration,
      note: (json['note'])?.toString(),
      createdAt: createdDate,
      updatedAt: updatedDate,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'trip_id': tripId,
      'user_id': userId,
      'stop_order': stopOrder,
      'location_id': locationId,
      'location_name': locationName,
      'state': state,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'met_location_id': metLocationId,
      'met_location_name': metLocationName,
      'source_type': sourceType,
      'address': address,
      'visit_date': DateFormat('yyyy-MM-dd').format(visitDate),
      'time_mode': timeMode,
      'preferred_period': preferredPeriod,
      'planned_arrival_time': plannedArrivalTime,
      'planned_departure_time': plannedDepartureTime,
      'stay_duration_minutes': stayDurationMinutes,
      'note': note,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,
      'stopOrder': stopOrder,
      'locationId': locationId,
      'locationName': locationName,
      'state': state,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'metLocationId': metLocationId,
      'metLocationName': metLocationName,
      'sourceType': sourceType,
      'address': address,
      'visitDate': DateFormat('yyyy-MM-dd').format(visitDate),
      'timeMode': timeMode,
      'preferredPeriod': preferredPeriod,
      'plannedArrivalTime': plannedArrivalTime,
      'plannedDepartureTime': plannedDepartureTime,
      'stayDurationMinutes': stayDurationMinutes,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
