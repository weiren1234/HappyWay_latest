import '../models/air_quality_info.dart';
import 'api_client.dart';

class AirQualityService {
  final ApiClient _apiClient = ApiClient();

  ApiClient get apiClient => _apiClient;

  Future<AirQualityInfo> fetchAirQuality(String state, String station) async {
    try {

      return _getMockAirQuality(state, station);
    } catch (e) {
      return _getMockAirQuality(state, station);
    }
  }

  AirQualityInfo _getMockAirQuality(String state, String station) {
    if (station.toLowerCase().contains('kl') || station.toLowerCase().contains('batu caves')) {
      return const AirQualityInfo(
        apiValue: 78,
        statusText: 'Moderate',
        pm25: 24.5,
        healthAdvice: 'Air quality is acceptable. Sensitive individuals should consider limiting prolonged outdoor exertion.',
      );
    } else if (station.toLowerCase().contains('port dickson')) {
      return const AirQualityInfo(
        apiValue: 42,
        statusText: 'Good',
        pm25: 10.2,
        healthAdvice: 'Air quality is clean and fresh. Perfect for beach and outdoor recreation.',
      );
    } else if (state.toLowerCase().contains('sarawak')) {
      return const AirQualityInfo(
        apiValue: 125,
        statusText: 'Unhealthy',
        pm25: 45.0,
        healthAdvice: 'Haze condition detected. Wear N95 face mask outdoors.',
      );
    } else {
      return const AirQualityInfo(
        apiValue: 35,
        statusText: 'Good',
        pm25: 8.5,
        healthAdvice: 'Ideal air quality for travel and sightseeing.',
      );
    }
  }
}
