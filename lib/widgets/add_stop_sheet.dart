import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/trip_stop.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'destination_picker_sheet.dart';

class AddStopSheet extends StatefulWidget {
  final PlannedTrip trip;
  final TripStop? initialStop;
  final DateTime? defaultVisitDate;

  const AddStopSheet({
    super.key,
    required this.trip,
    this.initialStop,
    this.defaultVisitDate,
  });

  static Future<TripStop?> show(
    BuildContext context, {
    required PlannedTrip trip,
    TripStop? initialStop,
    DateTime? defaultVisitDate,
  }) {
    return showModalBottomSheet<TripStop>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddStopSheet(
        trip: trip,
        initialStop: initialStop,
        defaultVisitDate: defaultVisitDate,
      ),
    );
  }

  @override
  State<AddStopSheet> createState() => _AddStopSheetState();
}

class _AddStopSheetState extends State<AddStopSheet> {
  String? _locationId;
  String? _locationName;
  String? _state;
  String? _category;
  double _latitude = 0.0;
  double _longitude = 0.0;
  String? _metLocationId;
  String? _metLocationName;
  String? _sourceType;
  String? _address;

  late DateTime _visitDate;
  String _timeMode = 'exact';
  TimeOfDay _exactTime = const TimeOfDay(hour: 10, minute: 0);
  String _preferredPeriod = 'Morning';
  late TextEditingController _noteController;

  bool _isSaving = false;
  String? _errorMessage;

  final List<String> _periodOptions = ['Morning', 'Afternoon', 'Night', 'Auto'];

  @override
  void initState() {
    super.initState();
    if (widget.initialStop != null) {
      final s = widget.initialStop!;
      _locationId = s.locationId;
      _locationName = s.locationName;
      _state = s.state;
      _category = s.category;
      _latitude = s.latitude;
      _longitude = s.longitude;
      _metLocationId = s.metLocationId;
      _metLocationName = s.metLocationName;
      _sourceType = s.sourceType;
      _address = s.address;
      _visitDate = DateTime(s.visitDate.year, s.visitDate.month, s.visitDate.day);
      _timeMode = s.timeMode;
      _exactTime = s.arrivalTimeOfDay ?? const TimeOfDay(hour: 10, minute: 0);
      _preferredPeriod = s.preferredPeriod ?? 'Morning';
      _noteController = TextEditingController(text: s.note ?? '');
    } else {
      final tripStart = widget.trip.effectiveStartDate;
      final tripEnd = widget.trip.effectiveEndDate;
      DateTime candidate = widget.defaultVisitDate ?? tripStart;
      if (candidate.isBefore(tripStart)) candidate = tripStart;
      if (candidate.isAfter(tripEnd)) candidate = tripEnd;
      _visitDate = DateTime(candidate.year, candidate.month, candidate.day);
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _openDestinationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DestinationPickerSheet(
        selectedLocationId: _locationId,
        onSelectTravelLocation: (loc) {
          setState(() {
            _locationId = loc.id;
            _locationName = loc.name;
            _state = loc.state;
            _category = loc.category;
            _latitude = loc.latitude;
            _longitude = loc.longitude;
            _metLocationId = loc.metLocationId ?? (loc.id.startsWith('LOCATION:') ? loc.id : null);
            _metLocationName = loc.metLocationName ?? loc.name;
            _sourceType = loc.dbSourceType;
            _address = loc.formattedAddress ?? '${loc.name}, ${loc.state}';
            _errorMessage = null;
          });
        },
      ),
    );
  }

