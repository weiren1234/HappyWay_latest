import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/travel_location.dart';
import '../providers/trip_provider.dart';
import '../providers/location_provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'origin_picker_sheet.dart';
import 'destination_picker_sheet.dart';
import '../models/travel_score.dart';
import '../models/travel_route.dart';
import '../models/weather_info.dart';
import '../services/route_service.dart';
import '../services/weather_service.dart';
import '../utils/travel_score_calculator.dart';
import '../main.dart' show navigatorKey, scaffoldMessengerKey;
import '../routes/app_routes.dart';

class PlanTripSheet extends StatefulWidget {
  final TravelLocation? initialDestination;
  final PlannedTrip? initialTrip;

  final String? destinationLocationId;
  final String? destinationName;
  final String? destinationState;
  final String? destinationCategory;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final String? destinationImageUrl;

  final DateTime? initialTravelDate;

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
    this.initialTravelDate,
  });

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
    DateTime? initialTravelDate,
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
        initialTravelDate: initialTravelDate,
      ),
    );
  }

  @override
  State<PlanTripSheet> createState() => _PlanTripSheetState();
}

class _PlanTripSheetState extends State<PlanTripSheet> {
  int _calcVersion = 0;
  TravelLocation? _selectedDestination;
  String? _destinationError;

  late DateTime _selectedDate;
  late String _selectedPeriod;
  late TextEditingController _notesController;

  String _originName = 'Current Location';
  double? _originLat;
  double? _originLng;

  bool _isSaving = false;

  final _weatherService = WeatherService();
  final _routeService = RouteService();
  WeatherInfo? _previewWeather;
  TravelRoute? _previewRoute;
  TravelScore? _previewScore;
  bool _isLoadingPreview = false;

