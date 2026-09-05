
class AirQualityInfo {
  final int apiValue;
  final String statusText;
  final double pm25;
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
