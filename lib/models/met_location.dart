

class MetLocation {
  final String id;
  final String name;
  final String locationCategoryId;
  final String? locationRootId;
  final String state;
  final double? latitude;
  final double? longitude;

  const MetLocation({
    required this.id,
    required this.name,
    required this.locationCategoryId,
    this.locationRootId,
    required this.state,
    this.latitude,
    this.longitude,
  });

  String get formattedName {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      if (word.toUpperCase() == 'WP' || word.toUpperCase() == 'KL' || word.toUpperCase() == 'MT') {
        return word.toUpperCase();
      }
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String get categoryLabel {
    switch (locationCategoryId.toUpperCase()) {
      case 'TOURISTDEST':
        return 'Tourist Destination';
      case 'TOWN':
        return 'Town';
      case 'DISTRICT':
        return 'District';
      case 'DIVISION':
        return 'Division';
      case 'STATE':
        return 'State';
      default:
        return locationCategoryId;
    }
  }

  String get subtitle {
    if (state.isNotEmpty) {
      return '$categoryLabel • $state';
    }
    return categoryLabel;
  }

  factory MetLocation.fromJson(Map<String, dynamic> json) {
    return MetLocation(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      locationCategoryId: json['locationcategoryid'] as String? ?? '',
      locationRootId: json['locationrootid'] as String?,
      state: json['state'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'locationcategoryid': locationCategoryId,
      'locationrootid': locationRootId,
      'state': state,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
