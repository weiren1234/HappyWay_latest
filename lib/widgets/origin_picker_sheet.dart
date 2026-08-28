import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/met_location.dart';
import '../models/travel_location.dart';
import '../providers/location_provider.dart';
import '../services/met_location_service.dart';
import '../services/geocoding_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// OriginPickerSheet provides an origin selection modal supporting two clear choices:
/// 1. 📍 Current Location (real device GPS position)
/// 2. 🔎 Search another place or address (manual starting point)
class OriginPickerSheet extends StatefulWidget {
  final ValueChanged<TravelLocation>? onSelectTravelLocation;
  final VoidCallback? onSelectCurrentLocation;

  const OriginPickerSheet({
    super.key,
    this.onSelectTravelLocation,
    this.onSelectCurrentLocation,
  });

  @override
  State<OriginPickerSheet> createState() => _OriginPickerSheetState();
}

class _OriginPickerSheetState extends State<OriginPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<MetLocation> _allLocations = [];
  List<MetLocation> _filteredLocations = [];
  List<TravelLocation> _geocodedResults = [];
  bool _isLoadingCatalogue = true;
  bool _isGeocoding = false;
  String? _geocodingError;

  @override
  void initState() {
    super.initState();
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
      _filteredLocations = [...exactMatches, ...prefixMatches, ...containsMatches];
    });
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
          _geocodingError = result.errorMessage ?? 'Starting location not found. Please try a more specific place.';
        }
      });
    }
  }

  void _selectCurrentLocation() {
    if (widget.onSelectCurrentLocation != null) {
      widget.onSelectCurrentLocation!();
    } else {
      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      locProvider.selectCurrentLocation();
    }
    Navigator.pop(context);
  }

  void _selectManualLocation(TravelLocation loc) {
    if (widget.onSelectTravelLocation != null) {
      widget.onSelectTravelLocation!(loc);
    } else {
      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      locProvider.setManualLocation(loc);
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locProvider = Provider.of<LocationProvider>(context);
    final isCurrentGps = locProvider.isGps;
    final hasSearchQuery = _searchCtrl.text.trim().isNotEmpty;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.borderGlass(context), width: 1.5),
        ),
      ),
      child: Column(
        children: [
          // Drag indicator
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.glassBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Choose Origin', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                    Text(
                      'Select GPS or search another starting location',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.secondaryText(context)),
                ),
              ],
            ),
          ),

          // ── Option 1: 📍 Current Location Tile ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _selectCurrentLocation,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isCurrentGps
                        ? AppColors.safeGreen.withValues(alpha: 0.12)
                        : AppColors.surfaceGlass(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isCurrentGps
                          ? AppColors.safeGreen.withValues(alpha: 0.4)
                          : AppColors.borderGlass(context),
                      width: isCurrentGps ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.safeGreen.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location_rounded,
                          color: AppColors.safeGreen,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Current Location',
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: isCurrentGps ? AppColors.safeGreen : AppColors.primaryText(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isCurrentGps) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.safeGreen.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        color: AppColors.safeGreen,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Use your device\'s current GPS position',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.secondaryText(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(child: Divider(color: AppColors.dividerColor(context))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR SEARCH PLACE',
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context), letterSpacing: 0.5),
                  ),
                ),
                Expanded(child: Divider(color: AppColors.dividerColor(context))),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Option 2: Search Input Field ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputFill(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: AppColors.mutedText(context), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      autofocus: false,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context)),
                      decoration: InputDecoration(
                        hintText: 'Search starting place or address...',
                        hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText(context)),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (_) => _performDetailedGeocoding(),
                    ),
                  ),
                  if (hasSearchQuery)
                    GestureDetector(
                      onTap: () {
                        _searchCtrl.clear();
                        _onSearchChanged('');
                      },
                      child: const Icon(Icons.close_rounded, color: AppColors.textMuted, size: 18),
                    ),
                ],
              ),
            ),
          ),

          // Action tile for detailed geocoding search
          if (hasSearchQuery)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isGeocoding ? null : _performDetailedGeocoding,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        if (_isGeocoding)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                          )
                        else
                          const Icon(Icons.pin_drop_rounded, color: AppColors.accentCyan, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Search "${_searchCtrl.text.trim()}" as a place/address',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.accentCyan,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Resolves exact GPS coordinates for journey start',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.accentCyan, size: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_geocodingError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: AppColors.dangerRed, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _geocodingError!,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 6),

          // ── Search Results List ──
          Expanded(
            child: _isLoadingCatalogue
                ? const Center(child: CircularProgressIndicator(color: AppColors.accentCyan))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    children: [
                      // Geocoded Places
                      if (_geocodedResults.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            'Detailed Places (${_geocodedResults.length})',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 12,
                              color: const Color(0xFF00E676),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._geocodedResults.map((loc) => _buildTravelLocationTile(context, loc)),
                        const SizedBox(height: 12),
                        Divider(height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 10),
                      ],

                      // Official Locations
                      if (_filteredLocations.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                          child: Text(
                            'Locations Catalogue (${_filteredLocations.length})',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 12,
                              color: AppColors.blueAccent(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        ..._filteredLocations.map((loc) {
                          final travelLoc = TravelLocation.fromMetLocation(loc);
                          return _buildMetLocationTile(context, loc, travelLoc);
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelLocationTile(BuildContext context, TravelLocation loc) {
    const badgeColor = Color(0xFF00E676);

    return InkWell(
      onTap: () => _selectManualLocation(loc),
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
              child: const Icon(Icons.location_on_rounded, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.name,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.state,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: const Text(
                'Selected Origin',
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMetLocationTile(BuildContext context, MetLocation loc, TravelLocation travelLoc) {
    final badgeColor = AppColors.blueAccent(context);

    return InkWell(
      onTap: () => _selectManualLocation(travelLoc),
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
              child: Icon(Icons.location_city_rounded, color: badgeColor, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loc.formattedName,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    loc.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: badgeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                loc.categoryLabel,
                style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
          ],
        ),
      ),
    );
  }
}
