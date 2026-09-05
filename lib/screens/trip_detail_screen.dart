import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../models/planned_trip.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/plan_trip_sheet.dart';
import '../widgets/destination_image_view.dart';
import '../widgets/hourly_weather_card.dart';

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
      await tripProvider.calculateScoreForPlannedTrip(
        _trip,
        forceRefresh: forceRefresh,
        sourceScreen: 'TripDetail',
      );
    }
  }

  void _editTrip() async {
    final updated = await PlanTripSheet.show(
      context,
      destinationLocationId: _trip.destinationLocationId,
      destinationName: _trip.destinationName,
      destinationState: _trip.destinationState,
      destinationCategory: _trip.destinationCategory,
      destinationLatitude: _trip.destinationLatitude,
      destinationLongitude: _trip.destinationLongitude,
      destinationImageUrl: _trip.destinationImageUrl,
      initialTrip: _trip,
    );

    if (updated != null && mounted) {
      setState(() => _trip = updated);
      _loadTripData(forceRefresh: true);
    }
  }

  void _openEditNotesDialog() async {
    final controller = TextEditingController(text: _trip.notes ?? '');
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
              _trip.notes != null && _trip.notes!.trim().isNotEmpty ? 'Edit Note' : 'Add Note',
              style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          maxLines: 4,
          style: TextStyle(color: AppColors.primaryText(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Record activities, packing reminders, or travel notes...',
            hintStyle: TextStyle(color: AppColors.mutedText(context), fontSize: 13),
            filled: true,
            fillColor: AppColors.surfaceGlass(context),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderGlass(context)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.borderGlass(context)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.cyanAccent(context)),
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
              backgroundColor: AppColors.weatherBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updatedNote != null && mounted) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final newTrip = _trip.copyWith(notes: updatedNote.isEmpty ? null : updatedNote);
      final success = await tripProvider.updateTrip(newTrip);
      if (success && mounted) {
        setState(() => _trip = newTrip);
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: const Text('Note updated successfully', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.safeGreen.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
          ),
        );
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
          'Are you sure you want to delete your trip to ${_trip.destinationName} on ${_trip.formattedDate}?',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
            content: Text('Trip to ${_trip.destinationName} (${_trip.tripCode}) deleted.', style: TextStyle(color: AppColors.primaryText(context))),
            backgroundColor: AppColors.cardBg(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final tripId = _trip.id;

    final weather = tripId != null ? tripProvider.weatherForTrip(tripId) : null;
    final route = tripId != null ? tripProvider.routeForTrip(tripId) : null;
    final travelScore = tripId != null ? tripProvider.scoreForTrip(tripId) : null;
    final isScoreLoading = tripId != null ? tripProvider.isScoreLoadingForTrip(tripId) : false;
    final forecastStatus = tripId != null
        ? tripProvider.forecastStatusForTrip(tripId)
        : TripForecastStatus.pending;

    final hasImage = _trip.destinationImageUrl != null && _trip.destinationImageUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
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
            title: Text('Trip Details', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            centerTitle: true,
            actions: [
              if (isScoreLoading)
                const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                    ),
                  ),
                )
              else
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
                  tooltip: 'Refresh Forecast',
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
                onPressed: _editTrip,
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

                  if (hasImage)
                    _buildImageHeader()
                  else
                    _buildGradientHeader(),
                  const SizedBox(height: 16),

                  _buildOverviewCard(),
                  const SizedBox(height: 14),

                  _buildRouteCard(route, isScoreLoading),
                  const SizedBox(height: 14),

                  _buildForecastSection(weather, isScoreLoading, forecastStatus),
                  const SizedBox(height: 14),

                  if (isScoreLoading && travelScore == null && _trip.isWithinForecastRange && !_trip.isPast) ...[
                    _buildScoreLoadingCard(),
                    const SizedBox(height: 14),
                  ] else if (travelScore != null) ...[
                    _buildTravelScoreCard(travelScore, route),
                    const SizedBox(height: 14),
                  ],

                  _buildNotesCard(),
                  const SizedBox(height: 14),

                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          DestinationImageView(
            name: _trip.destinationName,
            state: _trip.destinationState,
            locationId: _trip.destinationLocationId,
            imageUrl: _trip.destinationImageUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
              ),
            ),
          ),
          Positioned(
            bottom: 14, left: 14, right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_trip.destinationState} • ${_trip.destinationCategory}',
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_trip.destinationName, style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.location_city_rounded, color: AppColors.cyanAccent(context), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_trip.destinationName, style: AppTextStyles.titleLarge.copyWith(fontSize: 20, color: AppColors.primaryText(context))),
                const SizedBox(height: 4),
                Text('${_trip.destinationState} • ${_trip.destinationCategory}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard() {
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
                    Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.blueAccent(context), borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Trip Schedule',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.cyanAccent(context).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _trip.tripCode,
                        style: TextStyle(
                          color: AppColors.cyanAccent(context),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _trip.isToday
                      ? AppColors.safeGreen.withValues(alpha: 0.2)
                      : _trip.isPast
                          ? AppColors.surfaceGlass(context)
                          : AppColors.weatherBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _trip.isToday
                        ? AppColors.safeGreen.withValues(alpha: 0.6)
                        : AppColors.borderGlass(context),
                  ),
                ),
                child: Text(
                  _trip.relativeDateLabel,
                  style: TextStyle(
                    color: _trip.isToday ? AppColors.safeGreen : (_trip.isPast ? AppColors.mutedText(context) : Colors.white),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.calendar_month_rounded,
                    label: 'Date',
                    value: _trip.formattedDate,
                    color: AppColors.blueAccent(context),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.access_time_rounded,
                    label: 'Preferred Period',
                    value: () {
                      final period = _trip.preferredPeriod;
                      if (period == 'Auto Recommend' || period == 'Auto') return 'Auto';
                      return '$period Trip';
                    }(),
                    color: AppColors.cyanAccent(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGlass(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, size: 14, color: AppColors.safeGreen),
                const SizedBox(width: 8),
                Text('Starting From: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context))),
                Expanded(
                  child: Text(
                    _trip.originName,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard(TravelRoute? route, bool isScoreLoading) {
    final hasCoordinates = _trip.originLatitude != null && _trip.destinationLatitude != null;

    if (!hasCoordinates && route == null && !isScoreLoading) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.cyanAccent(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Driving Route', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            ],
          ),
          const SizedBox(height: 12),

          if (isScoreLoading && route == null)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Calculating driving distance...',
                        style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (route != null) ...[
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.route_rounded,
                      label: 'Distance',
                      value: route.distanceFormatted,
                      color: AppColors.blueAccent(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _InfoTile(
                      icon: Icons.schedule_rounded,
                      label: 'Est. Drive Time',
                      value: route.durationFormatted,
                      color: AppColors.cyanAccent(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '* Estimated normal driving duration, not live traffic data',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildForecastSection(WeatherInfo? weather, bool isScoreLoading, TripForecastStatus forecastStatus) {
    if (_trip.isPast) {
      return const SizedBox.shrink();
    }

    if (!_trip.isWithinForecastRange) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.weatherBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, color: AppColors.cyanAccent(context), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Forecast Availability', style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                  const SizedBox(height: 4),
                  Text(
                    'Forecast not available yet. Weather forecasts will be available closer to your travel date on ${_trip.formattedDate}.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (isScoreLoading && weather == null) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  'Loading weather forecast...',
                  style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (weather == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.cautionAmber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Weather forecast currently unavailable for this date. Check network connection.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
              ),
            ),
            TextButton(
              onPressed: () => _loadTripData(forceRefresh: true),
              child: Text('Retry', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return HourlyWeatherCard(
      weather: weather,
      title: 'Weather',
    );
  }

  Widget _buildScoreLoadingCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'Calculating travel suitability...',
              style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: score.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: score.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${score.score}/100 • ${score.levelName}',
                  style: TextStyle(color: score.color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(score.consumerSummary, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), height: 1.4)),

          if (score.recommendedPeriod != null || score.bestWeatherWindow != null) ...[
            const SizedBox(height: 12),
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
          ],

          if (score.recommendedDeparture != null) ...[
            const SizedBox(height: 10),
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
                } else if (route != null) {
                  final timeMatch = RegExp(r'(\d+):(\d+)\s*([AP]M)', caseSensitive: false).firstMatch(score.recommendedDeparture ?? '');
                  if (timeMatch != null) {
                    int hour = int.parse(timeMatch.group(1)!);
                    final min = int.parse(timeMatch.group(2)!);
                    final isPm = timeMatch.group(3)!.toUpperCase() == 'PM';
                    if (isPm && hour < 12) hour += 12;
                    if (!isPm && hour == 12) hour = 0;
                    final depDateTime = DateTime(_trip.travelDate.year, _trip.travelDate.month, _trip.travelDate.day, hour, min);
                    final arrDateTime = depDateTime.add(Duration(minutes: route.durationMinutes));
                    if (arrDateTime.day != _trip.travelDate.day) {
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

  Widget _buildNotesCard() {
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
                    Icon(Icons.note_alt_outlined, color: AppColors.cyanAccent(context), size: 17),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        'Personal Notes',
                        style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openEditNotesDialog,
                child: Text(
                  _trip.notes != null && _trip.notes!.isNotEmpty ? 'Edit' : 'Add Note',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openEditNotesDialog,
            child: _trip.notes != null && _trip.notes!.isNotEmpty
                ? Text(
                    _trip.notes!,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context), height: 1.45),
                  )
                : Text(
                    'No personal notes added for this trip yet. Tap "Add Note" to record activities or packing reminders.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontStyle: FontStyle.italic),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Text(
        'Travel Suitability and Departure suggestions are based on forecast weather data. They are planning aids and do not constitute official statements.',
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
