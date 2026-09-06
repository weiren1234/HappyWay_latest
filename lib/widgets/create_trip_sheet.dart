import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/travel_location.dart';
import '../models/trip_stop.dart';
import '../providers/auth_provider.dart';
import '../providers/location_provider.dart';
import '../providers/trip_provider.dart';
import '../screens/trip_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'auth_prompt_dialog.dart';
import 'origin_picker_sheet.dart';

class CreateTripSheet extends StatefulWidget {
  final PlannedTrip? initialTrip;
  final TravelLocation? initialDestination;

  const CreateTripSheet({
    super.key,
    this.initialTrip,
    this.initialDestination,
  });

  static Future<PlannedTrip?> show(
    BuildContext context, {
    PlannedTrip? initialTrip,
    TravelLocation? initialDestination,
  }) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isGuest) {
      AuthPromptDialog.show(context);
      return Future.value(null);
    }

    return showModalBottomSheet<PlannedTrip>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CreateTripSheet(
        initialTrip: initialTrip,
        initialDestination: initialDestination,
      ),
    );
  }

  @override
  State<CreateTripSheet> createState() => _CreateTripSheetState();
}

class _CreateTripSheetState extends State<CreateTripSheet> {
  late TextEditingController _nameController;
  late TextEditingController _notesController;
  late DateTime _startDate;
  late DateTime _endDate;