  final List<String> _periods = [
    'Morning',
    'Afternoon',
    'Night',
    'Auto',
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

      _selectedDate = widget.initialTravelDate != null
          ? DateTime(widget.initialTravelDate!.year, widget.initialTravelDate!.month, widget.initialTravelDate!.day)
          : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
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

      _selectedDate = widget.initialTravelDate != null
          ? DateTime(widget.initialTravelDate!.year, widget.initialTravelDate!.month, widget.initialTravelDate!.day)
          : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _selectedPeriod = 'Morning';
      _notesController = TextEditingController();
    } else {

      _selectedDestination = null;
      _selectedDate = widget.initialTravelDate != null
          ? DateTime(widget.initialTravelDate!.year, widget.initialTravelDate!.month, widget.initialTravelDate!.day)
          : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
      _selectedPeriod = 'Morning';
      _notesController = TextEditingController();
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _recalculatePreview();
    });
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

        },
      ),
    );

    if (selected != null && mounted) {
      setState(() {
        _selectedDestination = selected;
        _destinationError = null;
      });
      _recalculatePreview();
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
      _recalculatePreview();
    }
  }

  Future<void> _recalculatePreview() async {
    final thisVersion = ++_calcVersion;
    final dest = _selectedDestination;
    if (dest == null ||
        ((dest.latitude == 0.0 && dest.longitude == 0.0) &&
            (dest.metLocationId == null || dest.metLocationId!.isEmpty))) {
      if (mounted && thisVersion == _calcVersion) {
        setState(() {
          _previewWeather = null;
          _previewRoute = null;
          _previewScore = null;
          _isLoadingPreview = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _isLoadingPreview = true);
    }

    if ((_originLat == null || _originLng == null) && mounted) {
      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locProvider.currentLocation != null) {
        _originName = locProvider.isGps ? 'Current Location' : locProvider.currentLocation!.name;
        _originLat = locProvider.currentLocation!.latitude;
        _originLng = locProvider.currentLocation!.longitude;
      }
    }

    try {
      WeatherInfo? weather;
      if (dest.latitude != 0.0 || dest.longitude != 0.0) {
        weather = await _weatherService.fetchWeatherForCoordinates(
          latitude: dest.latitude,
          longitude: dest.longitude,
          targetDate: _selectedDate,
          locationId: dest.metLocationId,
        );
      } else if (dest.metLocationId != null && dest.metLocationId!.isNotEmpty) {
        weather = await _weatherService.fetchWeatherForLocationAndDate(
          dest.metLocationId!,
          _selectedDate,
        );
      }

      if (thisVersion != _calcVersion || !mounted) return;

      TravelRoute? route;
      if (_originLat != null &&
          _originLng != null &&
          _originLat != 0.0 &&
          _originLng != 0.0 &&
          dest.latitude != 0.0 &&
          dest.longitude != 0.0) {
        try {
          final routeResult = await _routeService.calculateRouteDetails(
            originName: _originName,
            originLat: _originLat!,
            originLng: _originLng!,
            destName: dest.name,
            destLat: dest.latitude,
            destLng: dest.longitude,
          );
          route = routeResult.route;
        } catch (e) {
          debugPrint('[PlanTripSheet] Route calculation error: $e');
        }
      }

      if (thisVersion != _calcVersion || !mounted) return;

      final score = weather != null
          ? TravelScoreCalculator.calculateScore(
              weather: weather,
              route: route,
              preferredPeriod: _selectedPeriod,
              travelDate: _selectedDate,
            )
          : null;

      debugPrint('[PLAN WEATHER DEBUG] Recalculated preview: date=${DateFormat('yyyy-MM-dd').format(_selectedDate)}, origin=$_originName (${_originLat?.toStringAsFixed(3)}, ${_originLng?.toStringAsFixed(3)}), dest=${dest.name} (${dest.latitude.toStringAsFixed(3)}, ${dest.longitude.toStringAsFixed(3)}), routeDuration=${route?.durationFormatted ?? "none"}, score=${score?.score}');

      if (thisVersion != _calcVersion || !mounted) return;

      setState(() {
        _previewWeather = weather;
        _previewRoute = route;
        _previewScore = score;
        _isLoadingPreview = false;
      });
    } catch (_) {
      if (mounted && thisVersion == _calcVersion) {
        setState(() {
          _previewWeather = null;
          _previewRoute = null;
          _previewScore = null;
          _isLoadingPreview = false;
        });
      }
    }
  }

  void _openOriginPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OriginPickerSheet(
        onSelectCurrentLocation: () async {
          final locProvider = Provider.of<LocationProvider>(context, listen: false);
          final success = await locProvider.requestCurrentLocation(context);
          if (mounted && success) {
            setState(() {
              _originName = 'Current Location';
              if (locProvider.currentLocation != null) {
                _originLat = locProvider.currentLocation!.latitude;
                _originLng = locProvider.currentLocation!.longitude;
              }
            });
            _recalculatePreview();
          }
          return success;
        },
        onSelectTravelLocation: (loc) {
          setState(() {
            _originName = loc.name;
            _originLat = loc.latitude;
            _originLng = loc.longitude;
          });
          _recalculatePreview();
        },
      ),
    );
  }

  Future<void> _saveTrip() async {

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
      final success = await tripProvider.updateTrip(trip);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, trip);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trip updated successfully!',
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to update trip. Please try again.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      final createdTrip = await tripProvider.addTrip(trip);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (createdTrip != null) {

        final navProvider = Provider.of<NavigationProvider>(context, listen: false);
        navProvider.setTab(0);
        navigatorKey.currentState?.pushNamedAndRemoveUntil(AppRoutes.main, (route) => false);
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(
              'Trip planned successfully!',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.cardBg(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderGlass(context)),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to plan trip. Please check your connection and try again.'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEdit = widget.initialTrip != null;

    final isLocked = isEdit;
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

            Text('Starting Location (From)', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 6),
            InkWell(
              onTap: isLocked ? null : _openOriginPicker,
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
                    if (!isLocked)
                      Text(
                        'Change',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

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

                    if (!isLocked)
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

            Text('Preferred Travel Period', style: AppTextStyles.titleSmall.copyWith(fontSize: 13, color: AppColors.secondaryText(context))),
            const SizedBox(height: 4),
            Text(
              'Choose when you\'d like to start your journey.',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 12, color: AppColors.mutedText(context)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _periods.map((period) {
                final isSelected = _selectedPeriod == period;
                return ChoiceChip(
                  label: Text(period),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedPeriod = period);
                    _recalculatePreview();
                  },
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

            _buildLiveAnalysisPreview(context),
            const SizedBox(height: 16),

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

  Widget _buildDepartureTile(BuildContext context, TravelScore score) {
    final now = DateTime.now();
    final isToday = _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
    final datePrefix = isToday ? 'Today' : DateFormat('d MMM').format(_selectedDate);
    final departure = score.recommendedDeparture!;
    final departureWithDate = '$datePrefix · $departure';

    String? estimatedArrival;
    final reason = score.departureReason ?? '';
    final onMatch = RegExp(r'on (\d+ \w+) at (\d+:\d+ [AP]M)', caseSensitive: false).firstMatch(reason);
    if (onMatch != null) {
      estimatedArrival = '${onMatch.group(1)} · Around ${onMatch.group(2)}';
    } else if (_previewRoute != null) {
      final timeMatch = RegExp(r'(\d+):(\d+)\s*([AP]M)', caseSensitive: false).firstMatch(departure);
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        final min = int.parse(timeMatch.group(2)!);
        final isPm = timeMatch.group(3)!.toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        final depDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, hour, min);
        final arrDateTime = depDateTime.add(Duration(minutes: _previewRoute!.durationMinutes));
        if (arrDateTime.day != _selectedDate.day) {
          final arrDatePrefix = DateFormat('d MMM').format(arrDateTime);
          final arrTime = DateFormat('h:mm a').format(arrDateTime);
          estimatedArrival = '$arrDatePrefix · Around $arrTime';
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.inputFill(context),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.inputBorder(context)),
          ),
          child: Row(
            children: [
              Icon(Icons.departure_board_rounded, size: 15, color: AppColors.cyanAccent(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suggested Departure',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      departureWithDate,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.cyanAccent(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (estimatedArrival != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.inputFill(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.inputBorder(context)),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded, size: 15, color: AppColors.blueAccent(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estimated Arrival',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mutedText(context),
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        estimatedArrival,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.blueAccent(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLiveAnalysisPreview(BuildContext context) {

    if (_selectedDestination == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderGlass(context)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_outlined, color: AppColors.mutedText(context), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Select a destination to preview real-time travel suitability, best window, and trip advice.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingPreview) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderGlass(context)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.cyanAccent(context),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Analyzing hourly travel weather...',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 12),
            ),
          ],
        ),
      );
    }

    if (_previewScore != null) {
      final score = _previewScore!;
      final scoreColor = score.color;
      final route = _previewRoute;
      final isRouteComplete = route != null;

      final formattedDate = DateFormat('EEEE, d MMMM').format(_selectedDate);

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceGlass(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: scoreColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: scoreColor.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.cyanAccent(context), size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    isRouteComplete ? 'TRAVEL SUITABILITY PREVIEW' : 'WEATHER SUITABILITY PREVIEW',
                    style: AppTextStyles.badgeLabel.copyWith(
                      color: AppColors.cyanAccent(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 0.8,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),

            Text(
              formattedDate,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryText(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_previewWeather?.temperature != null)
                        Row(
                          children: [
                            Text(
                              '${_previewWeather!.temperature!.round()}°C',
                              style: TextStyle(
                                color: AppColors.primaryText(context),
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_previewWeather?.condition != null) ...[
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _previewWeather!.condition,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.secondaryText(context),
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      if (route != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          '${route.durationFormatted} • ${route.distanceFormatted}',
                          style: TextStyle(
                            color: AppColors.cyanAccent(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ] else ...[
                        const SizedBox(height: 2),
                        Text(
                          'Route unavailable — weather only',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: scoreColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: scoreColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${score.score}',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        '/100 · ${score.levelName}',
                        style: TextStyle(
                          color: scoreColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.inputBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              score.recommendedPeriod == 'Morning'
                                  ? Icons.wb_sunny_outlined
                                  : score.recommendedPeriod == 'Afternoon'
                                      ? Icons.wb_cloudy_outlined
                                      : Icons.nightlight_outlined,
                              size: 14,
                              color: AppColors.cyanAccent(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                score.recommendedPeriod ?? 'Auto',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText(context),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.inputFill(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.inputBorder(context)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best Departure Window',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: AppColors.cyanAccent(context),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                score.bestWeatherWindow ?? 'All day',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryText(context),
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            if (score.recommendedDeparture != null) ...[
              const SizedBox(height: 8),
              _buildDepartureTile(context, score),
            ],

            if (score.recommendation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                score.recommendation,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.secondaryText(context),
                  fontSize: 11.5,
                  height: 1.4,
                ),
              ),
            ],

            if (_selectedPeriod != 'Auto' &&
                score.recommendedPeriod != null &&
                _selectedPeriod != score.recommendedPeriod) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.cautionAmber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.cautionAmber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.cautionAmber),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tip: ${score.recommendedPeriod} has better forecast conditions than $_selectedPeriod.',
                        style: const TextStyle(color: AppColors.cautionAmber, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, color: AppColors.mutedText(context), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Forecast unavailable for this destination and date.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
