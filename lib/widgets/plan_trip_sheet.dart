import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/travel_location.dart';
import '../providers/trip_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'origin_picker_sheet.dart';
import 'destination_picker_sheet.dart';

/// PlanTripSheet presents the modal bottom sheet form to plan a new trip or edit an existing one.
/// Supports both pre-selected destinations (from Explore / Destination Detail / Saved)
/// and internal destination picking (from Trips FAB) with strict coordinate & MET ID separation.
class PlanTripSheet extends StatefulWidget {
  final TravelLocation? initialDestination;
  final PlannedTrip? initialTrip; // If editing

  // Backwards compatibility / convenience fields if passed directly
  final String? destinationLocationId;
  final String? destinationName;
  final String? destinationState;
  final String? destinationCategory;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationImageUrl;

  const PlanTripSheet({
    super.key,
    this.initialDestination,
    this.initialTrip,
    this.destinationLocationId,
    this.destinationName,
    this.destinationState,
    this.destinationCategory,
    this.destinationLatitude,
    this.destinationLongitude,
    this.destinationImageUrl,
  });

  /// Static helper to show the sheet easily from any screen.
  static Future<PlannedTrip?> show(
    BuildContext context, {
    TravelLocation? initialDestination,
    PlannedTrip? initialTrip,
    String? destinationLocationId,
    String? destinationName,
    String? destinationState,
    String? destinationCategory,
    double? destinationLatitude,
    double? destinationLongitude,
    String? destinationImageUrl,
  }) {
    return showModalBottomSheet<PlannedTrip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlanTripSheet(
        initialDestination: initialDestination,
        initialTrip: initialTrip,
        destinationLocationId: destinationLocationId,
        destinationName: destinationName,
        destinationState: destinationState,
        destinationCategory: destinationCategory,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
        destinationImageUrl: destinationImageUrl,
      ),
    );
  }

  @override
  State<PlanTripSheet> createState() => _PlanTripSheetState();
}

class _PlanTripSheetState extends State<PlanTripSheet> {
  TravelLocation? _selectedDestination;
  String? _destinationError;

  late DateTime _selectedDate;
  late String _selectedPeriod;
  late TextEditingController _notesController;

  // Origin Location
  String _originName = 'Current Location';
  double? _originLat;
  double? _originLng;

  bool _isSaving = false;

  final List<String> _periods = [
    'Morning',
    'Afternoon',
    'Night',
    'Auto Recommend',
  ];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();

    if (widget.initialTrip != null) {
      final trip = widget.initialTrip!;
      _selectedDate = trip.travelDate;
      _selectedPeriod = trip.preferredPeriod;
      _notesController = TextEditingController(text: trip.notes ?? '');
      _originName = trip.originName;
      _originLat = trip.originLatitude;
      _originLng = trip.originLongitude;

      // Construct destination from initial trip
      final hasMet = trip.destinationLocationId.startsWith('LOCATION:');
      _selectedDestination = TravelLocation(
        id: trip.destinationLocationId.isNotEmpty ? trip.destinationLocationId : 'trip:${trip.id}',
        name: trip.destinationName,
        state: trip.destinationState,
        category: trip.destinationCategory,
        latitude: trip.destinationLatitude ?? 0.0,
        longitude: trip.destinationLongitude ?? 0.0,
        source: hasMet ? TravelLocationSource.metLocation : TravelLocationSource.geocodedPlace,
        metLocationId: hasMet ? trip.destinationLocationId : null,
        metLocationName: hasMet ? trip.destinationName : null,
        imageUrl: trip.destinationImageUrl,
      );
    } else if (widget.initialDestination != null) {
      _selectedDestination = widget.initialDestination;
      _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _selectedPeriod = 'Morning';
      _notesController = TextEditingController();
    } else if (widget.destinationName != null && widget.destinationName!.isNotEmpty) {
      final hasMet = (widget.destinationLocationId ?? '').startsWith('LOCATION:');
      _selectedDestination = TravelLocation(
        id: widget.destinationLocationId ?? 'dest:${widget.destinationName}',
        name: widget.destinationName!,
        state: widget.destinationState ?? 'Malaysia',
        category: widget.destinationCategory ?? 'Destination',
        latitude: widget.destinationLatitude ?? 0.0,
        longitude: widget.destinationLongitude ?? 0.0,
        source: hasMet ? TravelLocationSource.metLocation : TravelLocationSource.geocodedPlace,
        metLocationId: hasMet ? widget.destinationLocationId : null,
        metLocationName: hasMet ? widget.destinationName : null,
        imageUrl: widget.destinationImageUrl,
      );
      _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _selectedPeriod = 'Morning';
      _notesController = TextEditingController();
    } else {
      // Open without pre-selected destination
      _selectedDestination = null;
      _selectedDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _selectedPeriod = 'Morning';
      _notesController = TextEditingController();
    }

