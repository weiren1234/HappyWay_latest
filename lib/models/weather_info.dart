/// Weather data entity based strictly on official MET Malaysia API fields.
/// Only fields actually provided by MET Malaysia are stored.
class WeatherInfo {
  final double? maxTemperature; // Celsius (from FMAXT)
  final double? minTemperature; // Celsius (from FMINT)
  final String condition; // e.g. "Thunderstorms", "No Rain", "Rain" (from FGA/FSIGW)
  final String iconCode; // e.g. "thunderstorm", "rain", "sunny", "partly_cloudy", "cloudy"
  final String alertLevel; // "None", "Yellow Alert — Thunderstorms", etc. (from FSIGW)
  final String? morningCondition; // from FGM
  final String? afternoonCondition; // from FGA
  final String? nightCondition; // from FGN
  final String? significantWeather; // from FSIGW
  final String? significantWhen; // e.g. "Afternoon", "Night"

  const WeatherInfo({
    this.maxTemperature,
    this.minTemperature,
    required this.condition,
    required this.iconCode,
    required this.alertLevel,
    this.morningCondition,
    this.afternoonCondition,
    this.nightCondition,
    this.significantWeather,
    this.significantWhen,
  });

  /// Average temperature if both max and min are present, or whichever is available.
  double? get temperature {
    if (maxTemperature != null && minTemperature != null) {
      return (maxTemperature! + minTemperature!) / 2;
    }
    return maxTemperature ?? minTemperature;
  }

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      maxTemperature: (json['maxTemperature'] as num?)?.toDouble(),
      minTemperature: (json['minTemperature'] as num?)?.toDouble(),
      condition: json['condition'] as String? ?? 'Unavailable',
      iconCode: json['iconCode'] as String? ?? 'cloudy',
      alertLevel: json['alertLevel'] as String? ?? 'None',
      morningCondition: json['morningCondition'] as String?,
      afternoonCondition: json['afternoonCondition'] as String?,
      nightCondition: json['nightCondition'] as String?,
      significantWeather: json['significantWeather'] as String?,
      significantWhen: json['significantWhen'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxTemperature': maxTemperature,
      'minTemperature': minTemperature,
      'condition': condition,
      'iconCode': iconCode,
      'alertLevel': alertLevel,
      'morningCondition': morningCondition,
      'afternoonCondition': afternoonCondition,
      'nightCondition': nightCondition,
      'significantWeather': significantWeather,
      'significantWhen': significantWhen,
    };
  }
}
