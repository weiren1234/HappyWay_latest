import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/weather_info.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/plan_trip_sheet.dart';
import '../widgets/destination_image_view.dart';
import 'travel_insights_screen.dart';

/// DestinationDetailScreen shows the full travel breakdown for a featured destination.
/// Displays official MET Malaysia weather forecast data, Travel Suitability Score, and best travel period.
class DestinationDetailScreen extends StatefulWidget {
  final TravelDestination destination;

  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _scoreController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scoreAnimation = CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic);
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _scoreController.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destProvider = Provider.of<DestinationProvider>(context, listen: false);
      final current = destProvider.allDestinations.where(
        (item) => item.id == widget.destination.id,
      ).firstOrNull ?? widget.destination;
      if (current.weather == null) {
        destProvider.fetchForecastForDestination(current);
      }
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destProvider = Provider.of<DestinationProvider>(context);
    final currentDest = destProvider.allDestinations.where(
      (item) => item.id == widget.destination.id,
    ).firstOrNull ?? widget.destination;

    final weather = currentDest.weather;
    final score = currentDest.travelScore;
    final scoreColor = score.color;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: AppColors.scaffoldBg(context),
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Icon(
                    currentDest.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: currentDest.isSaved ? AppColors.cyanAccent(context) : Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (auth.isGuest) {
                    AuthPromptDialog.show(context);
                    return;
                  }
                  destProvider.toggleSaveFeaturedDestination(currentDest.id);
                },
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  DestinationImageView(
                    name: currentDest.name,
                    state: currentDest.state,
                    locationId: currentDest.metLocationId.isNotEmpty ? currentDest.metLocationId : currentDest.id,
                    imageUrl: currentDest.imageUrl,
                    width: double.infinity,
                    height: 340,
                    fit: BoxFit.cover,
                    showAttribution: true,
                    heroTag: 'dest_img_${currentDest.id}',
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.2),
                            AppColors.scaffoldBg(context).withValues(alpha: 0.97),
                          ],
                          stops: const [0.3, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 24,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Text(
                            currentDest.category.toUpperCase(),
                            style: AppTextStyles.badgeLabel.copyWith(color: AppColors.cyanAccent(context)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(currentDest.name, style: AppTextStyles.titleHero.copyWith(color: AppColors.primaryText(context))),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined, color: AppColors.cyanAccent(context), size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${currentDest.state}, Malaysia',
                              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
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

          // ── Body ─────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Animated Travel Suitability Score Card ────────────────
                  GlassCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            // Animated score ring
                            AnimatedBuilder(
                              animation: _scoreAnimation,
                              builder: (context, _) {
                                final progress = (score.score / 100.0) * _scoreAnimation.value;
                                return SizedBox(
                                  width: 88,
                                  height: 88,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CustomPaint(
                                        size: const Size(88, 88),
                                        painter: _ScoreRingPainter(
                                          progress: progress,
                                          color: scoreColor,
                                          backgroundColor: scoreColor.withValues(alpha: 0.12),
                                        ),
                                      ),
                                      Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${(score.score * _scoreAnimation.value).round()}',
                                            style: AppTextStyles.titleLarge.copyWith(
                                              color: scoreColor,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            '/100',
                                            style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Travel Suitability', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context))),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: scoreColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                                    ),
                                    child: Text(
                                      score.levelName,
                                      style: AppTextStyles.badgeLabel.copyWith(color: scoreColor),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    score.recommendation,
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Divider(height: 1, color: AppColors.dividerColor(context)),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Icon(Icons.schedule_rounded, color: AppColors.cyanAccent(context), size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                                  children: [
                                    const TextSpan(text: 'Best Time to Travel: '),
                                    TextSpan(
                                      text: score.bestTravelPeriod,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        color: AppColors.cyanAccent(context),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Description ───────────────────────────────────────────
                  Text('About This Destination', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                  const SizedBox(height: 10),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentDest.description,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.primaryText(context),
                            height: 1.55,
                          ),
                        ),
                        if (currentDest.activityTags.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: currentDest.activityTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.weatherBlue.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  '#$tag',
                                  style: TextStyle(
                                    color: AppColors.cyanAccent(context),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── MET Malaysia Official Forecast ────────────────────────
                  _SectionHeader(
                    title: 'MET Malaysia Forecast',
                    trailing: Row(
                      children: [
                        Icon(Icons.cloud_done_outlined, color: AppColors.blueAccent(context), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Official API',
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MetForecastCard(weather: weather),
                  const SizedBox(height: 20),

                  // ── Full Travel Insights CTA ──────────────────────────────
                  GlassCard(
                    onTap: () {
                      final locProvider = Provider.of<LocationProvider>(context, listen: false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TravelInsightsScreen(
                            destination: currentDest,
                            userOrigin: locProvider.currentLocation,
                          ),
                        ),
                      );
                    },
                    backgroundColor: AppColors.weatherBlue.withValues(alpha: 0.08),
                    borderColor: AppColors.weatherBlue.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.weatherBlue.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.insights_rounded, color: AppColors.weatherBlue, size: 20),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Full Travel Analysis', style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                              Text(
                                'Detailed MET forecast, morning/afternoon/night conditions, and trip advice.',
                                style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context).withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: AppColors.borderGlass(context))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final locProvider = Provider.of<LocationProvider>(context, listen: false);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelInsightsScreen(
                          destination: currentDest,
                          initialWeather: currentDest.weather,
                          userOrigin: locProvider.currentLocation,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.analytics_outlined, size: 16),
                  label: const Text('Analyze', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyanAccent(context),
                    side: BorderSide(color: AppColors.cyanAccent(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (auth.isGuest) {
                      AuthPromptDialog.show(context);
                      return;
                    }
                    PlanTripSheet.show(
                      context,
                      initialDestination: TravelLocation.fromFeaturedDestination(currentDest),
                    );
                  },
                  icon: const Icon(Icons.luggage_rounded, size: 18),
                  label: const Text('Plan This Trip', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.weatherBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── MET Forecast Card ───────────────────────────────────────────────────────

class _MetForecastCard extends StatelessWidget {
  final WeatherInfo? weather;
  const _MetForecastCard({required this.weather});

  IconData _icon(String? code) {
    switch (code) {
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
      default:
        return Icons.cloud_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_icon(weather?.iconCode), size: 44, color: const Color(0xFFFBBF24)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (weather?.maxTemperature != null)
                      Text(
                        '${weather!.maxTemperature!.round()}°C',
                        style: AppTextStyles.titleHero.copyWith(fontSize: 36, color: AppColors.primaryText(context)),
                      ),
                    Text(
                      weather?.condition ?? 'Loading forecast…',
                      style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cyanAccent(context)),
                    ),
                  ],
                ),
              ),
              if (weather?.minTemperature != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Range Today', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context))),
                    Text(
                      '${weather!.minTemperature!.round()}° – ${weather!.maxTemperature!.round()}°C',
                      style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context)),
                    ),
                  ],
                ),
            ],
          ),
          if (weather != null &&
              (weather!.morningCondition != null ||
                  weather!.afternoonCondition != null ||
                  weather!.nightCondition != null)) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _PeriodTile(
                  label: 'Morning',
                  condition: weather!.morningCondition ?? '—',
                  icon: Icons.wb_twilight_rounded,
                ),
                _PeriodTile(
                  label: 'Afternoon',
                  condition: weather!.afternoonCondition ?? '—',
                  icon: Icons.wb_sunny_rounded,
                ),
                _PeriodTile(
                  label: 'Night',
                  condition: weather!.nightCondition ?? '—',
                  icon: Icons.nights_stay_rounded,
                ),
              ],
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

  const _PeriodTile({
    required this.label,
    required this.condition,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: AppColors.cyanAccent(context), size: 18),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context))),
        const SizedBox(height: 2),
        Text(
          condition,
          style: AppTextStyles.titleSmall.copyWith(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ─── Score Ring Painter ───────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    const strokeWidth = 8.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * math.pi * progress;
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
        ?trailing,
      ],
    );
  }
}
