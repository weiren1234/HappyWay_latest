import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/weather_info.dart';
import '../models/travel_score.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'destination_image_view.dart';
import 'glass_card.dart';

/// PlannedTripCard is a presentational widget displaying a planned trip card
/// with destination image, gradient overlay, weather chips, HappyWay score, and swipe-to-delete.
class PlannedTripCard extends StatelessWidget {
  final PlannedTrip trip;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const PlannedTripCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return onDelete != null
        ? _SwipeToDeleteWrapper(trip: trip, onDelete: onDelete!, child: _buildCard(context))
        : _buildCard(context);
  }

  Widget _buildCard(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final tripId = trip.id;

    TripForecastStatus forecastStatus = TripForecastStatus.pending;
    if (tripId != null) {
      forecastStatus = trip.isWithinForecastRange
          ? tripProvider.forecastStatusForTrip(tripId)
          : TripForecastStatus.pending;
    }
    final WeatherInfo? weather = tripId != null ? tripProvider.weatherForTrip(tripId) : null;
    final TravelScore? score = tripId != null ? tripProvider.scoreForTrip(tripId) : null;

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
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
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
                        _ForecastStatusRow(
                          forecastStatus: forecastStatus,
                          weather: weather,
                          isPast: trip.isPast,
                        ),
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

                    // Travel Score mini-badge (only when forecast available)
                    if (score != null && forecastStatus == TripForecastStatus.available) ...[
                      const SizedBox(height: 10),
                      _TravelScoreBadge(score: score),
                    ],

                    // Notes
                    if (trip.notes != null && trip.notes!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Note: ${trip.notes!.trim()}',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontSize: 11,
                          color: AppColors.mutedText(context),
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 10),
                    Divider(height: 1, color: AppColors.dividerColor(context)),
                    const SizedBox(height: 8),

                    // Bottom Row
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
}

// ─── Forecast Status Row ──────────────────────────────────────────────────────

class _ForecastStatusRow extends StatelessWidget {
  final TripForecastStatus forecastStatus;
  final WeatherInfo? weather;
  final bool isPast;

  const _ForecastStatusRow({
    required this.forecastStatus,
    required this.weather,
    required this.isPast,
  });

  @override
  Widget build(BuildContext context) {
    switch (forecastStatus) {
      case TripForecastStatus.pending:
        if (isPast) return const SizedBox.shrink();
        return _chip(
          icon: Icons.schedule_rounded,
          label: 'Forecast pending',
          iconColor: AppColors.mutedText(context),
          bgColor: AppColors.surfaceGlass(context),
          textColor: AppColors.mutedText(context),
          borderColor: AppColors.borderGlass(context),
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
              Text('Loading forecast…', style: TextStyle(color: AppColors.mutedText(context), fontSize: 10)),
            ],
          ),
        );

      case TripForecastStatus.available:
        final condition = weather?.condition.trim().isNotEmpty == true
            ? weather!.condition.trim()
            : 'Fair Weather';

        return _chip(
          icon: Icons.cloud_outlined,
          label: condition,
          iconColor: AppColors.cyanAccent(context),
          bgColor: AppColors.weatherBlue.withValues(alpha: 0.15),
          textColor: AppColors.cyanAccent(context),
          borderColor: AppColors.weatherBlue.withValues(alpha: 0.30),
          fontWeight: FontWeight.w600,
        );

      case TripForecastStatus.unavailable:
        if (isPast) return const SizedBox.shrink();
        return _chip(
          icon: Icons.cloud_off_rounded,
          label: 'Forecast unavailable',
          iconColor: AppColors.mutedText(context),
          bgColor: AppColors.surfaceGlass(context),
          textColor: AppColors.mutedText(context),
          borderColor: AppColors.borderGlass(context),
        );

      case TripForecastStatus.error:
        return _chip(
          icon: Icons.wifi_off_rounded,
          label: 'Forecast offline',
          iconColor: AppColors.cautionAmber,
          bgColor: AppColors.cautionAmber.withValues(alpha: 0.10),
          textColor: AppColors.cautionAmber,
          borderColor: AppColors.cautionAmber.withValues(alpha: 0.30),
        );
    }
  }

  Widget _chip({
    required IconData icon,
    required String label,
    required Color iconColor,
    required Color bgColor,
    required Color textColor,
    Color? borderColor,
    FontWeight fontWeight = FontWeight.w400,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: fontWeight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Travel Score Badge ────────────────────────────────────────────────────────

class _TravelScoreBadge extends StatelessWidget {
  final TravelScore? score;

  const _TravelScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    if (score == null) return const SizedBox.shrink();
    final scoreValue = score!.score;
    final levelName = score!.levelName;
    final scoreColor = score!.color;

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
}

// ─── Swipe-to-Delete Wrapper ──────────────────────────────────────────────────

class _SwipeToDeleteWrapper extends StatefulWidget {
  final PlannedTrip trip;
  final VoidCallback onDelete;
  final Widget child;

  const _SwipeToDeleteWrapper({
    required this.trip,
    required this.onDelete,
    required this.child,
  });

  @override
  State<_SwipeToDeleteWrapper> createState() => _SwipeToDeleteWrapperState();
}

class _SwipeToDeleteWrapperState extends State<_SwipeToDeleteWrapper> {
  late Key _dismissibleKey;

  @override
  void initState() {
    super.initState();
    _dismissibleKey = ValueKey('dismissible_${widget.trip.id}');
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: _dismissibleKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => widget.onDelete(),
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
            Text('Delete', style: TextStyle(color: AppColors.dangerRed, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: widget.child,
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(ctx)),
        ),
        title: Text('Delete Trip?', style: TextStyle(color: AppColors.primaryText(ctx))),
        content: Text(
          'Remove your trip to ${widget.trip.destinationName} on ${widget.trip.formattedDate}?',
          style: TextStyle(color: AppColors.secondaryText(ctx), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(ctx))),
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
        setState(() => _dismissibleKey = UniqueKey());
      }
      return false;
    }
    return true;
  }
}
