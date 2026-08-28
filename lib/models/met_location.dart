/// MetLocation represents a lightweight official Malaysian location from the MET Malaysia API
/// (`https://api.met.gov.my/v2.1/locations`).
class MetLocation {
  final String id; // Official MET location ID (e.g. "LOCATION:316", "LOCATION:122")
  final String name; // Official name in MET dataset (e.g. "DESARU", "PORT DICKSON")
  final String locationCategoryId; // e.g. "TOURISTDEST", "TOWN", "DISTRICT"
  final String? locationRootId; // State ID (e.g. "LOCATION:1" = Johor)
  final String state; // Resolved State Name (e.g. "Johor", "Negeri Sembilan")
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

  /// Formatted title case name (e.g., "DESARU" -> "Desaru", "PORT DICKSON" -> "Port Dickson").
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

  /// User-friendly label for the location category.
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

  /// Subtitle distinguishing duplicate/similar locations, e.g. "Town • Pahang" vs "District • Pahang".
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