  String _originName = 'Current Location';
  double? _originLat;
  double? _originLng;

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (widget.initialTrip != null) {
      final trip = widget.initialTrip!;
      _nameController = TextEditingController(text: trip.tripName ?? trip.destinationName);
      _notesController = TextEditingController(text: trip.generalNote ?? trip.notes ?? '');
      _startDate = DateTime(trip.effectiveStartDate.year, trip.effectiveStartDate.month, trip.effectiveStartDate.day);
      _endDate = DateTime(trip.effectiveEndDate.year, trip.effectiveEndDate.month, trip.effectiveEndDate.day);
      _originName = trip.originName.isNotEmpty ? trip.originName : 'Current Location';
      _originLat = trip.originLatitude;
      _originLng = trip.originLongitude;
    } else {
      final defaultName = widget.initialDestination != null
          ? '${widget.initialDestination!.name} Trip'
          : '';
      _nameController = TextEditingController(text: defaultName);
      _notesController = TextEditingController();
      _startDate = today;
      _endDate = today.add(const Duration(days: 1));

      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locProvider.currentLocation != null) {
        _originLat = locProvider.currentLocation!.latitude;
        _originLng = locProvider.currentLocation!.longitude;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
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
          }
          return success;
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

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => _buildDatePickerTheme(child),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate;
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: now.add(const Duration(days: 365 * 2)),
      builder: (context, child) => _buildDatePickerTheme(child),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Widget _buildDatePickerTheme(Widget? child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isDark
            ? const ColorScheme.dark(
                primary: AppColors.accentCyan,
                onPrimary: Colors.black,
                surface: AppColors.backgroundCardDark,
                onSurface: Colors.white,
              )
            : const ColorScheme.light(
                primary: AppColors.weatherBlue,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black87,
              ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter a trip name.');
      return;
    }

    if (_endDate.isBefore(_startDate)) {
      setState(() => _errorMessage = 'End date cannot be before start date.');
      return;
    }

    final tripProvider = Provider.of<TripProvider>(context, listen: false);

    if (widget.initialTrip != null && widget.initialTrip!.id != null) {
      final existingStops = tripProvider.getStopsForTrip(widget.initialTrip!.id!);
      final outOfBounds = existingStops.where((s) =>
          s.visitDate.isBefore(_startDate) || s.visitDate.isAfter(_endDate)).toList();

      if (outOfBounds.isNotEmpty) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.cardBg(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: AppColors.borderGlass(context)),
            ),
            title: Text(
              'Date Range Warning',
              style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
            ),
            content: Text(
              '${outOfBounds.length} stop(s) fall outside the new date range. They will remain in the itinerary but may not match trip days.',
              style: TextStyle(color: AppColors.secondaryText(context), fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(context))),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentCyan,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Proceed'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final notes = _notesController.text.trim();

    if (widget.initialTrip != null) {
      final updated = widget.initialTrip!.copyWith(
        tripName: name,
        startDate: _startDate,
        endDate: _endDate,
        generalNote: notes.isEmpty ? null : notes,
        originName: _originName,
        originLatitude: _originLat,
        originLongitude: _originLng,
        travelDate: _startDate,
      );

      final success = await tripProvider.updateTrip(updated);
      if (!mounted) return;
      setState(() => _isSaving = false);

      if (success) {
        Navigator.pop(context, updated);
      } else {
        setState(() => _errorMessage = 'Failed to update trip. Please try again.');
      }
      return;
    }

    if (_originLat == null || _originLng == null) {
      setState(() => _errorMessage = 'Starting location coordinates have not resolved yet. Please tap Starting Location and select your location.');
      return;
    }

    final newTrip = PlannedTrip(
      tripName: name,
      startDate: _startDate,
      endDate: _endDate,
      generalNote: notes.isEmpty ? null : notes,
      destinationLocationId: widget.initialDestination?.id ?? '',
      destinationName: widget.initialDestination?.name ?? name,
      destinationState: widget.initialDestination?.state ?? '',
      destinationCategory: widget.initialDestination?.category ?? '',
      destinationLatitude: widget.initialDestination?.latitude,
      destinationLongitude: widget.initialDestination?.longitude,
      travelDate: _startDate,
      originName: _originName,
      originLatitude: _originLat,
      originLongitude: _originLng,
      notes: notes.isEmpty ? null : notes,
      createdAt: DateTime.now(),
    );

    final created = await tripProvider.addTrip(newTrip);
    if (!mounted) return;

    if (created != null && created.id != null) {
      String? stopWarning;
      if (widget.initialDestination != null) {
        final stop1 = TripStop(
          tripId: created.id!,
          userId: created.userId ?? '',
          stopOrder: 1,
          locationId: widget.initialDestination!.id,
          locationName: widget.initialDestination!.name,
          state: widget.initialDestination!.state,
          category: widget.initialDestination!.category,
          latitude: widget.initialDestination!.latitude,
          longitude: widget.initialDestination!.longitude,
          visitDate: _startDate,
          timeMode: 'flexible',
          preferredPeriod: 'Morning',
          stayDurationMinutes: null,
          createdAt: DateTime.now(),
        );
        final addedStop = await tripProvider.addStop(created.id!, stop1);
        if (addedStop == null) {
          stopWarning = 'Trip created, but adding ${widget.initialDestination!.name} as Stop 1 failed. You can add it manually.';
        }
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      Navigator.pop(context, created);

      if (stopWarning != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(stopWarning),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TripDetailScreen(trip: created),
        ),
      );
    } else {
      setState(() {
        _isSaving = false;
        _errorMessage = tripProvider.errorMessage ?? 'Failed to create trip header. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialTrip != null;
    final totalDays = _endDate.difference(_startDate).inDays + 1;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 20,
        right: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.mutedText(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Trip' : 'Create Trip',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primaryText(context),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEditing ? 'Update trip itinerary header' : 'Plan your multi-day journey',
                      style: TextStyle(
                        color: AppColors.secondaryText(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: AppColors.secondaryText(context)),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerRed.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.dangerRed, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.dangerRed, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Text(
              'Trip Name',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: AppColors.primaryText(context), fontSize: 15),
              decoration: InputDecoration(
                hintText: 'e.g. Penang Food Tour, Cameron Getaway',
                hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 14),
                prefixIcon: Icon(Icons.map_rounded, color: AppColors.cyanAccent(context), size: 20),
                filled: true,
                fillColor: AppColors.surfaceGlass(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderGlass(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderGlass(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cyanAccent(context)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Start Date',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickStartDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.cyanAccent(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('d MMM yyyy').format(_startDate),
                                  style: TextStyle(
                                    color: AppColors.primaryText(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'End Date',
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _pickEndDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.event_available_rounded, size: 18, color: AppColors.cyanAccent(context)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('d MMM yyyy').format(_endDate),
                                  style: TextStyle(
                                    color: AppColors.primaryText(context),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                '$totalDays ${totalDays == 1 ? 'day' : 'days'} total itinerary',
                style: TextStyle(
                  color: AppColors.cyanAccent(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Starting Location',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openOriginPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.my_location_rounded, color: AppColors.cyanAccent(context), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _originName,
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText(context)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'General Note (Optional)',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 3,
              style: TextStyle(color: AppColors.primaryText(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Packing reminders, overall trip goals, budget notes...',
                hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
                filled: true,
                fillColor: AppColors.surfaceGlass(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderGlass(context)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.borderGlass(context)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: AppColors.cyanAccent(context)),
                ),
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      isEditing ? 'Save Changes' : 'Create Trip',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
