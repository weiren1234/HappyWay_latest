import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

class LoadingSkeleton extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const LoadingSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = AppColors.isDark(context);
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.glassSurface : const Color(0xFFE2E8F0),
      highlightColor: isDark ? AppColors.glassSurfaceHover : const Color(0xFFF8FAFC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget destinationCardSkeleton([BuildContext? context]) {
    final isDark = context == null || AppColors.isDark(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.glassSurface : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? AppColors.glassBorder : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          LoadingSkeleton(width: double.infinity, height: 160, borderRadius: 16),
          SizedBox(height: 14),
          LoadingSkeleton(width: 180, height: 20, borderRadius: 8),
          SizedBox(height: 8),
          LoadingSkeleton(width: 120, height: 14, borderRadius: 6),
        ],
      ),
    );
  }
}
