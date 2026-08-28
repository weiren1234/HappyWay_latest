import 'package:flutter/material.dart';
import '../models/travel_score.dart';
import '../theme/app_text_styles.dart';

/// TravelScoreBadge renders a visual travel suitability score indicator.
class TravelScoreBadge extends StatelessWidget {
  final TravelScore travelScore;
  final bool isCompact;

  const TravelScoreBadge({
    super.key,
    required this.travelScore,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color badgeColor = travelScore.color;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: badgeColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: badgeColor.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${travelScore.score}',
              style: AppTextStyles.badgeLabel.copyWith(color: badgeColor),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: badgeColor.withValues(alpha: 0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.explore_rounded,
            color: badgeColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Travel Score ${travelScore.score}',
            style: AppTextStyles.badgeLabel.copyWith(
              color: badgeColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
