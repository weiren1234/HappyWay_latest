import 'package:intl/intl.dart';

class PlannedTrip {
  final int? id;
  final String? userId;
  final String? tripName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? generalNote;
  final String destinationLocationId;
  final String destinationName;
  final String destinationState;
  final String destinationCategory;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationImageUrl;
  final DateTime travelDate;
  final String originName;
  final double? originLatitude;
  final double? originLongitude;
  final String preferredPeriod;
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PlannedTrip({
    this.id,
    this.userId,
    this.tripName,
    this.startDate,
    this.endDate,
    this.generalNote,
    required this.destinationLocationId,
    required this.destinationName,
    required this.destinationState,
    required this.destinationCategory,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationImageUrl,
    required this.travelDate,
    required this.originName,
    this.originLatitude,
    this.originLongitude,
    this.preferredPeriod = 'Morning',
    this.notes,
    required this.createdAt,
    this.updatedAt,
  });

  String get tripCode {
    if (id == null) return 'New Trip';
    return 'T${id.toString().padLeft(4, '0')}';
  }

  String get displayTitle {
    if (tripName != null && tripName!.trim().isNotEmpty) {
      return tripName!.trim();
    }
    if (destinationName.trim().isNotEmpty) {
      return destinationName.trim();
    }
    return 'My Trip';
  }

  DateTime get effectiveStartDate => startDate ?? travelDate;
  DateTime get effectiveEndDate => endDate ?? travelDate;
  String? get effectiveGeneralNote => generalNote ?? notes;

