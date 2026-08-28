/// Flood status entity based on data.gov.my river & flood monitoring dataset.
class FloodStatus {
  final String statusText; // "Normal", "Alert", "Warning", "Danger"
  final String riverLevelStatus; // "Normal", "Rising", "Overflowing"
  final bool isFloodWarningActive;
  final int affectedEvacuationCenters;
  final String details;

  const FloodStatus({
    required this.statusText,
    required this.riverLevelStatus,
    required this.isFloodWarningActive,
    required this.affectedEvacuationCenters,
    required this.details,
  });

  factory FloodStatus.fromJson(Map<String, dynamic> json) {
    return FloodStatus(
      statusText: json['statusText'] as String,
      riverLevelStatus: json['riverLevelStatus'] as String,
      isFloodWarningActive: json['isFloodWarningActive'] as bool,
      affectedEvacuationCenters: json['affectedEvacuationCenters'] as int? ?? 0,
      details: json['details'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'statusText': statusText,
      'riverLevelStatus': riverLevelStatus,
      'isFloodWarningActive': isFloodWarningActive,
      'affectedEvacuationCenters': affectedEvacuationCenters,
      'details': details,
    };
  }
}
