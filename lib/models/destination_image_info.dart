

class DestinationImageInfo {
  final String imageUrl;
  final String? photographer;
  final String? photographerUrl;
  final String? pexelsUrl;
  final String? altText;
  final DateTime cachedAt;
  final bool isLocalAsset;
  final bool isVerified;

  const DestinationImageInfo({
    required this.imageUrl,
    this.photographer,
    this.photographerUrl,
    this.pexelsUrl,
    this.altText,
    required this.cachedAt,
    this.isLocalAsset = false,
    this.isVerified = false,
  });

  bool isValid({Duration ttl = const Duration(days: 7)}) {
    if (isLocalAsset) return true;
    return DateTime.now().difference(cachedAt) < ttl;
  }

  factory DestinationImageInfo.fromJson(Map<String, dynamic> json) {
    return DestinationImageInfo(
      imageUrl: json['imageUrl'] as String? ?? '',
      photographer: json['photographer'] as String?,
      photographerUrl: json['photographerUrl'] as String?,
      pexelsUrl: json['pexelsUrl'] as String?,
      altText: json['altText'] as String?,
      cachedAt: json['cachedAt'] != null
          ? DateTime.tryParse(json['cachedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      isLocalAsset: json['isLocalAsset'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'photographer': photographer,
      'photographerUrl': photographerUrl,
      'pexelsUrl': pexelsUrl,
      'altText': altText,
      'cachedAt': cachedAt.toIso8601String(),
      'isLocalAsset': isLocalAsset,
      'isVerified': isVerified,
    };
  }
}
