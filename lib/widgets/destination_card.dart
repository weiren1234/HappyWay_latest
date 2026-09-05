import 'package:flutter/material.dart';
import '../models/travel_destination.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';
import 'travel_score_badge.dart';
import 'destination_image_view.dart';

class DestinationCard extends StatelessWidget {
  final TravelDestination destination;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const DestinationCard({
    super.key,
    required this.destination,
    required this.onTap,
    required this.onToggleSave,
  });

  IconData _getWeatherIcon(String? iconCode) {
    switch (iconCode) {
      case 'thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'rain':
        return Icons.grain_rounded;
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'cloudy':
        return Icons.wb_cloudy_rounded;
      case 'partly_cloudy':
        return Icons.wb_cloudy_outlined;
      case 'foggy':
        return Icons.foggy;
      default:
        return Icons.cloud_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final weather = destination.weather;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Stack(
              children: [
                DestinationImageView(
                  name: destination.name,
                  state: destination.state,
                  locationId: destination.metLocationId.isNotEmpty ? destination.metLocationId : destination.id,
                  imageUrl: destination.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  heroTag: 'dest_img_${destination.id}',
                ),

                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  top: 14,
                  left: 14,
                  right: 14,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Text(
                          destination.category,
                          style: AppTextStyles.badgeLabel.copyWith(color: AppColors.accentCyan),
                        ),
                      ),
                      GestureDetector(
                        onTap: onToggleSave,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Icon(
                            destination.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                            color: destination.isSaved ? AppColors.accentCyan : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Positioned(
                  bottom: 14,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination.name,
                        style: AppTextStyles.titleLarge.copyWith(color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: AppColors.accentCyan, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            destination.state,
                            style: AppTextStyles.bodyMedium.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  Row(
                    children: [
                      Icon(
                        _getWeatherIcon(weather?.iconCode),
                        color: AppColors.blueAccent(context),
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (weather?.temperature != null)
                            Text(
                              '${weather!.temperature!.toStringAsFixed(1)}°C',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryText(context),
                              ),
                            )
                          else if (weather?.maxTemperature != null)
                            Text(
                              '${weather!.maxTemperature!.toStringAsFixed(0)}°C',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.primaryText(context),
                              ),
                            ),
                          Text(
                            weather?.condition ?? 'MET Forecast',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.mutedText(context),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  TravelScoreBadge(travelScore: destination.travelScore, isCompact: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