    // Initialize origin from LocationProvider if not editing
    if (widget.initialTrip == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final locProvider = Provider.of<LocationProvider>(context, listen: false);
        if (locProvider.currentLocation != null) {
          setState(() {
            _originName = locProvider.isGps
                ? 'Current Location'
                : locProvider.currentLocation!.name;
            _originLat = locProvider.currentLocation!.latitude;
            _originLng = locProvider.currentLocation!.longitude;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _openDestinationPicker() async {
    final selected = await showModalBottomSheet<TravelLocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DestinationPickerSheet(
        selectedLocationId: _selectedDestination?.id,
        onSelectTravelLocation: (loc) {
          // Handled via Navigator.pop(context, loc)
        },
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedDestination = selected;
        _destinationError = null; // Clear validation error immediately on selection
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final maxDate = today.add(const Duration(days: 365));

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: maxDate,
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _openOriginPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OriginPickerSheet(
        onSelectCurrentLocation: () {
          final locProvider = Provider.of<LocationProvider>(context, listen: false);
          locProvider.selectCurrentLocation();
          if (locProvider.currentLocation != null) {
            setState(() {
              _originName = 'Current Location';
              _originLat = locProvider.currentLocation!.latitude;
              _originLng = locProvider.currentLocation!.longitude;
            });
          }
        },
        onSelectTravelLocation: (loc) {
          setState(() {
            _originName = loc.name;
            _originLat = loc.latitude;
            _originLng = loc.longitude;
          });
        },
      ),
    );
  }

  Future<void> _saveTrip() async {
    // Validate destination selection
    if (_selectedDestination == null) {
      setState(() {
        _destinationError = 'Please select a destination.';
      });
      return;
    }

    setState(() => _isSaving = true);

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final isEdit = widget.initialTrip != null;
    final dest = _selectedDestination!;

    // Resolve official MET location ID safely (never use geo: ID as fallback)
    String effectiveMetId = '';
    if (dest.metLocationId != null && dest.metLocationId!.isNotEmpty) {
      effectiveMetId = dest.metLocationId!;
    } else if (dest.id.startsWith('LOCATION:')) {
      effectiveMetId = dest.id;
    } else if (dest.id.startsWith('met:LOCATION:')) {
      effectiveMetId = dest.id.substring(4);
    }

    if (effectiveMetId.startsWith('met:')) {
      effectiveMetId = effectiveMetId.substring(4);
    }

    final trip = PlannedTrip(
      id: widget.initialTrip?.id,
      destinationLocationId: effectiveMetId,
      destinationName: dest.name,
      destinationState: dest.state,
      destinationCategory: dest.category,
      destinationLatitude: dest.latitude,
      destinationLongitude: dest.longitude,
      destinationImageUrl: dest.imageUrl,
      travelDate: _selectedDate,
      originName: _originName,
      originLatitude: _originLat,
      originLongitude: _originLng,
      preferredPeriod: _selectedPeriod,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      createdAt: isEdit ? widget.initialTrip!.createdAt : DateTime.now(),
    );

    if (isEdit) {
      await tripProvider.updateTrip(trip);
    } else {
      await tripProvider.addTrip(trip);
    }

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.pop(context, trip);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isEdit ? 'Trip updated successfully!' : 'Trip to ${dest.name} added to My Trips!',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context)),
        ),
        backgroundColor: AppColors.cardBg(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initialTrip != null;
    final formattedDate = DateFormat('EEEE, d MMMM yyyy').format(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.borderGlass(context), width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedText(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.weatherBlue.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.luggage_rounded, color: AppColors.cyanAccent(context), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEdit ? 'Edit Trip' : 'Plan This Trip',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 18,
                        color: AppColors.primaryText(context),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.mutedText(context)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ── Destination Selection Box ────────────────────────────────────
            Text('Destination (To)', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 6),
            if (_selectedDestination != null)
              GlassCard(
                padding: const EdgeInsets.all(12),
                borderColor: AppColors.cyanAccent(context).withValues(alpha: 0.3),
                backgroundColor: AppColors.cyanAccent(context).withValues(alpha: 0.05),
                child: Row(
                  children: [
                    Icon(Icons.location_on_rounded, color: AppColors.cyanAccent(context), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedDestination!.name,
                            style: AppTextStyles.titleSmall.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText(context),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${_selectedDestination!.state} • ${_selectedDestination!.category}',
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_selectedDestination!.hasWeatherLocation)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceGlass(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.borderGlass(context)),
                        ),
                        child: Text('Official MET', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                    TextButton(
                      onPressed: _openDestinationPicker,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Change',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: _openDestinationPicker,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGlass(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _destinationError != null ? AppColors.dangerRed : AppColors.borderGlass(context),
                          width: _destinationError != null ? 1.2 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.add_location_alt_outlined,
                            color: _destinationError != null ? AppColors.dangerRed : AppColors.mutedText(context),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select a destination...',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: _destinationError != null ? AppColors.dangerRed : AppColors.mutedText(context),
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
                        ],
                      ),
                    ),
                  ),
                  if (_destinationError != null) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        _destinationError!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerRed, fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            const SizedBox(height: 16),

            // ── Travel Date Picker ──────────────────────────────────────────
            Text('Travel Date', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 6),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppColors.cyanAccent(context), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        formattedDate,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.mutedText(context), size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Starting Location ───────────────────────────────────────────
            Text('Starting Location (From)', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 6),
            InkWell(
              onTap: _openOriginPicker,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, color: AppColors.safeGreen, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _originName,
                        style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
                      ),
                    ),
                    Text(
                      'Change',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Preferred Travel Period ─────────────────────────────────────
            Text('Preferred Travel Period', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _periods.map((period) {
                final isSelected = _selectedPeriod == period;
                return ChoiceChip(
                  label: Text(period),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedPeriod = period),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.secondaryText(context),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  backgroundColor: AppColors.surfaceGlass(context),
                  selectedColor: AppColors.blueAccent(context),
                  side: BorderSide(color: isSelected ? AppColors.cyanAccent(context) : AppColors.borderGlass(context)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // ── Personal Notes ──────────────────────────────────────────────
            Text('Personal Trip Notes (Optional)', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context)),
              decoration: InputDecoration(
                hintText: 'e.g. Visit strawberry farm, check in by 3 PM...',
                hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context)),
                filled: true,
                fillColor: AppColors.inputFill(context),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.inputBorder(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.inputBorder(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.cyanAccent(context), width: 1.5),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // ── Save Button ─────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.weatherBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            isEdit ? 'Save Changes' : 'Confirm & Plan Trip',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