  Future<void> _pickVisitDate() async {
    final start = DateTime(
      widget.trip.effectiveStartDate.year,
      widget.trip.effectiveStartDate.month,
      widget.trip.effectiveStartDate.day,
    );
    final end = DateTime(
      widget.trip.effectiveEndDate.year,
      widget.trip.effectiveEndDate.month,
      widget.trip.effectiveEndDate.day,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate.isBefore(start) || _visitDate.isAfter(end) ? start : _visitDate,
      firstDate: start,
      lastDate: end,
      builder: (context, child) {
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
      },
    );

    if (picked != null && mounted) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  void _showTimeDrumPicker() {
    int selectedHour = _exactTime.hour;
    int selectedMinute = _exactTime.minute;

    final hourController = FixedExtentScrollController(initialItem: selectedHour);
    final minuteController = FixedExtentScrollController(initialItem: selectedMinute ~/ 5);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          decoration: BoxDecoration(
            color: AppColors.cardBg(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: AppColors.borderGlass(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.mutedText(context).withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Select Arrival Time',
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                child: StatefulBuilder(
                  builder: (ctx, setInnerState) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            controller: hourController,
                            itemExtent: 48,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setInnerState(() => selectedHour = index);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 24,
                              builder: (context, index) {
                                final isSelected = index == selectedHour;
                                final h = index % 12 == 0 ? 12 : index % 12;
                                final label = h.toString().padLeft(2, '0');
                                return Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.cyanAccent(context)
                                          : AppColors.secondaryText(context),
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Text(
                          ':',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: 70,
                          child: ListWheelScrollView.useDelegate(
                            controller: minuteController,
                            itemExtent: 48,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setInnerState(() => selectedMinute = index * 5);
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 12,
                              builder: (context, index) {
                                final isSelected = index * 5 == selectedMinute;
                                final label = (index * 5).toString().padLeft(2, '0');
                                return Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.cyanAccent(context)
                                          : AppColors.secondaryText(context),
                                      fontSize: isSelected ? 24 : 18,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: ListWheelScrollView.useDelegate(
                            controller: FixedExtentScrollController(
                              initialItem: _exactTime.period == DayPeriod.pm ? 1 : 0,
                            ),
                            itemExtent: 48,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setInnerState(() {
                                if (index == 0) {
                                  if (selectedHour >= 12) selectedHour -= 12;
                                } else {
                                  if (selectedHour < 12) selectedHour += 12;
                                }
                              });
                            },
                            childDelegate: ListWheelChildBuilderDelegate(
                              childCount: 2,
                              builder: (context, index) {
                                final label = index == 0 ? 'AM' : 'PM';
                                final currentPeriod = selectedHour < 12 ? 0 : 1;
                                final isSelected = index == currentPeriod;
                                return Center(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: isSelected
                                          ? AppColors.cyanAccent(context)
                                          : AppColors.secondaryText(context),
                                      fontSize: isSelected ? 22 : 16,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _exactTime = TimeOfDay(hour: selectedHour, minute: selectedMinute);
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatTimeToSql(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  String _formatTimeOfDayLabel(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _handleSave() async {
    if (_locationName == null || _locationName!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select a place or destination.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final tripId = widget.trip.id!;

    final plannedArrival = _timeMode == 'exact' ? _formatTimeToSql(_exactTime) : null;

    final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (widget.initialStop != null) {
      final updatedStop = widget.initialStop!.copyWith(
        locationId: _locationId,
        locationName: _locationName!,
        state: _state,
        category: _category,
        latitude: _latitude,
        longitude: _longitude,
        metLocationId: _metLocationId,
        metLocationName: _metLocationName,
        sourceType: _sourceType,
        address: _address,
        visitDate: _visitDate,
        timeMode: _timeMode,
        preferredPeriod: _timeMode == 'flexible' ? _preferredPeriod : null,
        plannedArrivalTime: plannedArrival,
        plannedDepartureTime: null,
        stayDurationMinutes: null,
        note: note,
      );

      final success = await tripProvider.updateStop(updatedStop);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (success) {
        Navigator.pop(context, updatedStop);
      } else {
        setState(() => _errorMessage = 'Failed to update stop. Please try again.');
      }
      return;
    }

    final existingStops = tripProvider.getStopsForTrip(tripId);
    final dayStops = existingStops.where((s) =>
        s.visitDate.year == _visitDate.year &&
        s.visitDate.month == _visitDate.month &&
        s.visitDate.day == _visitDate.day).toList();

    final nextOrder = dayStops.isEmpty
        ? 1
        : dayStops.map((s) => s.stopOrder).reduce((a, b) => a > b ? a : b) + 1;

    final newStop = TripStop(
      tripId: tripId,
      userId: widget.trip.userId ?? '',
      stopOrder: nextOrder,
      locationId: _locationId,
      locationName: _locationName!,
      state: _state,
      category: _category,
      latitude: _latitude,
      longitude: _longitude,
      metLocationId: _metLocationId,
      metLocationName: _metLocationName,
      sourceType: _sourceType,
      address: _address,
      visitDate: _visitDate,
      timeMode: _timeMode,
      preferredPeriod: _timeMode == 'flexible' ? _preferredPeriod : null,
      plannedArrivalTime: plannedArrival,
      plannedDepartureTime: null,
      stayDurationMinutes: null,
      note: note,
      createdAt: DateTime.now(),
    );

    final created = await tripProvider.addStop(tripId, newStop);
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (created != null) {
      Navigator.pop(context, created);
    } else {
      setState(() => _errorMessage = tripProvider.errorMessage ?? 'Failed to add stop. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.initialStop != null;

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
                      isEditing ? 'Edit Stop' : 'Add Stop',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primaryText(context),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add a place and schedule to your itinerary',
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
              'Destination / Place',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openDestinationPicker,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _locationName != null
                        ? AppColors.cyanAccent(context).withValues(alpha: 0.4)
                        : AppColors.borderGlass(context),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.place_rounded, color: AppColors.cyanAccent(context), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _locationName ?? 'Tap to select place',
                            style: TextStyle(
                              color: _locationName != null
                                  ? AppColors.primaryText(context)
                                  : AppColors.mutedText(context),
                              fontSize: 15,
                              fontWeight: _locationName != null ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (_state != null || _category != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (_state != null && _state!.isNotEmpty) _state!,
                                if (_category != null && _category!.isNotEmpty) _category!,
                              ].join(' • '),
                              style: TextStyle(
                                color: AppColors.secondaryText(context),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText(context)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Visit Date',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _pickVisitDate,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_rounded, color: AppColors.cyanAccent(context), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMMM yyyy').format(_visitDate),
                        style: TextStyle(
                          color: AppColors.primaryText(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.secondaryText(context)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Time Mode',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _timeMode = 'exact'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _timeMode == 'exact'
                            ? AppColors.accentCyan.withValues(alpha: 0.18)
                            : AppColors.surfaceGlass(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _timeMode == 'exact'
                              ? AppColors.accentCyan
                              : AppColors.borderGlass(context),
                          width: _timeMode == 'exact' ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Exact Time',
                          style: TextStyle(
                            color: _timeMode == 'exact'
                                ? AppColors.accentCyan
                                : AppColors.secondaryText(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _timeMode = 'flexible'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _timeMode == 'flexible'
                            ? AppColors.accentCyan.withValues(alpha: 0.18)
                            : AppColors.surfaceGlass(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _timeMode == 'flexible'
                              ? AppColors.accentCyan
                              : AppColors.borderGlass(context),
                          width: _timeMode == 'flexible' ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Flexible Window',
                          style: TextStyle(
                            color: _timeMode == 'flexible'
                                ? AppColors.accentCyan
                                : AppColors.secondaryText(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_timeMode == 'exact') ...[
              Text(
                'Planned Arrival Time',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _showTimeDrumPicker,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass(context),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.access_time_rounded, color: AppColors.cyanAccent(context), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _formatTimeOfDayLabel(_exactTime),
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(Icons.edit_rounded, size: 18, color: AppColors.secondaryText(context)),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Text(
                'Preferred Period',
                style: TextStyle(
                  color: AppColors.secondaryText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _periodOptions.map((period) {
                  final isSelected = _preferredPeriod == period;
                  return ChoiceChip(
                    label: Text(
                      period == 'Morning'
                          ? 'Morning (06:00–11:59)'
                          : period == 'Afternoon'
                              ? 'Afternoon (12:00–17:59)'
                              : period == 'Night'
                                  ? 'Night (18:00–23:59)'
                                  : 'Auto Window',
                      style: TextStyle(
                        color: isSelected ? Colors.black : AppColors.primaryText(context),
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.accentCyan,
                    backgroundColor: AppColors.surfaceGlass(context),
                    onSelected: (selected) {
                      if (selected) setState(() => _preferredPeriod = period);
                    },
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 16),

            Text(
              'Personal Note (Optional)',
              style: TextStyle(
                color: AppColors.secondaryText(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: TextStyle(color: AppColors.primaryText(context), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a personal note (e.g. Try specialty dish, buy tickets in advance)...',
                hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.cyanAccent(context), size: 20),
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
                      isEditing ? 'Update Stop' : 'Add to Itinerary',
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
