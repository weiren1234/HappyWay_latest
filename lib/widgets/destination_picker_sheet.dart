import 'package:flutter/material.dart';
import '../models/met_location.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../services/met_location_service.dart';
import '../services/geocoding_service.dart';
import '../services/place_search_service.dart';
import '../services/nominatim_place_search_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DestinationPickerSheet extends StatefulWidget {
  final String? selectedLocationId;
  final ValueChanged<TravelLocation> onSelectTravelLocation;
  final ValueChanged<MetLocation>? onSelectLocation;
  final TravelDestination? selectedDestination;
  final ValueChanged<TravelDestination>? onSelect;
  final PlaceSearchService? placeSearchService;

  const DestinationPickerSheet({
    super.key,
    this.selectedLocationId,
    required this.onSelectTravelLocation,
    this.onSelectLocation,
    this.selectedDestination,
    this.onSelect,
    this.placeSearchService,
    List<TravelDestination>? destinations,
  });

  @override
  State<DestinationPickerSheet> createState() => _DestinationPickerSheetState();
}

class _DestinationPickerSheetState extends State<DestinationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  late final PlaceSearchService _placeSearchService;

  List<MetLocation> _allLocations = [];
  List<MetLocation> _filteredLocations = [];
  List<PlaceSearchResult> _osmResults = [];
  List<TravelLocation> _geocodedResults = [];

  bool _isLoadingCatalogue = true;
  bool _isSearchingPlaces = false;
  bool _isGeocoding = false;
  String? _placeSearchError;
  String? _geocodingError;

  @override
  void initState() {
    super.initState();
    _placeSearchService =
        widget.placeSearchService ?? NominatimPlaceSearchService();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final locations = await MetLocationService.getLocations();
    if (mounted) {
      setState(() {
        _allLocations = locations;
        _filteredLocations = locations;
        _isLoadingCatalogue = false;
      });
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _osmResults = [];
      _placeSearchError = null;
      _geocodedResults = [];
      _geocodingError = null;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _filteredLocations = _allLocations;
      });
      return;
    }

    final q = query.trim().toLowerCase();
    final exactMatches = <MetLocation>[];
    final prefixMatches = <MetLocation>[];
    final containsMatches = <MetLocation>[];

    for (final loc in _allLocations) {
      final name = loc.name.toLowerCase();
      final formattedName = loc.formattedName.toLowerCase();
      final state = loc.state.toLowerCase();
      final cat = loc.categoryLabel.toLowerCase();

      if (name == q || formattedName == q) {
        exactMatches.add(loc);
      } else if (name.startsWith(q) || formattedName.startsWith(q)) {
        prefixMatches.add(loc);
      } else if (name.contains(q) ||
          formattedName.contains(q) ||
          state.contains(q) ||
          cat.contains(q)) {
        containsMatches.add(loc);
      }
    }

    setState(() {
      _filteredLocations = [
        ...exactMatches,
        ...prefixMatches,
        ...containsMatches
      ];
    });
  }

  Future<void> _performPlaceSearch() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSearchingPlaces = true;
      _placeSearchError = null;
      _osmResults = [];
    });

    try {
      final results = await _placeSearchService.searchPlaces(query);
      if (mounted) {
        setState(() {
          _isSearchingPlaces = false;
          _osmResults = results;
          if (results.isEmpty) {
            _placeSearchError =
                'No specific places found for "$query". You can try device geocoder below or select a MET location.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSearchingPlaces = false;
          _placeSearchError =
              'Place search is temporarily unavailable. Please try again.';
        });
      }
    }
  }

  Future<void> _performDetailedGeocoding() async {
    final query = _searchCtrl.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isGeocoding = true;
      _geocodingError = null;
      _geocodedResults = [];
    });

    final result = await GeocodingService.searchPlaces(query);

    if (mounted) {
      setState(() {
        _isGeocoding = false;
        if (result.isSuccess) {
          _geocodedResults = result.locations;
        } else {
          _geocodingError = result.errorMessage ??
              'Destination not found. Please try a more specific place or address.';
        }
      });
    }
  }

  Future<void> _selectOsmPlace(PlaceSearchResult place) async {
    final nearestMet = await MetLocationService.findNearestWeatherLocation(
      place.latitude,
      place.longitude,
      preferredState: place.state,
    );

    final loc = TravelLocation.fromPlaceSearchResult(
      place,
      metLocationId: nearestMet?.id,
      metLocationName: nearestMet?.formattedName,
    );

    _selectLocation(loc);
  }

  void _selectLocation(TravelLocation loc) {
    widget.onSelectTravelLocation(loc);
    if (widget.onSelectLocation != null &&
        loc.isMetLocation &&
        loc.metLocationId != null) {
      final met = MetLocation(
        id: loc.metLocationId!,
        name: loc.name.toUpperCase(),
        locationCategoryId: loc.category,
        state: loc.state,
        latitude: loc.latitude,
        longitude: loc.longitude,
      );
      widget.onSelectLocation!(met);
    }
    Navigator.pop(context, loc);
  }

  Color _categoryBadgeColor(String catId) {
    switch (catId.toUpperCase()) {
      case 'TOURISTDEST':
        return AppColors.accentCyan;
      case 'TOWN':
        return AppColors.weatherBlue;
      case 'DETAILED PLACE':
      case 'DETAILEDPLACE':
        return const Color(0xFF00E676);
      case 'DISTRICT':
      default:
        return const Color(0xFFB388FF);
    }
  }

  IconData _iconForCategory(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('restaurant') ||
        lower.contains('food') ||
        lower.contains('cafe') ||
        lower.contains('fast food')) {
      return Icons.restaurant_rounded;
    }
    if (lower.contains('hotel') ||
        lower.contains('hostel') ||
        lower.contains('motel') ||
        lower.contains('guest house')) {
      return Icons.hotel_rounded;
    }
    if (lower.contains('attraction') ||
        lower.contains('tourism') ||
        lower.contains('museum') ||
        lower.contains('viewpoint') ||
        lower.contains('theme park')) {
      return Icons.attractions_rounded;
    }
    if (lower.contains('shop') ||
        lower.contains('mall') ||
        lower.contains('supermarket')) {
      return Icons.shopping_bag_rounded;
    }
    if (lower.contains('worship') ||
        lower.contains('mosque') ||
        lower.contains('temple') ||
        lower.contains('church')) {
      return Icons.account_balance_rounded;
    }
    return Icons.place_rounded;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentId =
        widget.selectedLocationId ?? widget.selectedDestination?.id;
    final hasSearchQuery = _searchCtrl.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.borderGlass(context), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Destination or Stop',
                        style: AppTextStyles.titleMedium
                            .copyWith(color: AppColors.primaryText(context)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Search specific places, hotels, food or MET forecast locations',
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.secondaryText(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      color: AppColors.secondaryText(context)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: AppColors.mutedText(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: false,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.primaryText(context)),
                      decoration: InputDecoration(
                        hintText: 'e.g. Line Clear Nasi Kandar, Penang Hill...',
                        hintStyle: AppTextStyles.bodyMedium
                            .copyWith(color: AppColors.mutedText(context)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _performPlaceSearch(),
                    ),
                  ),
                  if (hasSearchQuery)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                      child: Icon(Icons.close_rounded,
                          color: AppColors.mutedText(context), size: 18),
                    ),
                ],
              ),
            ),
          ),
          if (hasSearchQuery)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isSearchingPlaces ? null : _performPlaceSearch,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.accentCyan.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        if (_isSearchingPlaces)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.accentCyan),
                          )
                        else
                          const Icon(Icons.search_rounded,
                              color: AppColors.accentCyan, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Search "${_searchCtrl.text.trim()}" Places & Sights',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Find specific restaurants, hotels, sights & addresses',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded,
                            color: AppColors.accentCyan, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (_placeSearchError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.dangerRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.dangerRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _placeSearchError!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (hasSearchQuery && _osmResults.isEmpty && !_isSearchingPlaces)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _isGeocoding ? null : _performDetailedGeocoding,
                  icon: _isGeocoding
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(Icons.location_searching_rounded,
                          size: 14, color: AppColors.mutedText(context)),
                  label: Text(
                    'Device Geocoder fallback',
                    style: TextStyle(
                        color: AppColors.mutedText(context), fontSize: 12),
                  ),
                ),
              ),
            ),
          if (_geocodingError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppColors.dangerRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: AppColors.dangerRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _geocodingError!,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoadingCatalogue
                ? const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.accentCyan))
                : ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    children: [
                      if (_osmResults.isNotEmpty) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.stars_rounded,
                                  size: 16, color: Color(0xFF00E676)),
                              const SizedBox(width: 6),
                              Text(
                                'Places & Attractions (${_osmResults.length})',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontSize: 12,
                                  color: const Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._osmResults.map((place) {
                          final isSelected = currentId == place.id;
                          return _buildOsmPlaceTile(context, place,
                              isSelected: isSelected);
                        }),
                        const SizedBox(height: 12),
                        Divider(
                            height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 10),
                      ],
                      if (_geocodedResults.isNotEmpty) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Row(
                            children: [
                              const Icon(Icons.place_rounded,
                                  size: 14, color: Color(0xFF00E676)),
                              const SizedBox(width: 6),
                              Text(
                                'Device Geocoder (${_geocodedResults.length})',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontSize: 12,
                                  color: const Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._geocodedResults.map((loc) {
                          final isSelected = currentId == loc.id;
                          return _buildTravelLocationTile(context, loc,
                              isSelected: isSelected);
                        }),
                        const SizedBox(height: 12),
                        Divider(
                            height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 10),
                      ],
                      if (_filteredLocations.isNotEmpty) ...[
                        Padding(
                          padding:
                              const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Row(
                            children: [
                              Icon(Icons.cloud_outlined,
                                  size: 14,
                                  color: AppColors.blueAccent(context)),
                              const SizedBox(width: 6),
                              Text(
                                'Official MET Weather Locations (${_filteredLocations.length})',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontSize: 12,
                                  color: AppColors.blueAccent(context),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._filteredLocations.map((loc) {
                          final travelLoc = TravelLocation.fromMetLocation(loc);
                          final isSelected = currentId == loc.id ||
                              currentId == travelLoc.id;
                          return _buildMetLocationTile(context, loc, travelLoc,
                              isSelected: isSelected);
                        }),
                      ] else if (_osmResults.isEmpty &&
                          _geocodedResults.isEmpty &&
                          !hasSearchQuery) ...[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off_rounded,
                                    size: 40,
                                    color: AppColors.mutedText(context)),
                                const SizedBox(height: 10),
                                Text(
                                  'No matching locations found',
                                  style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.secondaryText(context)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.cardBg(context),
              border: Border(
                top: BorderSide(
                    color: AppColors.borderGlass(context), width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public_rounded,
                    size: 12, color: AppColors.mutedText(context)),
                const SizedBox(width: 6),
                Text(
                  'Place data © OpenStreetMap contributors',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOsmPlaceTile(BuildContext context, PlaceSearchResult place,
      {required bool isSelected}) {
    const badgeColor = Color(0xFF00E676);
    final iconData = _iconForCategory(place.category);

    return InkWell(
      onTap: () => _selectOsmPlace(place),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                iconData,
                color: badgeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          place.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: isSelected
                                ? AppColors.cyanAccent(context)
                                : AppColors.primaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          place.category,
                          style: const TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.formattedAddress ??
                        (place.state.isNotEmpty
                            ? '${place.state} • Malaysia'
                            : 'Malaysia'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.cyanAccent(context), size: 20)
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTravelLocationTile(BuildContext context, TravelLocation loc,
      {required bool isSelected}) {
    const badgeColor = Color(0xFF00E676);

    return InkWell(
      onTap: () => _selectLocation(loc),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: badgeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.name,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: isSelected
                                ? AppColors.cyanAccent(context)
                                : AppColors.primaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: const Text(
                          'Address',
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.formattedAddress?.isNotEmpty == true
                        ? loc.formattedAddress!
                        : (loc.state.isNotEmpty ? loc.state : 'Malaysia'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.cyanAccent(context), size: 20)
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetLocationTile(
      BuildContext context, MetLocation loc, TravelLocation travelLoc,
      {required bool isSelected}) {
    final badgeColor = _categoryBadgeColor(loc.locationCategoryId);

    return InkWell(
      onTap: () => _selectLocation(travelLoc),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                loc.locationCategoryId == 'TOURISTDEST'
                    ? Icons.beach_access_rounded
                    : loc.locationCategoryId == 'TOWN'
                        ? Icons.location_city_rounded
                        : Icons.map_outlined,
                color: badgeColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          loc.formattedName,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: isSelected
                                ? AppColors.cyanAccent(context)
                                : AppColors.primaryText(context),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: badgeColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          loc.categoryLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText(context),
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isSelected)
              Icon(Icons.check_circle_rounded,
                  color: AppColors.cyanAccent(context), size: 20)
            else
              Icon(Icons.chevron_right_rounded,
                  color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }
}
