import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/itinerary_analysis.dart';
import '../models/planned_trip.dart';
import '../models/trip_stop.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../providers/location_provider.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/canonical_destination_id.dart';
import '../utils/itinerary_top_score_deriver.dart';
import '../widgets/add_stop_sheet.dart';
import '../widgets/create_trip_sheet.dart';
import '../widgets/destination_picker_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/hourly_weather_sheet.dart';

class TripDetailScreen extends StatefulWidget {
  final PlannedTrip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late PlannedTrip _trip;

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTripData();
    });
  }

  Future<void> _loadTripData({bool forceRefresh = false}) async {
    if (_trip.id != null && mounted) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      await tripProvider.loadStopsForTrip(_trip.id!, force: forceRefresh);
      await tripProvider.loadDaySettingsForTrip(_trip.id!, force: forceRefresh);
      if (_trip.destinationLocationId.isNotEmpty ||
          (_trip.destinationLatitude != null && _trip.destinationLongitude != null)) {
        await tripProvider.calculateScoreForPlannedTrip(
          _trip,
          forceRefresh: forceRefresh,
          sourceScreen: 'TripDetail',
        );
      }
      unawaited(tripProvider.analyzeItineraryForTrip(_trip.id!, forceRefresh: forceRefresh));
    }
  }

  void _editTripHeader() async {
    final updated = await CreateTripSheet.show(
      context,
      initialTrip: _trip,
    );

    if (updated != null && mounted) {
      setState(() => _trip = updated);
      _loadTripData(forceRefresh: true);
    }
  }

  void _openAddStop({DateTime? defaultVisitDate}) async {
    final created = await AddStopSheet.show(
      context,
      trip: _trip,
      defaultVisitDate: defaultVisitDate,
    );
    if (created != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${created.locationName}" to itinerary', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.safeGreen.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _editStop(TripStop stop) async {
    final updated = await AddStopSheet.show(
      context,
      trip: _trip,
      initialStop: stop,
    );
    if (updated != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated "${updated.locationName}"', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.safeGreen.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _deleteStop(TripStop stop) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Text(
          'Delete Stop?',
          style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to remove "${stop.locationName}" from your itinerary?',
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
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && stop.id != null && _trip.id != null) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      await tripProvider.deleteStop(_trip.id!, stop.id!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Removed "${stop.locationName}"', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.cardBg(context),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppColors.borderGlass(context)),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _reorderStopInDay(DateTime dayDate, List<TripStop> dayStops, int oldIndex, int newIndex) async {
    if (newIndex < 0 || newIndex >= dayStops.length || oldIndex == newIndex) return;
    final item = dayStops.removeAt(oldIndex);
    dayStops.insert(newIndex, item);

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    await tripProvider.reorderStopsForDay(_trip.id!, dayDate, dayStops);
  }

  void _editStopNote(TripStop stop) async {
    final controller = TextEditingController(text: stop.note ?? '');
    final updatedNote = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Row(
          children: [
            Icon(Icons.note_alt_outlined, color: AppColors.cyanAccent(context), size: 20),
            const SizedBox(width: 8),
            Text(
              stop.note != null && stop.note!.trim().isNotEmpty ? 'Edit Note' : 'Add Note',
              style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 3,
          style: TextStyle(color: AppColors.primaryText(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Add a personal note (e.g. Try specialty dish, note booking details)...',
            hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceGlass(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderGlass(context)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedNote != null && mounted) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final updated = stop.copyWith(note: updatedNote.isEmpty ? null : updatedNote);
      await tripProvider.updateStop(updated);
    }
  }

  void _openEditGeneralNotesDialog() async {
    final controller = TextEditingController(text: _trip.effectiveGeneralNote ?? '');
    final updatedNote = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Row(
          children: [
            Icon(Icons.notes_rounded, color: AppColors.cyanAccent(context), size: 20),
            const SizedBox(width: 8),
            Text(
              _trip.effectiveGeneralNote != null && _trip.effectiveGeneralNote!.trim().isNotEmpty
                  ? 'Edit Trip Note'
                  : 'Add Trip Note',
              style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: AppColors.primaryText(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Record general activities, packing reminders, or travel notes...',
            hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceGlass(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderGlass(context)),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedNote != null && mounted) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final newTrip = _trip.copyWith(
        generalNote: updatedNote.isEmpty ? null : updatedNote,
        notes: updatedNote.isEmpty ? null : updatedNote,
      );
      final success = await tripProvider.updateTrip(newTrip);
      if (success && mounted) {
        setState(() => _trip = newTrip);
      }
    }
  }

  void _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Text('Delete Trip?', style: TextStyle(color: AppColors.primaryText(context))),
        content: Text(
          'Are you sure you want to delete "${_trip.displayTitle}"? All itinerary stops will also be removed.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && _trip.id != null) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      await tripProvider.deleteTrip(_trip.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip "${_trip.displayTitle}" deleted.', style: TextStyle(color: AppColors.primaryText(context))),
            backgroundColor: AppColors.cardBg(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  List<DateTime> _generateTripDays() {
    final start = DateTime(
      _trip.effectiveStartDate.year,
      _trip.effectiveStartDate.month,
      _trip.effectiveStartDate.day,
    );
    final end = DateTime(
      _trip.effectiveEndDate.year,
      _trip.effectiveEndDate.month,
      _trip.effectiveEndDate.day,
    );

    final List<DateTime> days = [];
    DateTime cur = start;
    while (!cur.isAfter(end)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days.isNotEmpty ? days : [start];
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final tripId = _trip.id;

    final stops = tripId != null ? tripProvider.getStopsForTrip(tripId) : <TripStop>[];
    final isStopsLoading = tripId != null ? tripProvider.isStopsLoading(tripId) : false;
    final travelScore = tripId != null ? tripProvider.scoreForTrip(tripId) : null;
    final route = tripId != null ? tripProvider.routeForTrip(tripId) : null;
    final itineraryAnalysis = tripId != null ? tripProvider.getItineraryAnalysis(tripId) : null;
    final isAnalysisLoading = tripId != null ? tripProvider.isItineraryAnalysisLoading(tripId) : false;
    final tripDays = _generateTripDays();

    TravelScore? effectiveScore;
    TravelRoute? effectiveRoute;
    ItineraryStopAnalysis? firstStopAnalysis;

    if (stops.isNotEmpty && itineraryAnalysis != null && itineraryAnalysis.days.isNotEmpty) {
      for (final day in itineraryAnalysis.days) {
        if (day.stops.isNotEmpty) {
          firstStopAnalysis = day.stops.first;
          break;
        }
      }

      if (firstStopAnalysis != null) {
        effectiveScore = ItineraryTopScoreDeriver.derive(
          trip: _trip,
          firstStopAnalysis: firstStopAnalysis,
          totalStops: stops.length,
          fallbackScore: travelScore,
        );
        effectiveRoute = (firstStopAnalysis.routeFromPrevious != null &&
                firstStopAnalysis.routeFromPrevious!.isRouteAvailable &&
                firstStopAnalysis.routeFromPrevious!.route != null)
            ? firstStopAnalysis.routeFromPrevious!.route
            : route;
      } else {
        effectiveScore = travelScore;
        effectiveRoute = route;
      }
    } else {
      effectiveScore = travelScore;
      effectiveRoute = route;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddStop(),
        backgroundColor: AppColors.accentCyan,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_location_alt_rounded, size: 20),
        label: const Text(
          'Add Stop',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.scaffoldBg(context),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Icon(Icons.arrow_back_rounded, color: AppColors.primaryText(context), size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              _trip.displayTitle,
              style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Icon(Icons.refresh_rounded, color: AppColors.primaryText(context), size: 18),
                ),
                tooltip: 'Refresh',
                onPressed: () => _loadTripData(forceRefresh: true),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Icon(Icons.edit_outlined, color: AppColors.primaryText(context), size: 18),
                ),
                tooltip: 'Edit Trip',
                onPressed: _editTripHeader,
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed, size: 18),
                ),
                tooltip: 'Delete Trip',
                onPressed: _deleteTrip,
              ),
              const SizedBox(width: 8),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTripHeaderCard(),
                  const SizedBox(height: 16),

                  if (effectiveScore != null) ...[
                    _buildTravelScoreCard(effectiveScore, effectiveRoute),
                    const SizedBox(height: 16),
                  ],

                  if (_trip.effectiveGeneralNote != null && _trip.effectiveGeneralNote!.trim().isNotEmpty) ...[
                    _buildGeneralNoteCard(),
                    const SizedBox(height: 16),
                  ],

                  if (isStopsLoading && stops.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          children: [
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.accentCyan),
                            ),
                            const SizedBox(height: 12),
                            Text('Loading itinerary...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
                          ],
                        ),
                      ),
                    )
                  else if (stops.isEmpty)
                    _buildEmptyState()
                  else
                    ...tripDays.asMap().entries.map((entry) {
                      final dayIndex = entry.key + 1;
                      final dayDate = entry.value;
                      final dayStops = stops.where((s) =>
                          s.visitDate.year == dayDate.year &&
                          s.visitDate.month == dayDate.month &&
                          s.visitDate.day == dayDate.day).toList();
                      dayStops.sort((a, b) => a.stopOrder.compareTo(b.stopOrder));

                      final dayAnalysis = itineraryAnalysis?.days.firstWhere(
                        (d) => d.dayDate.year == dayDate.year &&
                            d.dayDate.month == dayDate.month &&
                            d.dayDate.day == dayDate.day,
                        orElse: () => ItineraryDayAnalysis(
                          dayIndex: dayIndex,
                          dayDate: dayDate,
                          stops: [],
                          segments: [],
                        ),
                      );

                      return _buildDaySection(
                        dayIndex,
                        dayDate,
                        dayStops,
                        dayAnalysis: dayAnalysis,
                        isAnalysisLoading: isAnalysisLoading,
                      );
                    }),

                  const SizedBox(height: 24),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeaderCard() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentCyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.luggage_rounded, color: AppColors.accentCyan, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trip.displayTitle,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primaryText(context),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_trip.dateRangeText} • ${_trip.totalDays} ${_trip.totalDays == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        color: AppColors.cyanAccent(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.near_me_rounded, size: 15, color: AppColors.mutedText(context)),
              const SizedBox(width: 6),
              Text(
                'Starting point: ',
                style: TextStyle(color: AppColors.mutedText(context), fontSize: 12),
              ),
              Expanded(
                child: Text(
                  _trip.originName.isNotEmpty ? _trip.originName : 'Current Location',
                  style: TextStyle(
                    color: AppColors.primaryText(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralNoteCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notes_rounded, color: AppColors.cyanAccent(context), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Trip Notes',
                    style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _openEditGeneralNotesDialog,
                child: Text(
                  'Edit',
                  style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _trip.effectiveGeneralNote!,
            style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass(context),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.borderGlass(context)),
            ),
            child: Icon(Icons.add_location_alt_outlined, size: 40, color: AppColors.cyanAccent(context)),
          ),
          const SizedBox(height: 18),
          Text(
            'Start building your itinerary',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primaryText(context),
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add places, visit times and notes to plan your trip.',
            style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13, height: 1.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () => _openAddStop(defaultVisitDate: _trip.effectiveStartDate),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add First Stop', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentCyan,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySection(
    int dayIndex,
    DateTime dayDate,
    List<TripStop> dayStops, {
    ItineraryDayAnalysis? dayAnalysis,
    bool isAnalysisLoading = false,
  }) {
    final dayLabel = 'DAY $dayIndex · ${DateFormat('d MMM').format(dayDate).toUpperCase()}';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.accentCyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dayLabel,
                    style: TextStyle(
                      color: AppColors.cyanAccent(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openAddStop(defaultVisitDate: dayDate),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.add_rounded, size: 14, color: AppColors.cyanAccent(context)),
                      const SizedBox(width: 4),
                      Text(
                        'Add Stop',
                        style: TextStyle(
                          color: AppColors.cyanAccent(context),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildDayStartingPointCard(dayIndex, dayDate),
          const SizedBox(height: 10),

          if (dayStops.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF141C2B)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF232F46)
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.05,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No stops scheduled for Day $dayIndex yet.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            ...dayStops.asMap().entries.expand((entry) {
              final stopIdx = entry.key;
              final stop = entry.value;
              final isLast = stopIdx == dayStops.length - 1;

              final stopAnalysis = dayAnalysis?.stops.firstWhere(
                (s) => s.stop.id == stop.id,
                orElse: () => ItineraryStopAnalysis(
                  stop: stop,
                  isWeatherAvailable: false,
                ),
              );

              final segment = stopAnalysis?.routeFromPrevious;

              return [
                if (segment != null && segment.isRouteAvailable)
                  _buildSegmentConnector(segment),
                _buildStopTimelineItem(
                  stop: stop,
                  stopAnalysis: stopAnalysis,
                  isFirst: stopIdx == 0,
                  isLast: isLast,
                  canMoveUp: stopIdx > 0,
                  canMoveDown: stopIdx < dayStops.length - 1,
                  onMoveUp: () => _reorderStopInDay(dayDate, dayStops, stopIdx, stopIdx - 1),
                  onMoveDown: () => _reorderStopInDay(dayDate, dayStops, stopIdx, stopIdx + 1),
                  isAnalysisLoading: isAnalysisLoading,
                ),
              ];
            }),
        ],
      ),
    );
  }

  Widget _buildDayStartingPointCard(int dayIndex, DateTime dayDate) {
    final tripProvider = Provider.of<TripProvider>(context);
    final tripId = _trip.id ?? 0;
    final allStops = tripProvider.getStopsForTrip(tripId);
    final effectiveStart = tripProvider.getEffectiveDayStart(tripId, dayDate, allStops, _trip);
    final customOverride = tripProvider.getDayStartingPoint(tripId, dayDate);
    final hasOverride = customOverride != null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    final cardBgColor = isDark ? const Color(0xFF141C2B) : Colors.white;
    final borderColor = hasOverride
        ? AppColors.cyanAccent(context).withValues(alpha: 0.7)
        : (isDark ? const Color(0xFF232F46) : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: borderColor,
          width: hasOverride ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (hasOverride ? AppColors.cyanAccent(context) : onSurfaceVariant).withValues(alpha: isDark ? 0.2 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.trip_origin_rounded,
              size: 16,
              color: hasOverride ? AppColors.cyanAccent(context) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'Starting Point',
                      style: TextStyle(
                        color: onSurfaceVariant,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (hasOverride) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentCyan.withValues(alpha: isDark ? 0.25 : 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Custom',
                          style: TextStyle(
                            color: AppColors.cyanAccent(context),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  effectiveStart.name,
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (effectiveStart.address != null &&
                    effectiveStart.address!.trim().isNotEmpty &&
                    effectiveStart.address!.trim() != effectiveStart.name.trim()) ...[
                  const SizedBox(height: 2),
                  Text(
                    effectiveStart.address!.trim(),
                    style: TextStyle(
                      color: onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _pickDayStartingPoint(dayDate),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.accentCyan.withValues(alpha: isDark ? 0.22 : 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.cyanAccent(context).withValues(alpha: 0.6),
                  width: 1.2,
                ),
              ),
              child: Text(
                'Change',
                style: TextStyle(
                  color: AppColors.cyanAccent(context),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _pickDayStartingPoint(DateTime dayDate) {
    final tripId = _trip.id;
    if (tripId == null) return;
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final allStops = tripProvider.getStopsForTrip(tripId);

    final uniqueTripStops = <TripStop>[];
    final seenKeys = <String>{};
    for (final s in allStops) {
      final key = (s.locationId != null && s.locationId!.isNotEmpty)
          ? CanonicalDestinationId.fromString(s.locationId!)
          : '${s.locationName.toLowerCase().trim()}_${s.latitude.toStringAsFixed(4)}_${s.longitude.toStringAsFixed(4)}';
      if (seenKeys.add(key)) {
        uniqueTripStops.add(s);
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final onSurface = Theme.of(ctx).colorScheme.onSurface;
        final onSurfaceVariant = Theme.of(ctx).colorScheme.onSurfaceVariant;
        final sheetCardBg = isDark ? const Color(0xFF172033) : const Color(0xFFF8FAFC);
        final sheetCardBorder = isDark ? const Color(0xFF26354D) : const Color(0xFFE2E8F0);

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: sheetCardBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Text(
                      'Choose Starting Point',
                      style: TextStyle(
                        color: onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: onSurfaceVariant, size: 20),
                      onPressed: () => Navigator.of(ctx).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () async {
                        Navigator.of(ctx).pop();
                        final locProvider = Provider.of<LocationProvider>(context, listen: false);
                        final success = await locProvider.requestCurrentLocation(context);
                        if (success && mounted) {
                          final userLoc = locProvider.currentLocation;
                          if (userLoc != null && _trip.id != null) {
                            await tripProvider.setDayStartingPoint(
                              _trip.id!,
                              dayDate,
                              'Current Location',
                              userLoc.latitude,
                              userLoc.longitude,
                              address: userLoc.reverseGeocodedAddress,
                            );
                          }
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: sheetCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.cyanAccent(ctx).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.my_location_rounded, size: 18, color: AppColors.cyanAccent(ctx)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Use GPS to detect where you are starting from',
                                    style: TextStyle(
                                      color: onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                    if (uniqueTripStops.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Text(
                          'TRIP PLACES',
                          style: TextStyle(
                            color: onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        decoration: BoxDecoration(
                          color: sheetCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCardBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: uniqueTripStops.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              thickness: 1,
                              indent: 48,
                              color: sheetCardBorder,
                            ),
                            itemBuilder: (context, index) {
                              final stop = uniqueTripStops[index];
                              final subtitle = stop.address?.trim().isNotEmpty == true
                                  ? stop.address!.trim()
                                  : (stop.state?.isNotEmpty == true ? stop.state! : null);

                              return InkWell(
                                onTap: () async {
                                  Navigator.of(ctx).pop();
                                  await tripProvider.setDayStartingPoint(
                                    tripId,
                                    dayDate,
                                    stop.locationName,
                                    stop.latitude,
                                    stop.longitude,
                                    locationId: stop.locationId,
                                    sourceType: stop.sourceType,
                                    address: stop.address,
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: onSurfaceVariant.withValues(alpha: isDark ? 0.2 : 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.place_outlined, size: 16, color: onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              stop.locationName,
                                              style: TextStyle(
                                                color: onSurface,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            if (subtitle != null) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                subtitle,
                                                style: TextStyle(
                                                  color: onSurfaceVariant,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right_rounded, size: 18, color: onSurfaceVariant),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (pickerCtx) => DestinationPickerSheet(
                            onSelectTravelLocation: (loc) {
                              tripProvider.setDayStartingPoint(
                                tripId,
                                dayDate,
                                loc.name,
                                loc.latitude,
                                loc.longitude,
                                locationId: loc.id,
                                sourceType: loc.source.toString(),
                                address: loc.formattedAddress,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: sheetCardBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sheetCardBorder),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.blueAccent(ctx).withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.search_rounded, size: 18, color: AppColors.blueAccent(ctx)),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Search Another Place',
                                    style: TextStyle(
                                      color: onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Search cities, towns, and attractions',
                                    style: TextStyle(
                                      color: onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 18, color: onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSegmentConnector(ItinerarySegmentAnalysis segment) {
    return Row(
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentCyan.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.18)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.directions_car_rounded, size: 13, color: AppColors.cyanAccent(context)),
                const SizedBox(width: 6),
                Text(
                  segment.summaryText,
                  style: TextStyle(
                    color: AppColors.cyanAccent(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStopTimelineItem({
    required TripStop stop,
    ItineraryStopAnalysis? stopAnalysis,
    required bool isFirst,
    required bool isLast,
    required bool canMoveUp,
    required bool canMoveDown,
    required VoidCallback onMoveUp,
    required VoidCallback onMoveDown,
    bool isAnalysisLoading = false,
  }) {
    final subtitleParts = [
      if (stop.state != null && stop.state!.isNotEmpty) stop.state!,
      if (stop.category != null && stop.category!.isNotEmpty) stop.category!,
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 18),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentCyan.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: AppColors.accentCyan.withValues(alpha: 0.25),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 14),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                borderRadius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.accentCyan.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            stop.displayTimeString,
                            style: TextStyle(
                              color: AppColors.cyanAccent(context),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (canMoveUp)
                              GestureDetector(
                                onTap: onMoveUp,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  margin: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.arrow_upward_rounded, size: 16, color: AppColors.secondaryText(context)),
                                ),
                              ),
                            if (canMoveDown)
                              GestureDetector(
                                onTap: onMoveDown,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  margin: const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.arrow_downward_rounded, size: 16, color: AppColors.secondaryText(context)),
                                ),
                              ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert_rounded, size: 18, color: AppColors.secondaryText(context)),
                              padding: EdgeInsets.zero,
                              color: AppColors.cardBg(context),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: AppColors.borderGlass(context)),
                              ),
                              onSelected: (val) {
                                if (val == 'edit') _editStop(stop);
                                if (val == 'delete') _deleteStop(stop);
                              },
                              itemBuilder: (ctx) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Edit Stop'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.dangerRed),
                                      SizedBox(width: 8),
                                      Text('Delete Stop', style: TextStyle(color: AppColors.dangerRed)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                      stop.locationName,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitleParts.join(' • '),
                        style: TextStyle(
                          color: AppColors.secondaryText(context),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),

                    if (stopAnalysis != null)
                      _buildStopIntelSection(stop, stopAnalysis, isAnalysisLoading),

                    if (stopAnalysis != null)
                      const SizedBox(height: 8),

                    if (stop.note != null && stop.note!.trim().isNotEmpty)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _editStopNote(stop),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.edit_note_rounded, size: 15, color: AppColors.cyanAccent(context)),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Note: ${stop.note!}',
                                  style: TextStyle(
                                    color: AppColors.primaryText(context),
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _editStopNote(stop),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.add_comment_outlined, size: 13, color: AppColors.mutedText(context)),
                                const SizedBox(width: 4),
                                Text(
                                  'Add note',
                                  style: TextStyle(
                                    color: AppColors.mutedText(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopIntelSection(
    TripStop stop,
    ItineraryStopAnalysis analysis,
    bool isAnalysisLoading,
  ) {
    if (isAnalysisLoading) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.cyanAccent(context),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Analysing...',
            style: TextStyle(color: AppColors.mutedText(context), fontSize: 11),
          ),
        ],
      );
    }

    final chips = <Widget>[];

    final arrivalLabel = stop.isExactTime
        ? analysis.plannedArrivalFormatted
        : analysis.recommendedArrivalFormatted;

    if (arrivalLabel != null) {
      final isRecommended = !stop.isExactTime;
      final chipColor = isRecommended ? AppColors.safeGreen : AppColors.cyanAccent(context);
      chips.add(_IntelChip(
        icon: isRecommended ? Icons.lightbulb_outline_rounded : Icons.access_time_rounded,
        label: isRecommended ? 'Recommended $arrivalLabel' : 'Planned $arrivalLabel',
        color: chipColor,
      ));
    }

    if (analysis.suggestedDepartureFormatted != null) {
      chips.add(_IntelChip(
        icon: Icons.departure_board_rounded,
        label: 'Depart ${analysis.suggestedDepartureFormatted?.replaceFirst('Around ', '') ?? ''}',
        color: AppColors.blueAccent(context),
      ));
    }

    if (analysis.estimatedArrivalFormatted != null) {
      chips.add(_IntelChip(
        icon: Icons.login_rounded,
        label: 'Est. Arrival ${analysis.estimatedArrivalFormatted?.replaceFirst('Around ', '') ?? ''}',
        color: AppColors.cyanAccent(context),
      ));
    }

    final weatherDesc = analysis.weatherDescriptionFormatted;
    final rainProb = analysis.rainProbabilityFormatted;
    final weatherLabel = (weatherDesc != null || rainProb != null)
        ? [weatherDesc, rainProb].whereType<String>().join(' · ')
        : (analysis.isWeatherAvailable ? null : 'Forecast not available yet');

    if (weatherLabel != null) {
      final suitability = analysis.weatherSuitability;
      Color weatherColor = AppColors.safeGreen;
      if (suitability != null) {
        if (suitability < 40) {
          weatherColor = AppColors.dangerRed;
        } else if (suitability < 65) {
          weatherColor = AppColors.cautionAmber;
        }
      } else if (!analysis.isWeatherAvailable) {
        weatherColor = AppColors.mutedText(context);
      }
      chips.add(_IntelChip(
        icon: Icons.wb_cloudy_outlined,
        label: weatherLabel,
        color: weatherColor,
        trailingIcon: Icons.chevron_right_rounded,
        onTap: () => HourlyWeatherSheet.show(context, stop: stop, analysis: analysis),
      ));
    }

    final conflictText = analysis.timingConflictText;
    final betterWindow = analysis.betterWeatherWindow;

    final hasConflict = analysis.hasTimingConflict && conflictText != null;
    final hasBetterWindow = betterWindow != null && betterWindow.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (chips.isNotEmpty) ...[
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: chips,
          ),
        ],

        if (hasConflict) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.dangerRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.dangerRed),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    conflictText,
                    style: TextStyle(
                      color: AppColors.dangerRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (hasBetterWindow) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cautionAmber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cautionAmber.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.wb_sunny_outlined, size: 14, color: AppColors.cautionAmber),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    betterWindow,
                    style: TextStyle(
                      color: AppColors.cautionAmber,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildTravelScoreCard(TravelScore score, TravelRoute? route) {
    final filteredBullets = score.explanationBullets.where((b) {
      final lower = b.toLowerCase();
      return !lower.contains('happyway') &&
          !lower.contains('algorithm') &&
          !lower.contains('preferred period') &&
          !lower.contains('matches happyway');
    }).toList();

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.explore_outlined, color: AppColors.cyanAccent(context), size: 17),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Travel Suitability',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: score.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    score.levelName,
                    style: TextStyle(
                      color: score.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Text(
                '${score.score}',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  color: score.color,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      score.consumerSummary,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primaryText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Out of 100 · Centralized Travel Score',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.mutedText(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (score.recommendedPeriod != null || score.bestWeatherWindow != null) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (score.recommendedPeriod != null)
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.wb_sunny_outlined,
                        label: 'Recommended Period',
                        value: score.recommendedPeriod!,
                        color: AppColors.cyanAccent(context),
                      ),
                    ),
                  if (score.recommendedPeriod != null && score.bestWeatherWindow != null)
                    const SizedBox(width: 8),
                  if (score.bestWeatherWindow != null)
                    Expanded(
                      child: _InfoTile(
                        icon: Icons.access_time_rounded,
                        label: 'Best Window',
                        value: score.bestWeatherWindow!,
                        color: AppColors.blueAccent(context),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (score.recommendedDeparture != null) ...[
            Builder(
              builder: (context) {
                final now = DateTime.now();
                final isToday = _trip.travelDate.year == now.year &&
                    _trip.travelDate.month == now.month &&
                    _trip.travelDate.day == now.day;
                final datePrefix = isToday ? 'Today' : DateFormat('d MMM').format(_trip.travelDate);
                final departureWithDate = '$datePrefix · ${score.recommendedDeparture}';

                String? estimatedArrival;
                final reason = score.departureReason ?? '';
                final onMatch = RegExp(r'on (\d+ \w+) at (\d+:\d+ [AP]M)', caseSensitive: false).firstMatch(reason);
                if (onMatch != null) {
                  estimatedArrival = '${onMatch.group(1)} · Around ${onMatch.group(2)}';
                } else if (route != null && score.recommendedDeparture != null) {
                  final timeMatch = RegExp(r'(\d+):(\d+)\s*([AP]M)', caseSensitive: false).firstMatch(score.recommendedDeparture!);
                  if (timeMatch != null) {
                    int hour = int.parse(timeMatch.group(1)!);
                    final min = int.parse(timeMatch.group(2)!);
                    final isPm = timeMatch.group(3)!.toUpperCase() == 'PM';
                    if (isPm && hour < 12) hour += 12;
                    if (!isPm && hour == 12) hour = 0;
                    final depDateTime = DateTime(_trip.travelDate.year, _trip.travelDate.month, _trip.travelDate.day, hour, min);
                    final arrDateTime = depDateTime.add(Duration(minutes: route.durationMinutes));
                    final isArrToday = arrDateTime.year == now.year &&
                        arrDateTime.month == now.month &&
                        arrDateTime.day == now.day;
                    final arrDatePrefix = isArrToday ? 'Today' : DateFormat('d MMM').format(arrDateTime);
                    final arrTime = DateFormat('h:mm a').format(arrDateTime);
                    estimatedArrival = '$arrDatePrefix · Around $arrTime';
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent(context).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.departure_board_rounded, color: AppColors.cyanAccent(context), size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Suggested Departure: $departureWithDate',
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.cyanAccent(context), fontWeight: FontWeight.w600, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (estimatedArrival != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: AppColors.blueAccent(context).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.blueAccent(context).withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded, color: AppColors.blueAccent(context), size: 14),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Estimated Arrival: $estimatedArrival',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],

          if (filteredBullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 10),
            ...filteredBullets.take(3).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(Icons.circle, size: 5, color: AppColors.cyanAccent(context)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          b.startsWith('• ') ? b.substring(2) : b,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Text(
        'Travel times and schedules are estimates. Suggested departure and arrival times are planning aids.',
        style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    label,
                    style: AppTextStyles.bodySmall.copyWith(
                      fontSize: 10,
                      color: AppColors.mutedText(context),
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTextStyles.bodyMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _IntelChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _IntelChip({
    required this.icon,
    required this.label,
    required this.color,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 3),
            Icon(trailingIcon!, size: 12, color: color),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: chip,
        ),
      );
    }

    return chip;
  }
}
