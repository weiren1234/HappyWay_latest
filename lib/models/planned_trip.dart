import 'package:intl/intl.dart';

/// PlannedTrip represents a trip that the user has planned to take.
///
/// NOTE: Weather data is NOT permanently stored within the trip object.
/// Weather changes over time and is queried dynamically from official MET Malaysia
/// when viewing the trip, provided the travel date falls within the official forecast window.
///
/// Database ID is an auto-incrementing bigint (`int? id` in Dart).
/// The UI displays `tripCode` (e.g., "T0001", "T0002") derived from this integer ID.
class PlannedTrip {
  final int? id; // Supabase bigint primary key (null before insert)
  final String destinationLocationId; // Official MET location ID (e.g. "LOCATION:314")
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
  final String preferredPeriod; // "Morning", "Afternoon", "Night", or "Auto"
  final String? notes;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const PlannedTrip({
    this.id,
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

  /// User-friendly trip code for display (e.g. "T0001", "T0042").
  String get tripCode {
    if (id == null) return 'New Trip';
    return 'T${id.toString().padLeft(4, '0')}';
  }

  /// Check if the trip is scheduled for today.
  bool get isToday {
    final now = DateTime.now();
    return travelDate.year == now.year &&
        travelDate.month == now.month &&
        travelDate.day == now.day;
  }

  /// Check if the trip is scheduled for tomorrow.
  bool get isTomorrow => daysUntil == 1;

  /// Check if the trip travel date is in the past.
  bool get isPast {
    final today = DateTime.now();
    final tripDateMidnight = DateTime(travelDate.year, travelDate.month, travelDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return tripDateMidnight.isBefore(todayMidnight);
  }

  /// Check if the trip is upcoming (today or future).
  bool get isUpcoming => !isPast;

  /// Number of days until the trip (0 for today, negative for past).
  int get daysUntil {
    final today = DateTime.now();
    final tripDateMidnight = DateTime(travelDate.year, travelDate.month, travelDate.day);
    final todayMidnight = DateTime(today.year, today.month, today.day);
    return tripDateMidnight.difference(todayMidnight).inDays;
  }

  /// Formatted date string (e.g., "24 Aug 2026").
  String get formattedDate => DateFormat('d MMM yyyy').format(travelDate);

  /// Day of the month (e.g., "24").
  String get formattedDay => DateFormat('d').format(travelDate);

  /// Month abbreviation in uppercase (e.g., "AUG").
  String get formattedMonth => DateFormat('MMM').format(travelDate).toUpperCase();

  /// Day of the week (e.g., "Monday").
  String get formattedWeekday => DateFormat('EEEE').format(travelDate);

  /// Relative countdown label (e.g. "Today", "Tomorrow", "In 5 days", "Completed").
  String get relativeDateLabel {
    if (isToday) return 'Today';
    if (isPast) return 'Completed';
    final days = daysUntil;
    if (days == 1) return 'Tomorrow';
    return 'In $days days';
  }

  /// Checks if the trip date is within official MET forecast range (today through +6 days).
  bool get isWithinForecastRange {
    final days = daysUntil;
    return days >= 0 && days <= 6;
  }

  PlannedTrip copyWith({
    int? id,
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
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PlannedTrip(
      id: id ?? this.id,
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
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Parses a yyyy-MM-dd date string as a LOCAL calendar date (year/month/day only).
  /// Parses a yyyy-MM-dd date string or DateTime as a LOCAL calendar date (year/month/day only).
  /// Avoids the DateTime.parse UTC midnight bug where '2026-08-27' becomes
  /// 2026-08-26 in MYT (UTC+8) local time.
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
      // If it's a bare date (yyyy-MM-dd), construct as local midnight directly.
      if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
        final parts = str.substring(0, 10).split('-');
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      // Full ISO8601 timestamp: parse then convert to local-date-only
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

    return PlannedTrip(
      id: parsedId,
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
      travelDate: _parseDateLocal(rawDate),
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

  /// Converts model to Supabase payload map for insertion or update.
  Map<String, dynamic> toSupabase({required String userId}) {
    final map = <String, dynamic>{
      'user_id': userId,
      'destination_location_id': destinationLocationId,
      'destination_name': destinationName,
      'destination_state': destinationState,
      'destination_category': destinationCategory,
      'destination_latitude': destinationLatitude,
      'destination_longitude': destinationLongitude,
      'travel_date': DateFormat('yyyy-MM-dd').format(travelDate),
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
