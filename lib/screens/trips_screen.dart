import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../models/planned_trip.dart';
import '../models/travel_score.dart';
import '../models/weather_info.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../screens/trip_detail_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/destination_image_view.dart';
import '../widgets/glass_card.dart';
import '../widgets/header_section.dart';
import '../widgets/create_trip_sheet.dart';
import '../models/trip_stop.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  bool _hasTriggeredInitialLoad = false;

  @override
  void initState() {
    super.initState();
    _checkAndLoadTrips();
  }

  void _checkAndLoadTrips() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.isAuthenticated && tripProvider.trips.isEmpty && !tripProvider.isLoading) {
        _hasTriggeredInitialLoad = true;
        tripProvider.loadTrips();
      }
    });
  }

  Future<void> _handleDeleteTrip(BuildContext context, PlannedTrip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Text(
          'Delete Trip?',
          style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove your trip to ${trip.destinationName} on ${trip.formattedDate}?',
          style: TextStyle(color: AppColors.secondaryText(context), fontSize: 14, height: 1.4),
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
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted || trip.id == null) return;

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final tripId = trip.id!;
    final success = await tripProvider.deleteTrip(tripId);

    if (!context.mounted) return;

    if (!success) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: const Text('Failed to delete trip. Please try again.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.dangerRed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Trip removed',
            style: TextStyle(color: AppColors.primaryText(context), fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.cardBg(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderGlass(context)),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.cyanAccent(context),
            onPressed: () async {
              await tripProvider.addTrip(trip);
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tripProvider = Provider.of<TripProvider>(context);

    if (authProvider.isAuthenticated &&
        tripProvider.trips.isEmpty &&
        !tripProvider.isLoading &&
        tripProvider.errorMessage == null &&
        !_hasTriggeredInitialLoad) {
      _hasTriggeredInitialLoad = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) tripProvider.loadTrips();
      });
    }

    final todayTrips = tripProvider.todayTrips;
    final upcomingTrips = tripProvider.upcomingTrips;
    final pastTrips = tripProvider.pastTrips;
    final totalTrips = tripProvider.trips.length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: tripProvider.loadTrips,
          color: AppColors.accentCyan,
          backgroundColor: AppColors.backgroundCardDark,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            children: [

              HeaderSection(
                title: 'My Trips',
                subtitle: totalTrips > 0
                    ? '$totalTrips planned ${totalTrips == 1 ? 'trip' : 'trips'}'
                    : 'Weather-optimized travel itineraries',
                trailing: authProvider.isAuthenticated && !authProvider.isGuest
                    ? _buildPlanTripButton(context)
                    : null,
              ),

              const SizedBox(height: 16),

              if (authProvider.isGuest)
                _buildGuestWall(context)
              else if (!authProvider.isAuthenticated)
                _buildAuthPrompt(context)
              else if (tripProvider.isLoading && tripProvider.trips.isEmpty)
                _buildLoadingState()
              else if (tripProvider.errorMessage != null && tripProvider.trips.isEmpty)
                _buildErrorState(context, tripProvider)
              else if (tripProvider.trips.isEmpty)
                _buildEmptyState(context)
              else ...[

                if (todayTrips.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Today\'s Trips',
                    todayTrips.length,
                    AppColors.safeGreen,
                    Icons.today_rounded,
                  ),
                  const SizedBox(height: 12),
                  ...todayTrips.map((trip) => _buildTripItem(context, trip, tripProvider)),
                  const SizedBox(height: 16),
                ],

                if (upcomingTrips.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Upcoming Trips',
                    upcomingTrips.length,
                    AppColors.accentCyan,
                    Icons.upcoming_rounded,
                  ),
                  const SizedBox(height: 12),
                  ...upcomingTrips.map((trip) => _buildTripItem(context, trip, tripProvider)),
                  const SizedBox(height: 16),
                ],

                if (pastTrips.isNotEmpty) ...[
                  _buildSectionHeader(
                    'Past Trips',
                    pastTrips.length,
                    AppColors.textMuted,
                    Icons.history_rounded,
                  ),
                  const SizedBox(height: 12),
                  ...pastTrips.map((trip) => _buildTripItem(context, trip, tripProvider)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanTripButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => CreateTripSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.accentCyan.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.add_rounded, size: 16, color: AppColors.accentCyan),
            SizedBox(width: 4),
            Text(
              'Plan Trip',
              style: TextStyle(
                color: AppColors.accentCyan,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, Color accentColor, IconData icon) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 6),
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTripItem(BuildContext context, PlannedTrip trip, TripProvider tripProvider) {
    return _buildPolishedTripCard(context, trip, tripProvider);
  }

  Widget _buildPolishedTripCard(BuildContext context, PlannedTrip trip, TripProvider tripProvider) {
    final tripId = trip.id;
    final forecastStatus = tripId != null
        ? (trip.isWithinForecastRange
            ? tripProvider.forecastStatusForTrip(tripId)
            : TripForecastStatus.pending)
        : TripForecastStatus.pending;
    final weather = tripId != null ? tripProvider.weatherForTrip(tripId) : null;
    final score = tripId != null ? tripProvider.scoreForTrip(tripId) : null;
    final isScoreLoading = tripId != null ? tripProvider.isScoreLoadingForTrip(tripId) : false;

    final subtitleParts = [
      if (trip.destinationState.trim().isNotEmpty) trip.destinationState.trim(),
      if (trip.destinationCategory.trim().isNotEmpty) trip.destinationCategory.trim(),
    ];
    final subtitleText = subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : 'Malaysia';

    final String statusText;
    final Color statusColor;
    if (trip.isToday) {
      statusText = 'Today';
      statusColor = AppColors.safeGreen;
    } else if (trip.daysUntil == 1) {
      statusText = 'Tomorrow';
      statusColor = AppColors.weatherBlue;
    } else if (trip.isUpcoming) {
      statusText = 'In ${trip.daysUntil} Days';
      statusColor = AppColors.accentCyan;
    } else {
      statusText = 'Past';
      statusColor = AppColors.textMuted;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: GlassCard(
        padding: EdgeInsets.zero,
        borderRadius: 20,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripDetailScreen(trip: trip),
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [

              SizedBox(
                height: 120,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: DestinationImageView(
                        name: trip.destinationName,
                        state: trip.destinationState,
                        locationId: trip.destinationLocationId,
                        height: 120,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.85),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.50)),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => _handleDeleteTrip(context, trip),
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.55),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.dangerRed,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitleText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 11,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          trip.dateRangeText,
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Builder(
                      builder: (ctx) {
                        final cachedStops = tripId != null ? tripProvider.getStopsForTrip(tripId) : <TripStop>[];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.alt_route_rounded, size: 13, color: AppColors.accentCyan),
                                const SizedBox(width: 6),
                                Text(
                                  cachedStops.isNotEmpty
                                      ? '${cachedStops.length} ${cachedStops.length == 1 ? 'stop' : 'stops'} • ${trip.totalDays} ${trip.totalDays == 1 ? 'day' : 'days'}'
                                      : '${trip.totalDays} ${trip.totalDays == 1 ? 'day' : 'days'} itinerary',
                                  style: TextStyle(
                                    color: AppColors.cyanAccent(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            if (cachedStops.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.place_rounded, size: 13, color: AppColors.weatherBlue),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Next: ${cachedStops.first.locationName} · ${cachedStops.first.displayTimeString}',
                                      style: TextStyle(
                                        color: AppColors.secondaryText(context),
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.my_location_rounded, size: 13, color: AppColors.safeGreen),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'From: ${trip.originName.isNotEmpty ? trip.originName : 'Current Location'}',
                            style: TextStyle(
                              color: AppColors.secondaryText(context),
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [

                        _buildForecastChip(context, forecastStatus, weather, trip.isPast),

                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded, size: 12, color: AppColors.secondaryText(context)),
                              const SizedBox(width: 4),
                              Text(
                                '${trip.preferredPeriod} Trip',
                                style: TextStyle(
                                  color: AppColors.primaryText(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (isScoreLoading && score == null && trip.isWithinForecastRange && !trip.isPast) ...[
                      const SizedBox(height: 10),
                      _buildCalculatingBadge(),
                    ] else if (score != null && forecastStatus == TripForecastStatus.available) ...[
                      const SizedBox(height: 10),
                      _buildTravelScoreBadge(score),
                    ],

                    if (trip.notes != null && trip.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Note: ${trip.notes!.trim()}',
                        style: TextStyle(
                          color: AppColors.mutedText(context),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.dividerColor(context)),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trip.isPast ? 'Past Trip' : 'Planned Trip',
                          style: TextStyle(
                            color: AppColors.mutedText(context),
                            fontSize: 11,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'View Trip',
                              style: TextStyle(
                                color: AppColors.accentCyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.accentCyan),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForecastChip(BuildContext context, TripForecastStatus status, WeatherInfo? weather, bool isPast) {
    switch (status) {
      case TripForecastStatus.available:
        final condition = weather?.condition.trim().isNotEmpty == true
            ? weather!.condition.trim()
            : 'Fair Weather';
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.weatherBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_outlined, size: 12, color: AppColors.cyanAccent(context)),
              const SizedBox(width: 5),
              Text(
                condition,
                style: TextStyle(
                  color: AppColors.cyanAccent(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );

      case TripForecastStatus.loading:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass(context),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accentCyan),
              ),
              const SizedBox(width: 6),
              Text(
                'Loading forecast…',
                style: TextStyle(color: AppColors.mutedText(context), fontSize: 10),
              ),
            ],
          ),
        );

      case TripForecastStatus.pending:
        if (isPast) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderGlass(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: AppColors.mutedText(context)),
              const SizedBox(width: 5),
              Text(
                'Forecast not available yet',
                style: TextStyle(color: AppColors.mutedText(context), fontSize: 10),
              ),
            ],
          ),
        );

      case TripForecastStatus.unavailable:
        if (isPast) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceGlass(context),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.borderGlass(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 12, color: AppColors.mutedText(context)),
              const SizedBox(width: 5),
              Text(
                'Forecast unavailable',
                style: TextStyle(color: AppColors.mutedText(context), fontSize: 10),
              ),
            ],
          ),
        );

      case TripForecastStatus.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cautionAmber.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cautionAmber.withValues(alpha: 0.30)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.wifi_off_rounded, size: 12, color: AppColors.cautionAmber),
              SizedBox(width: 5),
              Text(
                'Forecast offline',
                style: TextStyle(color: AppColors.cautionAmber, fontSize: 10),
              ),
            ],
          ),
        );
    }
  }

  Widget _buildTravelScoreBadge(TravelScore? score) {
    if (score == null) return const SizedBox.shrink();
    final int scoreValue = score.score;
    final String levelName = score.levelName;
    final Color scoreColor = score.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scoreColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scoreColor.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.stars_rounded, size: 13, color: scoreColor),
          const SizedBox(width: 5),
          Text(
            'Travel Score: $scoreValue — $levelName',
            style: TextStyle(
              color: scoreColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalculatingBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accentCyan),
          ),
          const SizedBox(width: 6),
          Text(
            'Calculating...',
            style: TextStyle(
              color: AppColors.mutedText(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent(context).withValues(alpha: 0.10),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.25)),
              ),
              child: Icon(
                Icons.luggage_outlined,
                size: 40,
                color: AppColors.cyanAccent(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Trips Planned Yet',
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Plan your next Malaysian getaway with official MET forecasts and weather-optimized routes.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.secondaryText(context),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => CreateTripSheet.show(context),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Plan Your First Trip'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.weatherBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.accentCyan),
            const SizedBox(height: 16),
            Text(
              'Loading your trips…',
              style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, TripProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.dangerRed),
          const SizedBox(height: 12),
          Text(
            provider.errorMessage ?? 'Unable to load trips',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => provider.loadTrips(),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: Column(
        children: [
          Icon(Icons.account_circle_outlined, size: 40, color: AppColors.cyanAccent(context)),
          const SizedBox(height: 16),
          Text(
            'Sign In to Save Trips',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.primaryText(context)),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an account or sign in to sync your planned trips and receive timely weather reminders across devices.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildGuestWall(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 40),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.weatherBlue.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.luggage_rounded, color: AppColors.weatherBlue, size: 34),
          ),
          const SizedBox(height: 20),
          Text(
            'My Trips',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in to plan and manage your trips.',
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.weatherBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cyanAccent(context),
                side: BorderSide(color: AppColors.cyanAccent(context)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
