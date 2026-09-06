import 'package:intl/intl.dart';

class TripDaySetting {
  final int? id;
  final int tripId;
  final String userId;
  final DateTime visitDate;
  final String? startLocationId;
  final String startLocationName;
  final double startLatitude;
  final double startLongitude;
  final String? sourceType;
  final String? address;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const TripDaySetting({
    this.id,
    required this.tripId,
    required this.userId,
    required this.visitDate,
    this.startLocationId,
    required this.startLocationName,
    required this.startLatitude,
    required this.startLongitude,
    this.sourceType,
    this.address,
    required this.createdAt,
    this.updatedAt,
  });

  factory TripDaySetting.fromJson(Map<String, dynamic> json) {
    final rawDate = json['visit_date'] ?? json['visitDate'];
    final rawCreated = json['created_at'] ?? json['createdAt'];
    final rawUpdated = json['updated_at'] ?? json['updatedAt'];

    DateTime visitDate;
    if (rawDate is DateTime) {
      visitDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
    } else if (rawDate != null) {
      try {
        final str = rawDate.toString().trim();
        if (str.length >= 10 && str[4] == '-' && str[7] == '-') {
          final parts = str.substring(0, 10).split('-');
          visitDate = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          final dt = DateTime.parse(str);
          visitDate = DateTime(dt.year, dt.month, dt.day);
        }
      } catch (_) {
        visitDate = DateTime.now();
      }
    } else {
      visitDate = DateTime.now();
    }

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

    final dynamic rawLat = json['start_latitude'] ?? json['startLatitude'];
    final double parsedLat = rawLat is num ? rawLat.toDouble() : (double.tryParse(rawLat?.toString() ?? '') ?? 0.0);

    final dynamic rawLng = json['start_longitude'] ?? json['startLongitude'];
    final double parsedLng = rawLng is num ? rawLng.toDouble() : (double.tryParse(rawLng?.toString() ?? '') ?? 0.0);

    return TripDaySetting(
      id: parsedId,
      tripId: parsedTripId,
      userId: (json['user_id'] ?? json['userId'] ?? '').toString(),
      visitDate: visitDate,
      startLocationId: json['start_location_id'] ?? json['startLocationId'],
      startLocationName: (json['start_location_name'] ?? json['startLocationName'] ?? '').toString(),
      startLatitude: parsedLat,
      startLongitude: parsedLng,
      sourceType: json['source_type'] ?? json['sourceType'],
      address: json['address'],
      createdAt: createdDate,
      updatedAt: updatedDate,
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      'trip_id': tripId,
      'visit_date': DateFormat('yyyy-MM-dd').format(visitDate),
      'start_location_id': startLocationId,
      'start_location_name': startLocationName,
      'start_latitude': startLatitude,
      'start_longitude': startLongitude,
      'source_type': sourceType,
      'address': address,
    };
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'userId': userId,
      'visitDate': DateFormat('yyyy-MM-dd').format(visitDate),
      'startLocationId': startLocationId,
      'startLocationName': startLocationName,
      'startLatitude': startLatitude,
      'startLongitude': startLongitude,
      'sourceType': sourceType,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }
}
