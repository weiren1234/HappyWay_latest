class PlaceSearchResult {
  final String id;
  final String name;
  final String state;
  final String category;
  final double latitude;
  final double longitude;
  final String? formattedAddress;
  final String? osmType;
  final int? osmId;

  const PlaceSearchResult({
    required this.id,
    required this.name,
    required this.state,
    required this.category,
    required this.latitude,
    required this.longitude,
    this.formattedAddress,
    this.osmType,
    this.osmId,
  });

  factory PlaceSearchResult.fromNominatimJson(Map<String, dynamic> json) {
    final osmTypeStr = (json['osm_type'] ?? '').toString().toLowerCase();
    String prefix = 'N';
    if (osmTypeStr.startsWith('w')) {
      prefix = 'W';
    } else if (osmTypeStr.startsWith('r')) {
      prefix = 'R';
    }

    final rawOsmId = json['osm_id'];
    int? parsedOsmId;
    if (rawOsmId is num) {
      parsedOsmId = rawOsmId.toInt();
    } else if (rawOsmId != null) {
      parsedOsmId = int.tryParse(rawOsmId.toString());
    }

    final id = 'osm:$prefix${parsedOsmId ?? json['place_id'] ?? ''}';

    String name = (json['name'] ?? '').toString().trim();
    final displayName = (json['display_name'] ?? '').toString().trim();
    if (name.isEmpty && displayName.isNotEmpty) {
      name = displayName.split(',').first.trim();
    }
    if (name.isEmpty) {
      name = 'Unnamed Place';
    }

    final addressMap = json['address'] is Map<String, dynamic>
        ? json['address'] as Map<String, dynamic>
        : const <String, dynamic>{};

    final state = (addressMap['state'] ??
            addressMap['state_district'] ??
            addressMap['city'] ??
            '')
        .toString()
        .trim();

    final type = (json['type'] ?? json['category'] ?? 'place')
        .toString()
        .replaceAll('_', ' ');

    final lat = double.tryParse(json['lat']?.toString() ?? '') ?? 0.0;
    final lon = double.tryParse(json['lon']?.toString() ?? '') ?? 0.0;

    return PlaceSearchResult(
      id: id,
      name: name,
      state: state,
      category: type,
      latitude: lat,
      longitude: lon,
      formattedAddress: displayName.isNotEmpty ? displayName : null,
      osmType: osmTypeStr.isNotEmpty ? osmTypeStr : null,
      osmId: parsedOsmId,
    );
  }
}

abstract class PlaceSearchService {
  Future<List<PlaceSearchResult>> searchPlaces(String query);
}
