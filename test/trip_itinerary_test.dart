import 'package:flutter_test/flutter_test.dart';
import 'package:happyway/models/planned_trip.dart';
import 'package:happyway/models/trip_stop.dart';
import 'package:happyway/providers/trip_provider.dart';
import 'package:happyway/services/trip_stop_service.dart';

void main() {
  group('TripStop Model Serialization & Helpers', () {
    test('Correctly serializes and deserializes TripStop JSON with exact time', () {
      final stop = TripStop(
        id: 101,
        tripId: 42,
        userId: 'user_uuid_123',
        stopOrder: 1,
        locationId: 'LOCATION:314',
        locationName: 'Restoran Mee Wah',
        state: 'Pulau Pinang',
        category: 'Food',
        latitude: 5.4164,
        longitude: 100.3327,
        metLocationId: 'LOCATION:314',
        metLocationName: 'George Town',
        sourceType: 'metLocation',
        address: 'Restoran Mee Wah, Pulau Pinang',
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '08:00:00',
        plannedDepartureTime: '08:45:00',
        stayDurationMinutes: 45,
        note: 'Try the wonton mee',
        createdAt: DateTime(2026, 10, 1, 10, 0),
        updatedAt: DateTime(2026, 10, 1, 10, 30),
      );

      expect(stop.isExactTime, isTrue);
      expect(stop.isFlexibleTime, isFalse);
      expect(stop.displayTimeString, '8:00 AM');
      expect(stop.formattedArrivalTime, '8:00 AM');
      expect(stop.formattedDepartureTime, '8:45 AM');
      expect(stop.effectiveMetLocationId, 'LOCATION:314');

      final json = stop.toJson();
      expect(json['id'], 101);
      expect(json['tripId'], 42);
      expect(json['timeMode'], 'exact');
      expect(json['plannedArrivalTime'], '08:00:00');

      final reconstructed = TripStop.fromJson({
        'id': 101,
        'trip_id': 42,
        'user_id': 'user_uuid_123',
        'stop_order': 1,
        'location_id': 'LOCATION:314',
        'location_name': 'Restoran Mee Wah',
        'state': 'Pulau Pinang',
        'category': 'Food',
        'latitude': 5.4164,
        'longitude': 100.3327,
        'met_location_id': 'LOCATION:314',
        'met_location_name': 'George Town',
        'source_type': 'metLocation',
        'address': 'Restoran Mee Wah, Pulau Pinang',
        'visit_date': '2026-11-04',
        'time_mode': 'exact',
        'planned_arrival_time': '08:00:00',
        'planned_departure_time': '08:45:00',
        'stay_duration_minutes': 45,
        'note': 'Try the wonton mee',
        'created_at': '2026-10-01T10:00:00.000Z',
      });

      expect(reconstructed.id, 101);
      expect(reconstructed.tripId, 42);
      expect(reconstructed.userId, 'user_uuid_123');
      expect(reconstructed.stopOrder, 1);
      expect(reconstructed.locationName, 'Restoran Mee Wah');
      expect(reconstructed.visitDate.year, 2026);
      expect(reconstructed.visitDate.month, 11);
      expect(reconstructed.visitDate.day, 4);
      expect(reconstructed.stayDurationMinutes, 45);
      expect(reconstructed.note, 'Try the wonton mee');
      expect(reconstructed.formattedArrivalTime, '8:00 AM');
    });

    test('TripStop toSupabase payload adheres to exact database column names', () {
      final stop = TripStop(
        tripId: 55,
        userId: 'user_uuid_456',
        stopOrder: 2,
        locationName: 'Kek Lok Si Temple',
        latitude: 5.3995,
        longitude: 100.2737,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'flexible',
        preferredPeriod: 'Morning',
        stayDurationMinutes: 90,
        note: 'Buy tickets first',
        createdAt: DateTime(2026, 10, 1),
      );

      final payload = stop.toSupabase();
      expect(payload['trip_id'], 55);
      expect(payload['user_id'], 'user_uuid_456');
      expect(payload['stop_order'], 2);
      expect(payload['location_name'], 'Kek Lok Si Temple');
      expect(payload['visit_date'], '2026-11-04');
      expect(payload['time_mode'], 'flexible');
      expect(payload['preferred_period'], 'Morning');
      expect(payload['stay_duration_minutes'], 90);
      expect(payload['note'], 'Buy tickets first');
      expect(payload.containsKey('created_at'), isFalse);
    });

    test('TripStop copyWith clears and updates fields accurately', () {
      final stop = TripStop(
        id: 1,
        tripId: 10,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Old Place',
        latitude: 3.0,
        longitude: 101.0,
        visitDate: DateTime(2026, 11, 4),
        note: 'Old note',
        createdAt: DateTime(2026, 10, 1),
      );

      final updated = stop.copyWith(
        locationName: 'New Place',
        note: null,
      );

      expect(updated.locationName, 'New Place');
      expect(updated.note, isNull);
      expect(updated.stopOrder, 1);
    });
  });

  group('PlannedTrip Multi-Day & Header Extensions', () {
    test('PlannedTrip calculates totalDays and dateRangeText accurately', () {
      final singleDayTrip = PlannedTrip(
        id: 1,
        tripName: 'One Day In Melaka',
        startDate: DateTime(2026, 11, 4),
        endDate: DateTime(2026, 11, 4),
        destinationLocationId: 'LOCATION:1',
        destinationName: 'Melaka City',
        destinationState: 'Melaka',
        destinationCategory: 'Historical',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Kuala Lumpur',
        createdAt: DateTime.now(),
      );

      expect(singleDayTrip.displayTitle, 'One Day In Melaka');
      expect(singleDayTrip.totalDays, 1);
      expect(singleDayTrip.dateRangeText, '4 Nov 2026');

      final multiDayTrip = PlannedTrip(
        id: 2,
        tripName: 'Penang Food Crawl',
        startDate: DateTime(2026, 11, 4),
        endDate: DateTime(2026, 11, 6),
        destinationLocationId: 'LOCATION:2',
        destinationName: 'George Town',
        destinationState: 'Penang',
        destinationCategory: 'Heritage',
        travelDate: DateTime(2026, 11, 4),
        originName: 'Kuala Lumpur',
        createdAt: DateTime.now(),
      );

      expect(multiDayTrip.totalDays, 3);
      expect(multiDayTrip.dateRangeText, '4–6 Nov 2026');
    });

    test('PlannedTrip falls back to legacy destinationName when tripName is null or empty', () {
      final legacyTrip = PlannedTrip(
        id: 3,
        tripName: null,
        destinationLocationId: 'LOCATION:314',
        destinationName: 'Cameron Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        travelDate: DateTime(2026, 8, 24),
        originName: 'Kuala Lumpur',
        createdAt: DateTime.now(),
      );

      expect(legacyTrip.displayTitle, 'Cameron Highlands');
      expect(legacyTrip.effectiveStartDate, DateTime(2026, 8, 24));
      expect(legacyTrip.effectiveEndDate, DateTime(2026, 8, 24));
      expect(legacyTrip.totalDays, 1);
    });
  });

  group('Stop Ordering Per Day Rule', () {
    test('Stops are ordered independently within their respective visit_date', () {
      final day1Stop1 = TripStop(
        id: 1,
        tripId: 99,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Day 1 Breakfast',
        latitude: 5.0,
        longitude: 100.0,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      );

      final day1Stop2 = TripStop(
        id: 2,
        tripId: 99,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Day 1 Lunch',
        latitude: 5.1,
        longitude: 100.1,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      );

      final day2Stop1 = TripStop(
        id: 3,
        tripId: 99,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Day 2 Morning Hike',
        latitude: 5.2,
        longitude: 100.2,
        visitDate: DateTime(2026, 11, 5),
        createdAt: DateTime.now(),
      );

      final day2Stop2 = TripStop(
        id: 4,
        tripId: 99,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Day 2 Museum Visit',
        latitude: 5.3,
        longitude: 100.3,
        visitDate: DateTime(2026, 11, 5),
        createdAt: DateTime.now(),
      );

      final allStops = [day1Stop2, day2Stop2, day1Stop1, day2Stop1];

      final day1Stops = allStops.where((s) => s.visitDate.day == 4).toList()
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));
      final day2Stops = allStops.where((s) => s.visitDate.day == 5).toList()
        ..sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

      expect(day1Stops.map((s) => s.stopOrder).toList(), [1, 2]);
      expect(day1Stops.map((s) => s.locationName).toList(), ['Day 1 Breakfast', 'Day 1 Lunch']);

      expect(day2Stops.map((s) => s.stopOrder).toList(), [1, 2]);
      expect(day2Stops.map((s) => s.locationName).toList(), ['Day 2 Morning Hike', 'Day 2 Museum Visit']);

      final reorderedDay1 = [day1Stop2.copyWith(stopOrder: 1), day1Stop1.copyWith(stopOrder: 2)];
      expect(reorderedDay1.first.locationName, 'Day 1 Lunch');
      expect(day2Stops.first.locationName, 'Day 2 Morning Hike');
      expect(day2Stops.first.stopOrder, 1);
    });
  });

  group('TripProvider Itinerary State Integration', () {
    test('Setting and querying trip stops by trip ID in provider', () {
      final provider = TripProvider(autoLoad: false, listenToAuth: false);

      expect(provider.getStopsForTrip(10), isEmpty);

      final stopA = TripStop(
        id: 11,
        tripId: 10,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Kek Lok Si',
        latitude: 5.399,
        longitude: 100.273,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      );

      final stopB = TripStop(
        id: 12,
        tripId: 10,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Penang Hill',
        latitude: 5.408,
        longitude: 100.277,
        visitDate: DateTime(2026, 11, 4),
        createdAt: DateTime.now(),
      );

      provider.setTripStopsForTesting(10, [stopA, stopB]);

      final retrieved = provider.getStopsForTrip(10);
      expect(retrieved.length, 2);
      expect(retrieved[0].locationName, 'Kek Lok Si');
      expect(retrieved[1].locationName, 'Penang Hill');

      provider.clearUserData();
      expect(provider.getStopsForTrip(10), isEmpty);
    });
  });

  group('Guest Persistence Protection', () {
    test('TripStopService throws or returns empty when user is unauthenticated', () async {
      final service = TripStopService();
      expect(service.currentUserId, isNull);

      final stops = await service.getStopsForTrip(999);
      expect(stops, isEmpty);

      final stop = TripStop(
        tripId: 999,
        userId: 'guest',
        stopOrder: 1,
        locationName: 'Test Place',
        latitude: 3.0,
        longitude: 101.0,
        visitDate: DateTime.now(),
        createdAt: DateTime.now(),
      );

      expect(() => service.createStop(stop), throwsStateError);
      expect(() => service.updateStop(stop), throwsStateError);
    });
  });

  group('Chronological Stop Ordering Logic', () {
    test('Correctly orders exact and flexible stops chronologically', () {
      final exactEarly = TripStop(
        id: 1,
        tripId: 1,
        userId: 'u1',
        stopOrder: 1,
        locationName: 'Breakfast',
        latitude: 5.0,
        longitude: 100.0,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '08:00:00',
        createdAt: DateTime.now(),
      );

      final flexibleMorning = TripStop(
        id: 2,
        tripId: 1,
        userId: 'u1',
        stopOrder: 2,
        locationName: 'Morning Market',
        latitude: 5.0,
        longitude: 100.0,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'flexible',
        preferredPeriod: 'Morning',
        createdAt: DateTime.now(),
      );

      final exactAfternoon = TripStop(
        id: 3,
        tripId: 1,
        userId: 'u1',
        stopOrder: 3,
        locationName: 'Lunch',
        latitude: 5.0,
        longitude: 100.0,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'exact',
        plannedArrivalTime: '13:00:00',
        createdAt: DateTime.now(),
      );

      final flexibleNight = TripStop(
        id: 4,
        tripId: 1,
        userId: 'u1',
        stopOrder: 4,
        locationName: 'Night Walk',
        latitude: 5.0,
        longitude: 100.0,
        visitDate: DateTime(2026, 11, 4),
        timeMode: 'flexible',
        preferredPeriod: 'Night',
        createdAt: DateTime.now(),
      );

      final scrambled = [flexibleNight, exactAfternoon, flexibleMorning, exactEarly];
      final sorted = List<TripStop>.from(scrambled);

      int stopSortMinutes(TripStop stop) {
        if (stop.isExactTime && stop.arrivalTimeOfDay != null) {
          final tod = stop.arrivalTimeOfDay!;
          return tod.hour * 60 + tod.minute;
        }
        final period = (stop.preferredPeriod ?? 'morning').trim().toLowerCase();
        if (period.startsWith('morning')) return 9 * 60;
        if (period.startsWith('afternoon')) return 14 * 60;
        if (period.startsWith('night')) return 19 * 60;
        return 12 * 60;
      }

      sorted.sort((a, b) {
        final aMin = stopSortMinutes(a);
        final bMin = stopSortMinutes(b);
        final cmp = aMin.compareTo(bMin);
        if (cmp != 0) return cmp;
        return a.stopOrder.compareTo(b.stopOrder);
      });

      expect(sorted.map((s) => s.locationName).toList(), [
        'Breakfast',
        'Morning Market',
        'Lunch',
        'Night Walk',
      ]);
    });
  });
}
