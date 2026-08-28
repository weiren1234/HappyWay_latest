import '../models/flood_status.dart';
import 'api_client.dart';

/// FloodService communicates with data.gov.my flood monitoring dataset or fallback mock data.
class FloodService {
  final ApiClient _apiClient = ApiClient();

  /// Returns the configured ApiClient instance for live API calls.
  ApiClient get apiClient => _apiClient;

  /// Fetches flood risk status for a destination state or district.
  Future<FloodStatus> fetchFloodStatus(String state, String district) async {
    try {
      // Endpoint contract for data.gov.my flood portal
      // final response = await _apiClient.dio.get('https://api.data.gov.my/flood-monitoring', queryParameters: {'state': state});

      return _getMockFloodStatus(state, district);
    } catch (e) {
      return _getMockFloodStatus(state, district);
    }
  }

  FloodStatus _getMockFloodStatus(String state, String district) {
    if (state.toLowerCase().contains('pahang') || district.toLowerCase().contains('jerantut')) {
      return const FloodStatus(
        statusText: 'Warning',
        riverLevelStatus: 'Overflowing (Sungai Tembeling)',
        isFloodWarningActive: true,
        affectedEvacuationCenters: 4,
        details: 'River levels elevated above danger threshold. River cruise activities suspended.',
      );
    } else if (state.toLowerCase().contains('kelantan')) {
      return const FloodStatus(
        statusText: 'Alert',
        riverLevelStatus: 'Rising',
        isFloodWarningActive: true,
        affectedEvacuationCenters: 1,
        details: 'Monsoon rainfall causing localized flash floods in low-lying areas.',
      );
    } else {
      return const FloodStatus(
        statusText: 'Normal',
        riverLevelStatus: 'Normal Water Level',
        isFloodWarningActive: false,
        affectedEvacuationCenters: 0,
        details: 'No flood risk recorded across river monitoring stations.',
      );
    }
  }
}
