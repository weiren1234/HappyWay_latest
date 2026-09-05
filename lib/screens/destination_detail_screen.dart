import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../models/user_location.dart';
import '../models/weather_info.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/location_provider.dart';
import '../services/route_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/canonical_destination_id.dart';
import '../utils/travel_score_calculator.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/plan_trip_sheet.dart';
import '../widgets/destination_image_view.dart';
import '../widgets/hourly_weather_card.dart';
import 'travel_insights_screen.dart';

/// DestinationDetailScreen shows the full travel breakdown for a destination.
/// Displays official weather forecast data, Travel Suitability Score, and best travel period.
class DestinationDetailScreen extends StatefulWidget {
  final TravelDestination destination;
  final TravelRoute? route;
  final UserLocation? userOrigin;
  final WeatherInfo? initialWeather;

  const DestinationDetailScreen({
    super.key,
    required this.destination,
    this.route,
    this.userOrigin,
    this.initialWeather,
  });

  @override
  State<DestinationDetailScreen> createState() => _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scoreController;
  late Animation<double> _scoreAnimation;

  WeatherInfo? _weather;
  TravelRoute? _route;
  bool _isLoadingWeather = false;
  bool _isLoadingRoute = false;
  final RouteService _routeService = RouteService();

  @override
  void initState() {
    super.initState();
    _weather = widget.initialWeather ?? widget.destination.weather;
    _route = widget.route;

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
      final current = _resolveCurrentDest(destProvider);

      if (_weather == null) {
        _loadWeather(destProvider, current);
      }
      if (_route == null) {
        final origin = widget.userOrigin ?? Provider.of<LocationProvider>(context, listen: false).currentLocation;
        if (origin != null) {
          _loadRoute(origin, current);
        }
      }
    });
  }

  Future<void> _loadWeather(DestinationProvider provider, TravelDestination dest) async {
    if (mounted) setState(() => _isLoadingWeather = true);
    final w = await provider.fetchForecastForDestination(dest);
    if (mounted) {
      setState(() {
        _weather = w;
        _isLoadingWeather = false;
      });
    }
  }

  Future<void> _loadRoute(UserLocation origin, TravelDestination dest) async {
    final destLat = dest.latitude;
    final destLng = dest.longitude;
    if (destLat == null || destLng == null || destLat == 0.0 || destLng == 0.0) return;

    if (mounted) setState(() => _isLoadingRoute = true);
    try {
      final result = await _routeService.calculateRouteDetails(
        originName: origin.name,
        originLat: origin.latitude,
        originLng: origin.longitude,
        destName: dest.name,
        destLat: destLat,
        destLng: destLng,
      );
      if (mounted) {
        setState(() {
          _route = result.route;
          _isLoadingRoute = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  TravelDestination _resolveCurrentDest(DestinationProvider destProvider) {
    final canonicalTarget = CanonicalDestinationId.fromDestination(widget.destination);
    return destProvider.allDestinations.where(
      (item) => CanonicalDestinationId.fromDestination(item) == canonicalTarget,
    ).firstOrNull ?? (
      destProvider.recommendations.map((r) => r.destination).where(
        (item) => CanonicalDestinationId.fromDestination(item) == canonicalTarget,
      ).firstOrNull ?? widget.destination
    );
  }

  @override
  void dispose() {
    _scoreController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destProvider = Provider.of<DestinationProvider>(context);
    final currentDest = _resolveCurrentDest(destProvider);
    final weather = _weather ?? currentDest.weather;
    final isSaved = destProvider.isDestinationSaved(currentDest);

    final travelScore = weather != null
        ? TravelScoreCalculator.calculateScore(
            weather: weather,
            route: _route,
            activityTags: currentDest.activityTags,
            travelDate: DateTime.now(),
          )
        : null;

    final scoreColor = travelScore?.color ?? AppColors.cyanAccent(context);

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
                    isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                    color: isSaved ? AppColors.cyanAccent(context) : Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () async {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (!auth.isAuthenticated || auth.isGuest) {
                    AuthPromptDialog.show(context);
                    return;
                  }
                  final success = await destProvider.toggleSaveAnyDestination(currentDest);
                  if (!success && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Unable to update saved destinations. Please check your network connection.'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
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
                  _buildScoreCard(context, travelScore, scoreColor),
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

                  // ── Weather Forecast ─────────────────────────────────────
                  _SectionHeader(
                    title: 'Weather Forecast',
                    trailing: Text(
                      'Source: MET Malaysia',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _MetForecastCard(weather: weather),
                  const SizedBox(height: 20),

                  // ── Full Travel Insights CTA ──────────────────────────────
                  GlassCard(
                    onTap: () {
                      final locProvider = Provider.of<LocationProvider>(context, listen: false);
                      final origin = widget.userOrigin ?? locProvider.currentLocation;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TravelInsightsScreen(
                            destination: currentDest,
                            initialWeather: weather,
                            route: _route,
                            userOrigin: origin,
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
                                'Detailed forecast, morning/afternoon/night conditions, and trip advice.',
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
                    final origin = widget.userOrigin ?? locProvider.currentLocation;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TravelInsightsScreen(
                          destination: currentDest,
                          initialWeather: weather,
                          route: _route,
                          userOrigin: origin,
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

  Widget _buildScoreCard(BuildContext context, TravelScore? travelScore, Color scoreColor) {
    final hasScore = travelScore != null;
    final isRouteComplete = _route != null;

    final formattedToday = DateFormat('d MMM').format(DateTime.now());
    final title = isRouteComplete ? "Today's Travel Score" : "Today's Weather Suitability";
    final badgeLabel = hasScore
        ? travelScore.levelName
        : (_isLoadingWeather ? 'Loading forecast...' : 'Awaiting forecast');
    final recommendation = hasScore
        ? travelScore.recommendation
        : (_isLoadingWeather
            ? 'Checking latest weather forecast...'
            : 'Forecast data currently unavailable.');
    final bestPeriod = hasScore
        ? travelScore.bestTravelPeriod
        : 'Pending forecast';

    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              // Animated score ring
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (context, _) {
                  final rawScore = hasScore ? travelScore.score : 0;
                  final progress = (rawScore / 100.0) * _scoreAnimation.value;
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
                            if (hasScore) ...[
                              Text(
                                '${(rawScore * _scoreAnimation.value).round()}',
                                style: AppTextStyles.titleLarge.copyWith(
                                  color: scoreColor,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                isRouteComplete ? '/100' : 'Weather / 100',
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 9, color: AppColors.mutedText(context)),
                              ),
                            ] else ...[
                              if (_isLoadingWeather)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: scoreColor),
                                )
                              else
                                Text(
                                  '--',
                                  style: AppTextStyles.titleLarge.copyWith(
                                    color: AppColors.mutedText(context),
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                            ],
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
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: Text(
                            'Today · $formattedToday',
                            style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.cyanAccent(context), fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (_isLoadingRoute) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.cyanAccent(context)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        badgeLabel,
                        style: AppTextStyles.badgeLabel.copyWith(color: scoreColor),
                      ),
                    ),
                    if (_route != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${_route!.durationFormatted} • ${_route!.distanceFormatted}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.cyanAccent(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ] else if (!_isLoadingRoute) ...[
                      const SizedBox(height: 4),
                      Text(
                        '(Weather only — route estimates unavailable)',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.mutedText(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      recommendation,
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
                      const TextSpan(text: 'Best Time Today: '),
                      TextSpan(
                        text: bestPeriod,
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
    );
  }
}

// ─── MET Forecast Card ───────────────────────────────────────────────────────

class _MetForecastCard extends StatelessWidget {
  final WeatherInfo? weather;
  const _MetForecastCard({required this.weather});

  @override
  Widget build(BuildContext context) {
    if (weather == null) {
      return GlassCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Loading weather forecast…', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context))),
              ),
            ],
          ),
        ),
      );
    }

    return HourlyWeatherCard(
      weather: weather!,
      title: 'Weather',
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
