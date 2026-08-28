import 'package:flutter/material.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../models/weather_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

/// TravelOverviewCard shows a compact trip summary with route info, weather,
/// key reasons, recommended departure, and travel score on the Home screen.
class TravelOverviewCard extends StatelessWidget {
  final String fromName;
  final String toName;
  final TravelRoute? route;
  final WeatherInfo? weather;
  final TravelScore score;
  final bool isLoadingRoute;
  final String? routeError;
  final String? weatherAreaName;
  final bool hasWeatherLocation;
  final VoidCallback? onRetryRoute;
  final VoidCallback? onViewInsights;

  const TravelOverviewCard({
    super.key,
    required this.fromName,
    required this.toName,
    this.route,
    this.weather,
    required this.score,
    this.isLoadingRoute = false,
    this.routeError,
    this.weatherAreaName,
    this.hasWeatherLocation = true,
    this.onRetryRoute,
    this.onViewInsights,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: isDark
          ? AppColors.backgroundCardDark.withValues(alpha: 0.85)
          : AppColors.backgroundCardLight,
      borderColor: AppColors.borderGlass(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 3,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.blueAccent(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Travel Overview',
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.primaryText(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: score.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: score.color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${score.score}/100 • ${score.levelName}',
                  style: TextStyle(
                    color: score.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Route Origin → Destination ─────────────────────────────────────
          _RouteRow(fromName: fromName, toName: toName),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 12),

          // ── Distance & Duration ────────────────────────────────────────────
          if (isLoadingRoute)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                    ),
                    const SizedBox(width: 10),
                    Text('Calculating route...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (routeError != null)
            _RouteErrorBanner(error: routeError!, onRetry: onRetryRoute)
          else if (route != null) ...[
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: route!.distanceFormatted,
                    color: AppColors.blueAccent(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.schedule_rounded,
                    label: 'Est. Drive Time',
                    value: route!.durationFormatted,
                    color: AppColors.cyanAccent(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '* Estimated driving time, not live traffic data',
                style: AppTextStyles.bodySmall.copyWith(
                  fontSize: 10,
                  color: AppColors.mutedText(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass(context),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: AppColors.mutedText(context)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Direct driving route unavailable — analysis based on official weather conditions.',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── MET Weather Summary ────────────────────────────────────────────
          if (weather != null) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.cloud_queue_rounded, color: AppColors.blueAccent(context), size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    (weatherAreaName != null &&
                            weatherAreaName!.isNotEmpty &&
                            weatherAreaName!.toLowerCase() != toName.toLowerCase())
                        ? 'Official MET Forecast • Area: $weatherAreaName'
                        : 'Official MET Malaysia Forecast',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.secondaryText(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _WeatherRow(weather: weather!),
          ] else if (!hasWeatherLocation) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderGlass(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.mutedText(context), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Official MET forecast is not available for this destination.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Key Insights / Reasons Preview ─────────────────────────────────
          if (score.explanationBullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 10),
            ...score.explanationBullets.take(2).map((bullet) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
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
                          bullet.startsWith('• ') ? bullet.substring(2) : bullet,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 10),

          // ── Recommended Travel Period & Departure ──────────────────────────
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.explore_outlined,
                  label: 'Best Period',
                  value: score.bestTravelPeriod,
                  color: score.color,
                ),
              ),
              if (score.recommendedDeparture != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.departure_board_rounded,
                    label: 'Departure',
                    value: score.recommendedDeparture!,
                    color: AppColors.cyanAccent(context),
                  ),
                ),
              ],
            ],
          ),

          if (score.departureReason != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.cyanAccent(context), size: 14),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      score.departureReason!,
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── View Full Insights CTA ─────────────────────────────────────────
          if (onViewInsights != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onViewInsights,
                icon: Icon(
                  Icons.insights_rounded,
                  size: 17,
                  color: isDark ? AppColors.accentCyan : AppColors.weatherBlue,
                ),
                label: Text(
                  'View Full Travel Analysis',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: isDark ? AppColors.accentCyan : AppColors.weatherBlue,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? AppColors.weatherBlue.withValues(alpha: 0.30)
                      : AppColors.weatherBlue.withValues(alpha: 0.10),
                  foregroundColor: isDark ? AppColors.accentCyan : AppColors.weatherBlue,
                  side: BorderSide(
                    color: isDark ? AppColors.accentCyan : AppColors.weatherBlue,
                    width: 1.2,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
          ],

          // HappyWay disclaimer
          const SizedBox(height: 10),
          Text(
            'Travel Score and Departure advice are HappyWay rule-based recommendations derived from official MET Malaysia data.',
            style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Route Row ──────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final String fromName;
  final String toName;

  const _RouteRow({required this.fromName, required this.toName});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.weatherBlue,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 1.5,
              height: 28,
              color: AppColors.borderGlass(context),
            ),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.cyanAccent(context),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('From', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
                  Text(
                    fromName,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('To', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
                  Text(
                    toName,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.cyanAccent(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
        Icon(Icons.directions_car_rounded, color: AppColors.iconMuted(context), size: 20),
      ],
    );
  }
}

// ── Info Tile ──────────────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w700),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Weather Row ────────────────────────────────────────────────────────────────

class _WeatherRow extends StatelessWidget {
  final WeatherInfo weather;
  const _WeatherRow({required this.weather});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        if (weather.morningCondition != null)
          _WeatherPeriod(label: 'Morning', value: weather.morningCondition!, icon: Icons.wb_twilight_rounded),
        if (weather.afternoonCondition != null)
          _WeatherPeriod(label: 'Afternoon', value: weather.afternoonCondition!, icon: Icons.wb_sunny_rounded),
        if (weather.nightCondition != null)
          _WeatherPeriod(label: 'Night', value: weather.nightCondition!, icon: Icons.nights_stay_rounded),
      ],
    );
  }
}

class _WeatherPeriod extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WeatherPeriod({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Column(
        children: [
          Icon(icon, size: 14, color: AppColors.cyanAccent(context)),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Route Error Banner ─────────────────────────────────────────────────────────

class _RouteErrorBanner extends StatelessWidget {
  final String error;
  final VoidCallback? onRetry;

  const _RouteErrorBanner({required this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.dangerRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.cyanAccent(context),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}
