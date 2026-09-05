import '../models/flood_status.dart';
import 'api_client.dart';

class FloodService {
  final ApiClient _apiClient = ApiClient();

  ApiClient get apiClient => _apiClient;

  Future<FloodStatus> fetchFloodStatus(String state, String district) async {
    try {

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
