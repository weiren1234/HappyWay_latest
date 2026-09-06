import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/weather_info.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'glass_card.dart';

class HourlyWeatherCard extends StatelessWidget {
  final WeatherInfo weather;
  final String? title;

  const HourlyWeatherCard({
    super.key,
    required this.weather,
    this.title = 'Weather',
  });

  @override
  Widget build(BuildContext context) {
    final rawHourly = weather.hourlyForecast;
    final now = DateTime.now();
    List<HourlyWeatherItem>? hourly = rawHourly;
    if (rawHourly != null && rawHourly.isNotEmpty) {
      final hasToday = rawHourly.any((item) =>
          item.time.year == now.year &&
          item.time.month == now.month &&
          item.time.day == now.day);
      if (hasToday) {
        final currentHourStart = DateTime(now.year, now.month, now.day, now.hour);
        final next24HoursEnd = currentHourStart.add(const Duration(hours: 24));
        final upcoming = rawHourly.where((item) {
          return !item.time.isBefore(currentHourStart) && item.time.isBefore(next24HoursEnd);
        }).toList();
        if (upcoming.isNotEmpty) {
          hourly = upcoming;
        }
      } else {
        final targetDate = rawHourly.first.time;
        final targetDayItems = rawHourly.where((item) =>
            item.time.year == targetDate.year &&
            item.time.month == targetDate.month &&
            item.time.day == targetDate.day).toList();
        if (targetDayItems.isNotEmpty) {
          hourly = targetDayItems;
        }
      }
    }
    final safeHourly = hourly;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              Icon(Icons.cloud_outlined, color: AppColors.cyanAccent(context), size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title ?? 'Weather',
                  style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Icon(_weatherIcon(weather.iconCode), size: 40, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.minTemperature != null && weather.maxTemperature != null
                          ? '${weather.minTemperature!.round()}°C – ${weather.maxTemperature!.round()}°C'
                          : weather.temperature != null ? '${weather.temperature!.round()}°C' : '—',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryText(context),
                      ),
                    ),
                    Text(
                      weather.condition,
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cyanAccent(context)),
                    ),
                  ],
                ),
              ),
              if (weather.feelsLike != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass(context),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Column(
                    children: [
                      Text('Feels Like', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
                      Text(
                        '${weather.feelsLike!.round()}°C',
                        style: TextStyle(color: AppColors.primaryText(context), fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 12),

          if (safeHourly != null && safeHourly.isNotEmpty) ...[
            SizedBox(
              height: 98,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: safeHourly.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (ctx, index) {
                  final item = safeHourly[index];
                  return _buildHourlyItem(context, item, now);
                },
              ),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 12),
          ] else if (weather.morningCondition != null || weather.afternoonCondition != null || weather.nightCondition != null) ...[

            Row(
              children: [
                Expanded(child: _PeriodTile(label: 'Morning', condition: weather.morningCondition ?? '—', icon: Icons.wb_twilight_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _PeriodTile(label: 'Afternoon', condition: weather.afternoonCondition ?? '—', icon: Icons.wb_sunny_rounded)),
                const SizedBox(width: 8),
                Expanded(child: _PeriodTile(label: 'Night', condition: weather.nightCondition ?? '—', icon: Icons.nights_stay_rounded)),
              ],
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 12),
          ],

          _buildMetricsGrid(context),
        ],
      ),
    );
  }

  Widget _buildHourlyItem(BuildContext context, HourlyWeatherItem item, DateTime now) {
    final isCurrent = !item.isSunset && !item.isSunrise &&
        item.time.year == now.year &&
        item.time.month == now.month &&
        item.time.day == now.day &&
        item.time.hour == now.hour;
    final isSpecial = item.isSunset || item.isSunrise;

    final displayLabel = isCurrent
        ? 'Now'
        : (isSpecial
            ? item.timeLabel
            : DateFormat('h a').format(item.time).replaceAll(' ', ''));

    return Container(
      width: 62,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.cyanAccent(context).withValues(alpha: 0.14)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isCurrent
            ? Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [

          Text(
            displayLabel,
            style: AppTextStyles.bodySmall.copyWith(
              fontSize: isSpecial ? 10 : 11,
              fontWeight: isCurrent || isSpecial ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent
                  ? AppColors.cyanAccent(context)
                  : AppColors.secondaryText(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Icon(
              _hourlyIcon(item),
              size: isSpecial ? 22 : 21,
              color: isSpecial ? const Color(0xFFFBBF24) : Colors.white,
            ),
          ),

          if (isSpecial)
            Text(
              item.specialLabel ?? '',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          else
            Text(
              item.temperature != null ? '${item.temperature!.round()}°' : '—',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryText(context),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [

            Expanded(
              child: _LargeMetricCard(
                icon: Icons.wb_twilight_rounded,
                iconColor: const Color(0xFFFBBF24),
                label: 'Sunrise & Sunset',
                primaryValue: '🌅 ${weather.sunriseTime?.replaceAll(':00 ', ' ') ?? '07:05 AM'}',
                secondaryValue: '🌇 ${weather.sunsetTime?.replaceAll(':00 ', ' ') ?? '07:22 PM'}',
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: _LargeMetricCard(
                icon: Icons.thermostat_rounded,
                iconColor: const Color(0xFF38BDF8),
                label: 'Day Temp & Feels',
                primaryValue: weather.minTemperature != null && weather.maxTemperature != null
                    ? '${weather.minTemperature!.round()}°C – ${weather.maxTemperature!.round()}°C'
                    : '—',
                secondaryValue: weather.feelsLike != null
                    ? 'Feels like ${weather.feelsLike!.round()}°C'
                    : 'Normal heat index',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [

            Expanded(
              child: _LargeMetricCard(
                icon: Icons.water_drop_outlined,
                iconColor: AppColors.cyanAccent(context),
                label: 'Rain & Humidity',
                primaryValue: '${weather.precipitationProbability ?? 0}% Rain Chance',
                secondaryValue: '${weather.humidity ?? 0}% Humidity',
              ),
            ),
            const SizedBox(width: 10),

            Expanded(
              child: _LargeMetricCard(
                icon: Icons.wb_sunny_outlined,
                iconColor: const Color(0xFFF97316),
                label: 'UV Index',
                primaryValue: weather.uvIndex != null
                    ? '${weather.uvIndex!.toStringAsFixed(1)} ${_uvLabel(weather.uvIndex!)}'
                    : 'Moderate',
                secondaryValue: _uvAdvice(weather.uvIndex),
              ),
            ),
          ],
        ),
      ],
    );
  }

  IconData _hourlyIcon(HourlyWeatherItem item) {
    if (item.isSunset) return Icons.wb_twilight_rounded;
    if (item.isSunrise) return Icons.wb_sunny_rounded;

    final hour = item.time.hour;
    final isNight = hour < 6 || hour >= 19;

    if (isNight) {
      switch (item.iconCode) {
        case 'sunny': return Icons.nights_stay_rounded;
        case 'partly_cloudy': return Icons.nightlight_round;
        case 'cloudy': return Icons.cloud_outlined;
        case 'drizzle': return Icons.water_drop_outlined;
        case 'rain': return Icons.water_drop_rounded;
        case 'heavy_rain': return Icons.thunderstorm_outlined;
        case 'showers': return Icons.umbrella_rounded;
        case 'heavy_showers': return Icons.thunderstorm_outlined;
        case 'thunderstorm': return Icons.thunderstorm_rounded;
        case 'severe_thunderstorm': return Icons.bolt_rounded;
        case 'foggy':
        case 'hazy': return Icons.foggy;
        default: return Icons.nightlight_round;
      }
    }

    switch (item.iconCode) {
      case 'sunny': return Icons.wb_sunny_rounded;
      case 'partly_cloudy': return Icons.wb_cloudy_outlined;
      case 'cloudy': return Icons.cloud_rounded;
      case 'drizzle': return Icons.water_drop_outlined;
      case 'rain': return Icons.water_drop_rounded;
      case 'heavy_rain': return Icons.thunderstorm_outlined;
      case 'showers': return Icons.umbrella_rounded;
      case 'heavy_showers': return Icons.thunderstorm_outlined;
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      case 'severe_thunderstorm': return Icons.bolt_rounded;
      case 'foggy':
      case 'hazy': return Icons.foggy;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  IconData _weatherIcon(String iconCode) {
    final nowHour = DateTime.now().hour;
    final isNight = nowHour < 6 || nowHour >= 19;

    switch (iconCode) {
      case 'sunny': return isNight ? Icons.nights_stay_rounded : Icons.wb_sunny_rounded;
      case 'partly_cloudy': return isNight ? Icons.nightlight_round : Icons.wb_cloudy_outlined;
      case 'cloudy': return Icons.cloud_rounded;
      case 'drizzle': return Icons.water_drop_outlined;
      case 'rain': return Icons.water_drop_rounded;
      case 'heavy_rain': return Icons.thunderstorm_outlined;
      case 'showers': return Icons.umbrella_rounded;
      case 'heavy_showers': return Icons.thunderstorm_outlined;
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      case 'severe_thunderstorm': return Icons.bolt_rounded;
      case 'foggy':
      case 'hazy': return Icons.foggy;
      case 'sunset': return Icons.wb_twilight_rounded;
      case 'sunrise': return Icons.wb_sunny_rounded;
      default: return Icons.cloud_outlined;
    }
  }

  String _uvLabel(double uv) {
    if (uv <= 2) return 'Low';
    if (uv <= 5) return 'Moderate';
    if (uv <= 7) return 'High';
    if (uv <= 10) return 'Very High';
    return 'Extreme';
  }

  String _uvAdvice(double? uv) {
    if (uv == null) return 'Standard sun protection';
    if (uv <= 2) return 'No protection needed';
    if (uv <= 5) return 'Wear sunglasses & hat';
    if (uv <= 7) return 'Apply sunscreen SPF30+';
    if (uv <= 10) return 'Seek shade midday';
    return 'Avoid midday outdoor sun';
  }
}

class _LargeMetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String primaryValue;
  final String? secondaryValue;

  const _LargeMetricCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.primaryValue,
    this.secondaryValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            primaryValue,
            style: AppTextStyles.bodyMedium.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText(context),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (secondaryValue != null) ...[
            const SizedBox(height: 2),
            Text(
              secondaryValue!,
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                color: AppColors.secondaryText(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final String label;
  final String condition;
  final IconData icon;

  const _PeriodTile({required this.label, required this.condition, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white, size: 16),
        const SizedBox(height: 3),
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.secondaryText(context)),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          condition,
          style: AppTextStyles.titleSmall.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
