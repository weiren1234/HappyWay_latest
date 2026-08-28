import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
import '../widgets/plan_trip_sheet.dart';

/// TripsScreen displays saved travel itineraries with weather forecasts,
/// HappyWay travel scores, proactive trip reminders, and swipe-to-delete.
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tripProvider = Provider.of<TripProvider>(context);

    // Auto-load if authenticated and empty but not loading yet
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
              // ── Header Section ─────────────────────────────────────────────
              HeaderSection(
                title: 'My Trips',
                subtitle: totalTrips > 0
                    ? '$totalTrips planned ${totalTrips == 1 ? 'trip' : 'trips'}'
                    : 'Weather-optimized travel itineraries',
                trailing: _buildPlanTripButton(context),
              ),

              const SizedBox(height: 16),

      // ── Content State Handlers ─────────────────────────────────────────
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
                // ── Today's Trips ───────────────────────────────────────────
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

                // ── Upcoming Trips ──────────────────────────────────────────
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

                // ── Past Trips ──────────────────────────────────────────────
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

  // ─── Header Button ──────────────────────────────────────────────────────────

  Widget _buildPlanTripButton(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => PlanTripSheet.show(context),
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

  // ─── Section Header ─────────────────────────────────────────────────────────

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

  // ─── Trip Item Wrapper ──────────────────────────────────────────────────────

  Widget _buildTripItem(BuildContext context, PlannedTrip trip, TripProvider tripProvider) {
    return _TripsSwipeWrapper(
      key: ValueKey('trip_${trip.id}'),
      trip: trip,
      child: _buildPolishedTripCard(context, trip, tripProvider),
    );
  }

  // ─── Polished PlannedTripCard ───────────────────────────────────────────────

  Widget _buildPolishedTripCard(BuildContext context, PlannedTrip trip, TripProvider tripProvider) {
    final tripId = trip.id;
    final forecastStatus = tripId != null
        ? (trip.isWithinForecastRange
            ? tripProvider.forecastStatusForTrip(tripId)
            : TripForecastStatus.pending)
        : TripForecastStatus.pending;
    final weather = tripId != null ? tripProvider.weatherForTrip(tripId) : null;
    final score = tripId != null ? tripProvider.scoreForTrip(tripId) : null;

    final subtitleParts = [
      if (trip.destinationState.trim().isNotEmpty) trip.destinationState.trim(),
      if (trip.destinationCategory.trim().isNotEmpty) trip.destinationCategory.trim(),
    ];
    final subtitleText = subtitleParts.isNotEmpty ? subtitleParts.join(' • ') : 'Malaysia';

    // Status pill info
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
              // ── Destination Image Header ──────────────────────────────────
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
                          // Top row: Status pill + Trip code pill
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
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.60),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.glassBorderLight),
                                ),
                                child: Text(
                                  trip.tripCode,
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Bottom: Destination Name & State
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trip.destinationName,
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

              // ── Card Body ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date & Origin Row
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.accentCyan),
                        const SizedBox(width: 6),
                        Text(
                          '${trip.formattedWeekday}, ${trip.formattedDate}',
                          style: TextStyle(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
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

                    // Chips Row (Wrap for narrow-screen safety)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Forecast chip
                        _buildForecastChip(context, forecastStatus, weather, trip.isPast),

                        // Preferred Period chip
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

                    // Travel Score Badge (if forecast available)
                    if (score != null && forecastStatus == TripForecastStatus.available) ...[
                      const SizedBox(height: 10),
                      _buildTravelScoreBadge(score),
                    ],

                    // Reminder Banner (for active trips when in-app reminders are enabled)
                    if (!trip.isPast && tripProvider.remindersEnabled) ...[
                      const SizedBox(height: 10),
                      _buildReminderBanner(context, trip, forecastStatus, score),
                    ],

                    // Optional Notes
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

                    // Bottom Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          trip.isPast ? 'Past Trip' : 'Swipe left to delete',
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

  // ─── Forecast Chip ──────────────────────────────────────────────────────────

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
                'Forecast pending',
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

  // ─── Travel Score Badge ─────────────────────────────────────────────────────

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
            'HappyWay Score: $scoreValue — $levelName',
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

  // ─── Reminder Banner ────────────────────────────────────────────────────────

  Widget _buildReminderBanner(
    BuildContext context,
    PlannedTrip trip,
    TripForecastStatus forecastStatus,
    TravelScore? score,
  ) {
    late final Color accentColor;
    late final IconData icon;
    late final String badgeText;
    late final String title;
    late final String subtitle;

    if (trip.isToday) {
      accentColor = AppColors.safeGreen;
      icon = Icons.today_rounded;
      badgeText = 'TRIP TODAY';
      title = 'Your trip is today!';
      subtitle = '${trip.destinationName} • from ${trip.originName}';
    } else if (trip.daysUntil == 1) {
      accentColor = AppColors.weatherBlue;
      icon = Icons.alarm_on_rounded;
      badgeText = 'TOMORROW';
      title = 'Trip tomorrow';
      subtitle = '${trip.destinationName} (${trip.formattedDate})';
    } else if (trip.isWithinForecastRange && forecastStatus == TripForecastStatus.available) {
      accentColor = AppColors.accentCyan;
      icon = Icons.cloud_done_rounded;
      badgeText = 'FORECAST READY';
      title = 'Official forecast available';
      subtitle = '${trip.destinationName} • ${trip.relativeDateLabel}';
    } else if (trip.isUpcoming) {
      accentColor = AppColors.weatherBlue;
      icon = Icons.luggage_rounded;
      badgeText = 'IN ${trip.daysUntil} DAYS';
      title = 'Upcoming Trip';
      subtitle = '${trip.destinationName} • ${trip.formattedDate}';
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge + Title (Wrap for responsive safety)
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 11, color: accentColor),
                    const SizedBox(width: 4),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.primaryText(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: AppColors.secondaryText(context),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (forecastStatus == TripForecastStatus.available && score != null) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: score.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Score ${score.score}/100 • ${score.levelName}',
                    style: TextStyle(
                      color: score.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trip.preferredPeriod.isNotEmpty)
                  Text(
                    'Preferred: ${trip.preferredPeriod}',
                    style: TextStyle(
                      color: AppColors.secondaryText(context),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ─── Empty & Error States ───────────────────────────────────────────────────

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
              onPressed: () => PlanTripSheet.show(context),
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
            'Sign in to continue',
            style: AppTextStyles.titleLarge.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Sign in to save destinations and plan your trips.',
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


// ─── Swipe-to-Delete Wrapper ──────────────────────────────────────────────────

class _TripsSwipeWrapper extends StatefulWidget {
  final PlannedTrip trip;
  final Widget child;

  const _TripsSwipeWrapper({
    required super.key,
    required this.trip,
    required this.child,
  });

  @override
  State<_TripsSwipeWrapper> createState() => _TripsSwipeWrapperState();
}

class _TripsSwipeWrapperState extends State<_TripsSwipeWrapper> {
  late Key _dismissKey;

  @override
  void initState() {
    super.initState();
    _dismissKey = ValueKey('dismissible_${widget.trip.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: _dismissKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmAndDelete(context),
      onDismissed: (_) {},
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.dangerRed.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.35)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed, size: 24),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(
                color: AppColors.dangerRed,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      child: widget.child,
    );
  }

  Future<bool> _confirmAndDelete(BuildContext context) async {
    // Capture context-dependent objects BEFORE any await gap
    final provider = Provider.of<TripProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final tripId = widget.trip.id;

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
          style: TextStyle(color: AppColors.primaryText(context)),
        ),
        content: Text(
          'Remove your trip to ${widget.trip.destinationName} on ${widget.trip.formattedDate}?',
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      if (mounted) {
        setState(() {
          _dismissKey = UniqueKey();
        });
      }
      return false;
    }

    if (tripId == null) {
      return false;
    }

    final success = await provider.deleteTrip(tripId);

    if (!success && mounted) {
      setState(() {
        _dismissKey = UniqueKey();
      });
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to delete trip. Please try again.'),
          backgroundColor: AppColors.dangerRed,
          duration: Duration(seconds: 3),
        ),
      );
      await provider.loadTrips();
    }

    return success;
  }
}
