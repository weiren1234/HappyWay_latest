import 'weather_info.dart';
import 'travel_score.dart';
import 'met_location.dart';

/// TravelDestination encapsulates curated data for featured Malaysian tourist destinations.
class TravelDestination {
  final String id;
  final String name;
  final String state; // e.g. "Pahang", "Kedah", "Sabah"
  final String category; // e.g. "Highlands", "Island & Beach", "Nature"
  final String imageUrl;
  final String description;
  final TravelScore travelScore;
  final WeatherInfo? weather; // Nullable until official MET forecast is loaded
  final bool isSaved;
  final bool isTrending;
  final String metLocationId; // Verified official MET location ID (e.g. "LOCATION:317")
  final List<String> activityTags; // e.g. ["Highlands", "Nature", "Relaxing", "Sightseeing"]
  final double? latitude;
  final double? longitude;
  final String? locationCategoryId; // e.g. "TOURISTDEST", "TOWN"

  const TravelDestination({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.imageUrl,
    required this.description,
    required this.travelScore,
    this.weather,
    this.isSaved = false,
    this.isTrending = false,
    required this.metLocationId,
    this.activityTags = const [],
    this.latitude,
    this.longitude,
    this.locationCategoryId,
  });

  TravelDestination copyWith({
    String? id,
    String? name,
    String? state,
    String? category,
    String? imageUrl,
    String? description,
    TravelScore? travelScore,
    WeatherInfo? weather,
    bool clearWeather = false,
    bool? isSaved,
    bool? isTrending,
    String? metLocationId,
    List<String>? activityTags,
    double? latitude,
    double? longitude,
    String? locationCategoryId,
  }) {
    return TravelDestination(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      travelScore: travelScore ?? this.travelScore,
      weather: clearWeather ? null : (weather ?? this.weather),
      isSaved: isSaved ?? this.isSaved,
      isTrending: isTrending ?? this.isTrending,
      metLocationId: metLocationId ?? this.metLocationId,
      activityTags: activityTags ?? this.activityTags,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationCategoryId: locationCategoryId ?? this.locationCategoryId,
    );
  }

  factory TravelDestination.fromMetLocation(MetLocation loc) {
    final nameLower = loc.name.toLowerCase();
    String category = 'Sightseeing';
    List<String> tags = ['Sightseeing', 'Relaxing', 'Family Trip'];

    if (nameLower.contains('highland') ||
        nameLower.contains('bukit') ||
        nameLower.contains('gunung') ||
        nameLower.contains('genting') ||
        nameLower.contains('fraser') ||
        nameLower.contains('cameron')) {
      category = 'Highlands';
      tags = ['Highlands', 'Nature', 'Relaxing', 'Sightseeing'];
    } else if (nameLower.contains('pantai') ||
        nameLower.contains('beach') ||
        nameLower.contains('teluk') ||
        nameLower.contains('tanjung') ||
        nameLower.contains('laut')) {
      category = 'Beach';
      tags = ['Beach', 'Relaxing', 'Family Trip', 'Sightseeing'];
    } else if (nameLower.contains('pulau') || nameLower.contains('island')) {
      category = 'Island';
      tags = ['Island', 'Beach', 'Relaxing', 'Nature'];
    } else if (nameLower.contains('taman negara') ||
        nameLower.contains('hutan') ||
        nameLower.contains('tasik') ||
        nameLower.contains('lake') ||
        nameLower.contains('air terjun') ||
        nameLower.contains('waterfall') ||
        nameLower.contains('gua') ||
        nameLower.contains('cave') ||
        nameLower.contains('danau') ||
        nameLower.contains('wetland') ||
        nameLower.contains('botani') ||
        nameLower.contains('park') ||
        nameLower.contains('taman')) {
      category = 'Nature';
      tags = ['Nature', 'Relaxing', 'Hiking', 'Family Trip', 'Sightseeing'];
    }

    return TravelDestination(
      id: 'met_${loc.id}',
      name: loc.formattedName,
      state: loc.state,
      category: category,
      imageUrl: '',
      description: '${loc.formattedName} is a ${category.toLowerCase()} destination in ${loc.state}. Weather forecasts are sourced from MET Malaysia.',
      travelScore: TravelScore.initial(),
      metLocationId: loc.id,
      activityTags: tags,
      latitude: loc.latitude,
      longitude: loc.longitude,
      locationCategoryId: loc.locationCategoryId,
    );
  }

  factory TravelDestination.fromJson(Map<String, dynamic> json) {
    return TravelDestination(
      id: json['id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      category: json['category'] as String,
      imageUrl: json['imageUrl'] as String,
      description: json['description'] as String,
      travelScore: json['travelScore'] != null
          ? TravelScore.fromJson(json['travelScore'] as Map<String, dynamic>)
          : TravelScore.initial(),
      weather: json['weather'] != null
          ? WeatherInfo.fromJson(json['weather'] as Map<String, dynamic>)
          : null,
      isSaved: json['isSaved'] as bool? ?? false,
      isTrending: json['isTrending'] as bool? ?? false,
      metLocationId: json['metLocationId'] as String? ?? json['id'] as String? ?? '',
      activityTags: (json['activityTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      locationCategoryId: json['locationCategoryId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'state': state,
      'category': category,
      'imageUrl': imageUrl,
      'description': description,
      'travelScore': travelScore.toJson(),
      'weather': weather?.toJson(),
      'isSaved': isSaved,
      'isTrending': isTrending,
      'metLocationId': metLocationId,
      'activityTags': activityTags,
      'latitude': latitude,
      'longitude': longitude,
      'locationCategoryId': locationCategoryId,
    };
  }
}
