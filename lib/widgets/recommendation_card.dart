import 'package:flutter/material.dart';
import '../models/destination_recommendation.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'destination_image_view.dart';

/// RecommendationCard displays a smart destination recommendation with
/// activity match, official MET weather periods, Destination Match score, reachability status, and explanation.
class RecommendationCard extends StatelessWidget {
  final DestinationRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onAnalyze;

  const RecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final dest = recommendation.destination;
    final weather = recommendation.weather;

    return GlassCard(
      padding: EdgeInsets.zero,
      borderColor: recommendation.matchColor.withValues(alpha: 0.35),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image & Top Badges ──────────────────────────────────────────
            Stack(
              children: [
                DestinationImageView(
                  name: dest.name,
                  state: dest.state,
                  locationId: dest.metLocationId.isNotEmpty ? dest.metLocationId : dest.id,
                  imageUrl: dest.imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                ),

                // Gradient overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.2),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),

                // Top Badges
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.glassBorderLight),
                        ),
                        child: Text(
                          '${dest.state} • ${dest.category}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    ],
                  ),
                ),

                // Bottom Title & Reachability Pill on Image
                Positioned(
                  bottom: 10,
                  left: 14,
                  right: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dest.name,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── Card Body ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reachability Indicator Row
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: recommendation.isRoadAccessible
                              ? AppColors.safeGreen.withValues(alpha: 0.12)
                              : AppColors.surfaceGlass(context),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: recommendation.isRoadAccessible
                                ? AppColors.safeGreen.withValues(alpha: 0.3)
                                : AppColors.borderGlass(context),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              recommendation.isRoadAccessible
                                  ? Icons.directions_car_rounded
                                  : Icons.flight_takeoff_rounded,
                              size: 12,
                              color: recommendation.isRoadAccessible
                                  ? AppColors.safeGreen
                                  : AppColors.mutedText(context),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              recommendation.reachabilityNote,
                              style: TextStyle(
                                color: recommendation.isRoadAccessible
                                    ? AppColors.safeGreen
                                    : AppColors.secondaryText(context),
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (recommendation.route != null)
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
                              Icon(Icons.timer_outlined, size: 11, color: AppColors.cyanAccent(context)),
                              const SizedBox(width: 4),
                              Text(
                                '${recommendation.route!.durationFormatted} • ${recommendation.route!.distanceFormatted}',
                                style: TextStyle(
                                  color: AppColors.primaryText(context),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // MET Weather Forecast Badges (if available)
                  if (weather != null &&
                      (weather.morningCondition != null || weather.afternoonCondition != null)) ...[
                    Row(
                      children: [
                        if (weather.morningCondition != null)
                          Expanded(
                            child: _WeatherBadge(
                              label: 'Morning',
                              condition: weather.morningCondition!,
                              icon: Icons.wb_twilight_rounded,
                            ),
                          ),
                        if (weather.morningCondition != null && weather.afternoonCondition != null)
                          const SizedBox(width: 8),
                        if (weather.afternoonCondition != null)
                          Expanded(
                            child: _WeatherBadge(
                              label: 'Afternoon',
                              condition: weather.afternoonCondition!,
                              icon: Icons.wb_sunny_rounded,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Best Travel Period
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 13, color: AppColors.cyanAccent(context)),
                      const SizedBox(width: 4),
                      Text(
                        'Best period: ${recommendation.bestTravelPeriod}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.cyanAccent(context),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Rule-Based Explanation
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceGlass(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderGlass(context)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline_rounded, color: AppColors.cyanAccent(context), size: 14),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            recommendation.reason,
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 11,
                              color: AppColors.secondaryText(context),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Actions row
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryText(context),
                            side: BorderSide(color: AppColors.borderGlass(context), width: 1),
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      if (onAnalyze != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onAnalyze,
                            icon: const Icon(Icons.insights_rounded, size: 14),
                            label: const Text('Analyze Trip', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.weatherBlue,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeatherBadge extends StatelessWidget {
  final String label;
  final String condition;
  final IconData icon;

  const _WeatherBadge({
    required this.label,
    required this.condition,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.weatherBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 13, color: AppColors.cyanAccent(context)),
          const SizedBox(width: 5),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 9, color: AppColors.mutedText(context))),
                Text(
                  condition,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primaryText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