  String get dateRangeText {
    final start = effectiveStartDate;
    final end = effectiveEndDate;
    if (start.year == end.year && start.month == end.month && start.day == end.day) {
      return DateFormat('d MMM yyyy').format(start);
    }
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('d').format(start)}–${DateFormat('d MMM yyyy').format(end)}';
    }
    if (start.year == end.year) {
      return '${DateFormat('d MMM').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
    }
    return '${DateFormat('d MMM yyyy').format(start)} – ${DateFormat('d MMM yyyy').format(end)}';
  }

  int get totalDays {
    final start = DateTime(effectiveStartDate.year, effectiveStartDate.month, effectiveStartDate.day);
    final end = DateTime(effectiveEndDate.year, effectiveEndDate.month, effectiveEndDate.day);
    final diff = end.difference(start).inDays + 1;
    return diff > 0 ? diff : 1;
  }

  bool get isToday {
    final now = DateTime.now();
    return travelDate.year == now.year &&
        travelDate.month == now.month &&
        travelDate.day == now.day;
  }

  bool get isTomorrow => daysUntil == 1;

  bool get isPast {
    final today = DateTime.now();
    final tripDateMidnight = DateTime(travelDate.year, travelDate.month, travelDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return tripDateMidnight.isBefore(todayMidnight);
  }

  bool get isUpcoming => !isPast;

  int get daysUntil {
    final today = DateTime.now();
    final tripDateMidnight = DateTime(travelDate.year, travelDate.month, travelDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return tripDateMidnight.difference(todayMidnight).inDays;
  }

  String get formattedDate => DateFormat('d MMM yyyy').format(travelDate);

  String get formattedDay => DateFormat('d').format(travelDate);

  String get formattedMonth => DateFormat('MMM').format(travelDate).toUpperCase();

  String get formattedWeekday => DateFormat('EEEE').format(travelDate);

  String get relativeDateLabel {
    if (isToday) return 'Today';
    if (isPast) return 'Completed';
    final days = daysUntil;
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  bool get isWithinForecastRange {
    final days = daysUntil;
    return days >= 0 && days <= 6;
  }

  static const _clear = Object();

  PlannedTrip copyWith({
    int? id,
    Object? userId = _clear,
    Object? tripName = _clear,
    Object? startDate = _clear,
    Object? endDate = _clear,
    Object? generalNote = _clear,
    String? destinationLocationId,
    String? destinationName,
    String? destinationState,
    String? destinationCategory,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationImageUrl,
    DateTime? travelDate,
    String? originName,
    double? originLatitude,
    double? originLongitude,
    String? preferredPeriod,
    Object? notes = _clear,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlannedTrip(
      id: id ?? this.id,
      userId: identical(userId, _clear) ? this.userId : userId as String?,
      tripName: identical(tripName, _clear) ? this.tripName : tripName as String?,
      startDate: identical(startDate, _clear) ? this.startDate : startDate as DateTime?,
      endDate: identical(endDate, _clear) ? this.endDate : endDate as DateTime?,
      generalNote: identical(generalNote, _clear) ? this.generalNote : generalNote as String?,
      destinationLocationId: destinationLocationId ?? this.destinationLocationId,
      destinationName: destinationName ?? this.destinationName,
      destinationState: destinationState ?? this.destinationState,
      destinationCategory: destinationCategory ?? this.destinationCategory,
      destinationLatitude: destinationLatitude ?? this.destinationLatitude,
      destinationLongitude: destinationLongitude ?? this.destinationLongitude,
      destinationImageUrl: destinationImageUrl ?? this.destinationImageUrl,
      travelDate: travelDate ?? this.travelDate,
      originName: originName ?? this.originName,
      originLatitude: originLatitude ?? this.originLatitude,
      originLongitude: originLongitude ?? this.originLongitude,
      preferredPeriod: preferredPeriod ?? this.preferredPeriod,
      notes: identical(notes, _clear) ? this.notes : notes as String?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
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

  factory PlannedTrip.fromJson(Map<String, dynamic> json) {
    final rawDate = json['travel_date'] ?? json['travelDate'];
    final rawStartDate = json['start_date'] ?? json['startDate'];
    final rawEndDate = json['end_date'] ?? json['endDate'];
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

    final DateTime parsedTravelDate = _parseDateLocal(rawDate ?? rawStartDate);

    return PlannedTrip(
      id: parsedId,
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      tripName: json['trip_name']?.toString() ?? json['tripName']?.toString(),
      startDate: rawStartDate != null ? _parseDateLocal(rawStartDate) : null,
      endDate: rawEndDate != null ? _parseDateLocal(rawEndDate) : null,
      generalNote: json['general_note']?.toString() ?? json['generalNote']?.toString(),
      destinationLocationId: json['destination_location_id']?.toString() ??
          json['destinationLocationId']?.toString() ??
          '',
      destinationName: json['destination_name']?.toString() ??
          json['destinationName']?.toString() ??
          '',
      destinationState: json['destination_state']?.toString() ??
          json['destinationState']?.toString() ??
          '',
      destinationCategory: json['destination_category']?.toString() ??
          json['destinationCategory']?.toString() ??
          '',
      destinationLatitude: (json['destination_latitude'] as num?)?.toDouble() ??
          (json['destinationLatitude'] as num?)?.toDouble() ??
          double.tryParse(json['destination_latitude']?.toString() ?? ''),
      destinationLongitude: (json['destination_longitude'] as num?)?.toDouble() ??
          (json['destinationLongitude'] as num?)?.toDouble() ??
          double.tryParse(json['destination_longitude']?.toString() ?? ''),
      destinationImageUrl: json['destination_image_url']?.toString() ??
          json['destinationImageUrl']?.toString(),
      travelDate: parsedTravelDate,
      originName: json['origin_name']?.toString() ??
          json['originName']?.toString() ??
          '',
      originLatitude: (json['origin_latitude'] as num?)?.toDouble() ??
          (json['originLatitude'] as num?)?.toDouble() ??
          double.tryParse(json['origin_latitude']?.toString() ?? ''),
      originLongitude: (json['origin_longitude'] as num?)?.toDouble() ??
          (json['originLongitude'] as num?)?.toDouble() ??
          double.tryParse(json['origin_longitude']?.toString() ?? ''),
      preferredPeriod: json['preferred_period']?.toString() ??
          json['preferredPeriod']?.toString() ??
          'Morning',
      notes: json['notes']?.toString(),
      createdAt: createdDate,
      updatedAt: updatedDate,
    );
  }

  Map<String, dynamic> toSupabase({required String userId}) {
    final effectiveDate = startDate ?? travelDate;
    final map = <String, dynamic>{
      'user_id': userId,
      'trip_name': tripName,
      'start_date': DateFormat('yyyy-MM-dd').format(effectiveDate),
      'end_date': endDate != null
          ? DateFormat('yyyy-MM-dd').format(endDate!)
          : DateFormat('yyyy-MM-dd').format(effectiveDate),
      'general_note': generalNote ?? notes,
      'destination_location_id': destinationLocationId.isNotEmpty ? destinationLocationId : null,
      'destination_name': destinationName.isNotEmpty ? destinationName : null,
      'destination_state': destinationState.isNotEmpty ? destinationState : null,
      'destination_category': destinationCategory.isNotEmpty ? destinationCategory : null,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'travel_date': DateFormat('yyyy-MM-dd').format(effectiveDate),
      'origin_name': originName,
      'origin_latitude': originLatitude,
      'origin_longitude': originLongitude,
      'preferred_period': preferredPeriod,
      'notes': notes,
    };
    return map;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tripName': tripName,
      'startDate': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : null,
      'endDate': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : null,
      'generalNote': generalNote,
      'destinationLocationId': destinationLocationId,
      'destinationName': destinationName,
      'destinationState': destinationState,
      'destinationCategory': destinationCategory,
      'destinationLatitude': destinationLatitude,
      'destinationLongitude': destinationLongitude,
      'destinationImageUrl': destinationImageUrl,
      'travelDate': travelDate.toIso8601String(),
      'originName': originName,
      'originLatitude': originLatitude,
      'originLongitude': originLongitude,
      'preferredPeriod': preferredPeriod,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
