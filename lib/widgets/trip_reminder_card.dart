import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/travel_score.dart';
import '../providers/trip_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

/// Reminder type category indicating priority level.
enum TripReminderType {
  today,
  tomorrow,
  forecastAvailable,
  upcoming,
}

/// TripReminderCard presents an in-app proactive reminder banner for upcoming itineraries.
/// Priority Order:
/// 1. Trip Today
/// 2. Trip Tomorrow
/// 3. Forecast Available (eligible trips with official MET weather ready)
/// 4. Next Upcoming Trip
class TripReminderCard extends StatelessWidget {
  final PlannedTrip trip;
  final VoidCallback onTap;
  final bool isCompact;

  const TripReminderCard({
    super.key,
    required this.trip,
    required this.onTap,
    this.isCompact = false,
  });

  /// Evaluates and returns the single highest priority trip for reminders, or null if none.
  static PlannedTrip? resolveTopReminder(List<PlannedTrip> trips, [TripProvider? tripProvider]) {
    if (trips.isEmpty) return null;

    final upcoming = trips.where((t) => t.isUpcoming).toList();
    if (upcoming.isEmpty) return null;

    // 1. Trip Today
    final todayTrips = upcoming.where((t) => t.isToday).toList();
    if (todayTrips.isNotEmpty) {
      todayTrips.sort((a, b) => a.travelDate.compareTo(b.travelDate));
      return todayTrips.first;
    }

    // 2. Trip Tomorrow
    final tomorrowTrips = upcoming.where((t) => t.daysUntil == 1).toList();
    if (tomorrowTrips.isNotEmpty) {
      tomorrowTrips.sort((a, b) => a.travelDate.compareTo(b.travelDate));
      return tomorrowTrips.first;
    }

    // 3. Forecast Available (trips in forecast window with MET weather loaded)
    if (tripProvider != null) {
      final forecastAvailableTrips = upcoming.where((t) {
        if (t.id == null) return false;
        return tripProvider.forecastStatusForTrip(t.id!) == TripForecastStatus.available;
      }).toList();
      if (forecastAvailableTrips.isNotEmpty) {
        forecastAvailableTrips.sort((a, b) => a.travelDate.compareTo(b.travelDate));
        return forecastAvailableTrips.first;
      }
    }

    // 4. Next Upcoming Trip
    upcoming.sort((a, b) => a.travelDate.compareTo(b.travelDate));
    return upcoming.first;
  }

  TripReminderType get _reminderType {
    if (trip.isToday) return TripReminderType.today;
    if (trip.daysUntil == 1) return TripReminderType.tomorrow;
    return trip.isWithinForecastRange ? TripReminderType.forecastAvailable : TripReminderType.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final tripProvider = Provider.of<TripProvider>(context);
    final tripId = trip.id;
    final forecastStatus = tripId != null
        ? tripProvider.forecastStatusForTrip(tripId)
        : TripForecastStatus.pending;
    final TravelScore? score = tripId != null ? tripProvider.scoreForTrip(tripId) : null;

    final type = _reminderType;

    Color accentColor;
    IconData icon;
    String badgeText;
    String title;
    String subtitle;

    switch (type) {
      case TripReminderType.today:
        accentColor = AppColors.safeGreen;
        icon = Icons.today_rounded;
        badgeText = 'TRIP TODAY';
        title = 'Your trip is today!';
        subtitle = '${trip.destinationName} • Starting from ${trip.originName}';
        break;

      case TripReminderType.tomorrow:
        accentColor = AppColors.blueAccent(context);
        icon = Icons.alarm_on_rounded;
        badgeText = 'TOMORROW';
        title = 'Trip tomorrow';
        subtitle = '${trip.destinationName} (${trip.formattedDate})';
        break;

      case TripReminderType.forecastAvailable:
        accentColor = AppColors.cyanAccent(context);
        icon = Icons.cloud_done_rounded;
        badgeText = forecastStatus == TripForecastStatus.available ? 'FORECAST AVAILABLE' : 'UPCOMING';
        title = 'Official forecast available';
        subtitle = '${trip.destinationName} • ${trip.relativeDateLabel} (${trip.formattedDate})';
        break;

      case TripReminderType.upcoming:
        accentColor = AppColors.blueAccent(context);
        icon = Icons.luggage_rounded;
        badgeText = 'IN ${trip.daysUntil} DAYS';
        title = 'Upcoming Trip';
        subtitle = '${trip.destinationName} • ${trip.formattedDate}';
        break;
    }

    if (isCompact) {
      return _buildCompactBanner(context, accentColor, icon, badgeText, title, subtitle, score, forecastStatus);
    }

    return _buildFullBanner(context, accentColor, icon, badgeText, title, subtitle, score, forecastStatus);
  }

  Widget _buildFullBanner(
    BuildContext context,
    Color accentColor,
    IconData icon,
    String badgeText,
    String title,
    String subtitle,
    TravelScore? score,
    TripForecastStatus forecastStatus,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: accentColor.withValues(alpha: 0.35),
      backgroundColor: accentColor.withValues(alpha: 0.07),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Tag + Countdown badge + Trailing CTA
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 12, color: accentColor),
                      const SizedBox(width: 5),
                      Text(
                        badgeText,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      'View Trip',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16, color: accentColor),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title & Destination Subtitle
            Text(
              title,
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText(context),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.secondaryText(context),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),

            // Score & Period Chip when forecast is available
            if (forecastStatus == TripForecastStatus.available && score != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
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
                        const SizedBox(width: 5),
                        Text(
                          'Score: ${score.score}/100 (${score.levelName})',
                          style: TextStyle(
                            color: score.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 12, color: AppColors.secondaryText(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.preferredPeriod} trip',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.secondaryText(context),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else if (trip.isWithinForecastRange && forecastStatus == TripForecastStatus.loading) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.cyanAccent(context)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Refreshing official MET forecast...',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.cyanAccent(context), fontSize: 11),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCompactBanner(
    BuildContext context,
    Color accentColor,
    IconData icon,
    String badgeText,
    String title,
    String subtitle,
    TravelScore? score,
    TripForecastStatus forecastStatus,
  ) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      borderColor: accentColor.withValues(alpha: 0.3),
      backgroundColor: accentColor.withValues(alpha: 0.06),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleSmall.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText(context),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText(context),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: accentColor, size: 18),
          ],
        ),
      ),
    );
  }
}
