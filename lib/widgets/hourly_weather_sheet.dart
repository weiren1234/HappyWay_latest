import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/itinerary_analysis.dart';
import '../models/trip_stop.dart';
import '../models/weather_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class HourlyWeatherSheet extends StatefulWidget {
  final TripStop stop;
  final ItineraryStopAnalysis analysis;

  const HourlyWeatherSheet({
    super.key,
    required this.stop,
    required this.analysis,
  });

  static Future<void> show(
    BuildContext context, {
    required TripStop stop,
    required ItineraryStopAnalysis analysis,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => HourlyWeatherSheet(
        stop: stop,
        analysis: analysis,
      ),
    );
  }

  @override
  State<HourlyWeatherSheet> createState() => _HourlyWeatherSheetState();
}

class _HourlyWeatherSheetState extends State<HourlyWeatherSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToTargetHour();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTargetHour() {
    if (!_scrollController.hasClients) return;
    final targetHour = _targetHour;
    if (targetHour == null) return;

    final items = _filteredHours;
    final index = items.indexWhere((item) => item.time.hour == targetHour);
    if (index > 0) {
      final targetOffset = (index * 64.0) - 20.0;
      final maxOffset = _scrollController.position.maxScrollExtent;
      final offset = targetOffset.clamp(0.0, maxOffset);
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int? get _targetHour {
    if (widget.stop.isExactTime) {
      return widget.analysis.plannedArrivalDateTime?.hour;
    }
    return widget.analysis.recommendedArrivalDateTime?.hour;
  }

  List<HourlyWeatherItem> get _filteredHours {
    final raw = widget.analysis.weather?.hourlyForecast;
    if (raw == null || raw.isEmpty) return const [];

    final visit = widget.stop.visitDate;
    return raw.where((item) {
      return item.time.year == visit.year &&
          item.time.month == visit.month &&
          item.time.day == visit.day;
    }).toList();
  }

  IconData _iconForItem(HourlyWeatherItem item) {
    if (item.isSunset) return Icons.wb_twilight_rounded;
    if (item.isSunrise) return Icons.wb_sunny_rounded;

    final hour = item.time.hour;
    final isNight = hour < 6 || hour >= 19;

    if (isNight) {
      switch (item.iconCode) {
        case 'sunny':
          return Icons.nights_stay_rounded;
        case 'partly_cloudy':
          return Icons.nightlight_round;
        case 'cloudy':
          return Icons.cloud_outlined;
        case 'drizzle':
          return Icons.water_drop_outlined;
        case 'rain':
          return Icons.water_drop_rounded;
        case 'heavy_rain':
        case 'showers':
        case 'heavy_showers':
          return Icons.thunderstorm_outlined;
        case 'thunderstorm':
        case 'severe_thunderstorm':
          return Icons.thunderstorm_rounded;
        case 'foggy':
        case 'hazy':
          return Icons.foggy;
        default:
          return Icons.nightlight_round;
      }
    }

    switch (item.iconCode) {
      case 'sunny':
        return Icons.wb_sunny_rounded;
      case 'partly_cloudy':
        return Icons.wb_cloudy_outlined;
      case 'cloudy':
        return Icons.cloud_rounded;
      case 'drizzle':
        return Icons.water_drop_outlined;
      case 'rain':
        return Icons.water_drop_rounded;
      case 'heavy_rain':
      case 'showers':
      case 'heavy_showers':
        return Icons.thunderstorm_outlined;
      case 'thunderstorm':
      case 'severe_thunderstorm':
        return Icons.thunderstorm_rounded;
      case 'foggy':
      case 'hazy':
        return Icons.foggy;
      default:
        return Icons.wb_cloudy_rounded;
    }
  }

  Color _iconColorForItem(HourlyWeatherItem item, BuildContext context) {
    if (item.isSunset || item.isSunrise) return AppColors.cautionAmber;
    final hour = item.time.hour;
    final isNight = hour < 6 || hour >= 19;
    if (isNight) return AppColors.accentCyan;

    switch (item.iconCode) {
      case 'sunny':
        return AppColors.cautionAmber;
      case 'partly_cloudy':
        return AppColors.accentCyan;
      case 'cloudy':
        return AppColors.mutedText(context);
      case 'drizzle':
      case 'rain':
      case 'showers':
      case 'heavy_rain':
      case 'thunderstorm':
        return AppColors.blueAccent(context);
      default:
        return AppColors.cyanAccent(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dateFormatted = DateFormat('d MMM yyyy').format(widget.stop.visitDate);
    final hours = _filteredHours;
    final targetHour = _targetHour;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
        minHeight: 280,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: AppColors.borderGlass(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mutedText(context).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.schedule_rounded,
                              size: 15,
                              color: AppColors.cyanAccent(context),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Hourly Weather',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.cyanAccent(context),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.stop.locationName,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primaryText(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(
                              dateFormatted,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.mutedText(context),
                                fontSize: 12,
                              ),
                            ),
                            if (!widget.stop.isExactTime &&
                                widget.stop.preferredPeriod != null &&
                                widget.stop.preferredPeriod!.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accentCyan.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: AppColors.accentCyan.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  'Preferred: ${widget.stop.preferredPeriod![0].toUpperCase()}${widget.stop.preferredPeriod!.substring(1).toLowerCase()}',
                                  style: TextStyle(
                                    color: AppColors.accentCyan,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: AppColors.mutedText(context), size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            Expanded(
              child: hours.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off_rounded,
                              size: 44,
                              color: AppColors.mutedText(context).withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Hourly forecast is not available yet.',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryText(context),
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Forecasts become available closer to your travel date.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.mutedText(context),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      itemCount: hours.length,
                      itemBuilder: (context, index) {
                        final item = hours[index];
                        final isHighlighted = targetHour != null && item.time.hour == targetHour;
                        final temp = item.temperature?.round();
                        final precip = item.precipitationProbability;
                        final timeStr = DateFormat('h a').format(item.time);

                        final badgeLabel = widget.stop.isExactTime ? 'Planned' : 'Recommended';
                        final badgeColor = widget.stop.isExactTime
                            ? AppColors.cyanAccent(context)
                            : AppColors.safeGreen;

                        return Container(
                          height: 56,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isHighlighted
                                ? badgeColor.withValues(alpha: 0.12)
                                : AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isHighlighted
                                  ? badgeColor.withValues(alpha: 0.55)
                                  : AppColors.borderGlass(context),
                              width: isHighlighted ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 58,
                                child: Text(
                                  timeStr,
                                  style: TextStyle(
                                    color: isHighlighted
                                        ? AppColors.primaryText(context)
                                        : AppColors.primaryText(context),
                                    fontWeight: isHighlighted ? FontWeight.w800 : FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Icon(
                                _iconForItem(item),
                                size: 18,
                                color: _iconColorForItem(item, context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item.condition,
                                        style: TextStyle(
                                          color: AppColors.primaryText(context),
                                          fontSize: 12,
                                          fontWeight: isHighlighted ? FontWeight.w700 : FontWeight.w500,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isHighlighted) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: badgeColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: badgeColor.withValues(alpha: 0.4),
                                          ),
                                        ),
                                        child: Text(
                                          badgeLabel,
                                          style: TextStyle(
                                            color: badgeColor,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  temp != null ? '$temp°C' : '—',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppColors.primaryText(context),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 68,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Icon(
                                      Icons.water_drop_rounded,
                                      size: 11,
                                      color: (precip != null && precip > 30)
                                          ? AppColors.blueAccent(context)
                                          : AppColors.mutedText(context).withValues(alpha: 0.6),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      precip != null ? '$precip%' : '0%',
                                      style: TextStyle(
                                        color: (precip != null && precip > 30)
                                            ? AppColors.blueAccent(context)
                                            : AppColors.mutedText(context),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
