/// Hourly weather item representing an hour's forecast or special event (e.g. Sunset / Sunrise).
class HourlyWeatherItem {
  final DateTime time;
  final String timeLabel; // e.g. "Now", "5PM", "6PM", "7:20PM"
  final double? temperature; // in °C (null for sunset/sunrise items)
  final String condition; // e.g. "Partly Cloudy", "Thunderstorms"
  final String iconCode; // "sunny", "partly_cloudy", "cloudy", "rain", "thunderstorm", "sunset", "sunrise"
  final int? precipitationProbability; // 0 - 100%
  final int? humidity; // 0 - 100%
  final bool isSunset;
  final bool isSunrise;
  final String? specialLabel; // "Sunset", "Sunrise"
  final int? weatherCode; // WMO weather code (0 - 99)
  final double? apparentTemperature; // in °C (feels like)
  final double? uvIndex; // UV index
  final double? visibility; // in meters
  final double? windSpeed; // in km/h

  const HourlyWeatherItem({
    required this.time,
    required this.timeLabel,
    this.temperature,
    required this.condition,
    required this.iconCode,
    this.precipitationProbability,
    this.humidity,
    this.isSunset = false,
    this.isSunrise = false,
    this.specialLabel,
    this.weatherCode,
    this.apparentTemperature,
    this.uvIndex,
    this.visibility,
    this.windSpeed,
  });

  factory HourlyWeatherItem.fromJson(Map<String, dynamic> json) {
    return HourlyWeatherItem(
      time: DateTime.parse(json['time'] as String),
      timeLabel: json['timeLabel'] as String? ?? '',
      temperature: (json['temperature'] as num?)?.toDouble(),
      condition: json['condition'] as String? ?? 'Clear',
      iconCode: json['iconCode'] as String? ?? 'cloudy',
      precipitationProbability: (json['precipitationProbability'] as num?)?.toInt(),
      humidity: (json['humidity'] as num?)?.toInt(),
      isSunset: json['isSunset'] as bool? ?? false,
      isSunrise: json['isSunrise'] as bool? ?? false,
      specialLabel: json['specialLabel'] as String?,
      weatherCode: (json['weatherCode'] as num?)?.toInt(),
      apparentTemperature: (json['apparentTemperature'] as num?)?.toDouble(),
      uvIndex: (json['uvIndex'] as num?)?.toDouble(),
      visibility: (json['visibility'] as num?)?.toDouble(),
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time.toIso8601String(),
      'timeLabel': timeLabel,
      'temperature': temperature,
      'condition': condition,
      'iconCode': iconCode,
      'precipitationProbability': precipitationProbability,
      'humidity': humidity,
      'isSunset': isSunset,
      'isSunrise': isSunrise,
      'specialLabel': specialLabel,
      'weatherCode': weatherCode,
      'apparentTemperature': apparentTemperature,
      'uvIndex': uvIndex,
      'visibility': visibility,
      'windSpeed': windSpeed,
    };
  }
}

/// Weather data entity containing daily summary, period breakdowns, and hourly forecast.
class WeatherInfo {
  final double? maxTemperature; // Celsius
  final double? minTemperature; // Celsius
  final String condition; // e.g. "Thunderstorms", "Partly Cloudy"
  final String iconCode; // "thunderstorm", "rain", "sunny", "partly_cloudy", "cloudy"
  final String alertLevel; // "None", "Yellow Alert", etc.
  final String? morningCondition;
  final String? afternoonCondition;
  final String? nightCondition;
  final String? significantWeather;
  final String? significantWhen;

  // Rich Travel-Day Metrics
  final List<HourlyWeatherItem>? hourlyForecast;
  final String? sunriseTime; // e.g. "07:05 AM"
  final String? sunsetTime; // e.g. "07:22 PM"
  final double? uvIndex; // e.g. 7.5
  final int? precipitationProbability; // 0 - 100%
  final int? humidity; // 0 - 100%
  final double? feelsLike; // in °C
  final double? windSpeed; // in km/h

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
    this.hourlyForecast,
    this.sunriseTime,
    this.sunsetTime,
    this.uvIndex,
    this.precipitationProbability,
    this.humidity,
    this.feelsLike,
    this.windSpeed,
  });

  /// Average temperature if both max and min are present, or whichever is available.
  double? get temperature {
    if (maxTemperature != null && minTemperature != null) {
      return (maxTemperature! + minTemperature!) / 2;
    }
    return maxTemperature ?? minTemperature;
  }

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    List<HourlyWeatherItem>? hourly;
    if (json['hourlyForecast'] is List) {
      hourly = (json['hourlyForecast'] as List)
          .map((e) => HourlyWeatherItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

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
      hourlyForecast: hourly,
      sunriseTime: json['sunriseTime'] as String?,
      sunsetTime: json['sunsetTime'] as String?,
      uvIndex: (json['uvIndex'] as num?)?.toDouble(),
      precipitationProbability: (json['precipitationProbability'] as num?)?.toInt(),
      humidity: (json['humidity'] as num?)?.toInt(),
      feelsLike: (json['feelsLike'] as num?)?.toDouble(),
      windSpeed: (json['windSpeed'] as num?)?.toDouble(),
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
      if (hourlyForecast != null)
        'hourlyForecast': hourlyForecast!.map((h) => h.toJson()).toList(),
      'sunriseTime': sunriseTime,
      'sunsetTime': sunsetTime,
      'uvIndex': uvIndex,
      'precipitationProbability': precipitationProbability,
      'humidity': humidity,
      'feelsLike': feelsLike,
      'windSpeed': windSpeed,
    };
  }

  WeatherInfo copyWith({
    double? maxTemperature,
    double? minTemperature,
    String? condition,
    String? iconCode,
    String? alertLevel,
    String? morningCondition,
    String? afternoonCondition,
    String? nightCondition,
    String? significantWeather,
    String? significantWhen,
    List<HourlyWeatherItem>? hourlyForecast,
    String? sunriseTime,
    String? sunsetTime,
    double? uvIndex,
    int? precipitationProbability,
    int? humidity,
    double? feelsLike,
    double? windSpeed,
  }) {
    return WeatherInfo(
      maxTemperature: maxTemperature ?? this.maxTemperature,
      minTemperature: minTemperature ?? this.minTemperature,
      condition: condition ?? this.condition,
      iconCode: iconCode ?? this.iconCode,
      alertLevel: alertLevel ?? this.alertLevel,
      morningCondition: morningCondition ?? this.morningCondition,
      afternoonCondition: afternoonCondition ?? this.afternoonCondition,
      nightCondition: nightCondition ?? this.nightCondition,
      significantWeather: significantWeather ?? this.significantWeather,
      significantWhen: significantWhen ?? this.significantWhen,
      hourlyForecast: hourlyForecast ?? this.hourlyForecast,
      sunriseTime: sunriseTime ?? this.sunriseTime,
      sunsetTime: sunsetTime ?? this.sunsetTime,
      uvIndex: uvIndex ?? this.uvIndex,
      precipitationProbability: precipitationProbability ?? this.precipitationProbability,
      humidity: humidity ?? this.humidity,
      feelsLike: feelsLike ?? this.feelsLike,
      windSpeed: windSpeed ?? this.windSpeed,
    );
  }
}
