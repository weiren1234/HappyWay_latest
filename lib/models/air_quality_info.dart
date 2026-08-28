/// Air Quality Index (API / AQI) entity based on data.gov.my air pollutant API.
class AirQualityInfo {
  final int apiValue; // Air Pollutant Index (0-500)
  final String statusText; // "Good", "Moderate", "Unhealthy", "Very Unhealthy", "Hazardous"
  final double pm25; // ug/m3
  final String healthAdvice;

  const AirQualityInfo({
    required this.apiValue,
    required this.statusText,
    required this.pm25,
    required this.healthAdvice,
  });

  factory AirQualityInfo.fromJson(Map<String, dynamic> json) {
    return AirQualityInfo(
      apiValue: json['apiValue'] as int,
      statusText: json['statusText'] as String,
      pm25: (json['pm25'] as num).toDouble(),
      healthAdvice: json['healthAdvice'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiValue': apiValue,
      'statusText': statusText,
      'pm25': pm25,
      'healthAdvice': healthAdvice,
    };
  }
}
