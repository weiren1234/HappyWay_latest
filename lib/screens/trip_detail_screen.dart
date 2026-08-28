import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/planned_trip.dart';
import '../models/weather_info.dart';
import '../models/travel_route.dart';
import '../models/travel_score.dart';
import '../providers/trip_provider.dart';
import '../services/weather_service.dart';
import '../services/route_service.dart';
import '../utils/travel_score_calculator.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/plan_trip_sheet.dart';
import '../widgets/destination_image_view.dart';

/// TripDetailScreen provides the complete breakdown of an explicitly planned trip:
/// - Route information (OSRM distance & driving duration)
/// - Official MET Malaysia forecast (if within official 7-day forecast window)
/// - HappyWay Travel Suitability Score & departure advice (if forecast available)
/// - Personal trip notes & management actions (Edit, Delete, Refresh)
class TripDetailScreen extends StatefulWidget {
  final PlannedTrip trip;

  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  late PlannedTrip _trip;
  WeatherInfo? _weather;
  TravelRoute? _route;
  bool _isLoadingWeather = false;
  bool _isLoadingRoute = false;
  String? _routeError;

  final WeatherService _weatherService = WeatherService();
  final RouteService _routeService = RouteService();

  @override
  void initState() {
    super.initState();
    _trip = widget.trip;
    _loadTripData();
  }

  Future<void> _loadTripData({bool forceRefresh = false}) async {
    // 1. Load Route (if coordinates available)
    _loadRoute(forceRefresh: forceRefresh);

    // 2. Load Official Forecast (if within forecast horizon)
    if (_trip.isWithinForecastRange) {
      _loadForecast(forceRefresh: forceRefresh);
    }
  }

  String? get _effectiveMETLocationId {
    final id = _trip.destinationLocationId;
    if (id.startsWith('LOCATION:')) return id;
    if (id.startsWith('met:')) return id.substring(4);
    return null;
  }

  Future<void> _loadForecast({bool forceRefresh = false}) async {
    final metId = _effectiveMETLocationId;
    if (metId == null) {
      if (mounted) {
        setState(() {
          _weather = null;
          _isLoadingWeather = false;
        });
      }
      return;
    }

    setState(() => _isLoadingWeather = true);
    try {
      final weather = await _weatherService.fetchWeatherForLocationAndDate(
        metId,
        _trip.travelDate,
        forceRefresh: forceRefresh,
      );
      if (mounted) {
        setState(() {
          _weather = weather;
          _isLoadingWeather = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingWeather = false);
    }
  }

  Future<void> _loadRoute({bool forceRefresh = false}) async {
    final origLat = _trip.originLatitude;
    final origLng = _trip.originLongitude;
    final destLat = _trip.destinationLatitude;
    final destLng = _trip.destinationLongitude;

    if (origLat == null || origLng == null || destLat == null || destLng == null) {
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    final result = await _routeService.calculateRouteDetails(
      originName: _trip.originName,
      originLat: origLat,
      originLng: origLng,
      destName: _trip.destinationName,
      destLat: destLat,
      destLng: destLng,
      forceRefresh: forceRefresh,
    );
    if (mounted) {
      setState(() {
        _route = result.route;
        _isLoadingRoute = false;
        _routeError = result.errorMessage;
      });
    }
  }

  void _editTrip() async {
    final updated = await PlanTripSheet.show(
      context,
      destinationLocationId: _trip.destinationLocationId,
      destinationName: _trip.destinationName,
      destinationState: _trip.destinationState,
      destinationCategory: _trip.destinationCategory,
      destinationLatitude: _trip.destinationLatitude,
      destinationLongitude: _trip.destinationLongitude,
      destinationImageUrl: _trip.destinationImageUrl,
      initialTrip: _trip,
    );

    if (updated != null && mounted) {
      setState(() => _trip = updated);
      _loadTripData(forceRefresh: true);
    }
  }

  void _deleteTrip() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
        title: Text('Delete Trip?', style: TextStyle(color: AppColors.primaryText(context))),
        content: Text(
          'Are you sure you want to delete your trip to ${_trip.destinationName} on ${_trip.formattedDate}?',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(context))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted && _trip.id != null) {
      final tripProvider = Provider.of<TripProvider>(context, listen: false);
      await tripProvider.deleteTrip(_trip.id!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip to ${_trip.destinationName} (${_trip.tripCode}) deleted.', style: TextStyle(color: AppColors.primaryText(context))),
            backgroundColor: AppColors.cardBg(context),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  IconData _weatherIcon(String iconCode) {
    switch (iconCode) {
      case 'thunderstorm': return Icons.thunderstorm_rounded;
      case 'rain': return Icons.grain_rounded;
      case 'sunny': return Icons.wb_sunny_rounded;
      case 'cloudy': return Icons.wb_cloudy_rounded;
      case 'partly_cloudy': return Icons.wb_cloudy_outlined;
      case 'foggy': return Icons.foggy;
      default: return Icons.wb_cloudy_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = _trip.destinationImageUrl != null && _trip.destinationImageUrl!.isNotEmpty;
    final travelScore = _weather != null
        ? TravelScoreCalculator.calculateScore(
            weather: _weather,
            route: _route,
            preferredPeriod: _trip.preferredPeriod,
          )
        : null;

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // ── App Bar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppColors.scaffoldBg(context),
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceGlass(context),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.borderGlass(context)),
                ),
                child: Icon(Icons.arrow_back_rounded, color: AppColors.primaryText(context), size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text('Trip Details', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGlass(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.borderGlass(context)),
                  ),
                  child: Icon(Icons.edit_outlined, color: AppColors.primaryText(context), size: 18),
                ),
                onPressed: _editTrip,
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerRed.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.dangerRed.withValues(alpha: 0.4)),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.dangerRed, size: 18),
                ),
                onPressed: _deleteTrip,
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Body ───────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Destination Header Banner
                  if (hasImage)
                    _buildImageHeader()
                  else
                    _buildGradientHeader(),
                  const SizedBox(height: 16),

                  // 2. Trip Overview Box (Date, Days Until, Origin, Preferred Period)
                  _buildOverviewCard(),
                  const SizedBox(height: 14),

                  // 3. Route Section (Distance & Estimated Driving Time via OSRM)
                  _buildRouteCard(),
                  const SizedBox(height: 14),

                  // 4. Official MET Malaysia Forecast Section
                  _buildForecastSection(),
                  const SizedBox(height: 14),

                  // 5. HappyWay Recommendation & Score (only when forecast available)
                  if (travelScore != null) ...[
                    _buildTravelScoreCard(travelScore),
                    const SizedBox(height: 14),
                  ],

                  // 6. Personal Notes Section
                  _buildNotesCard(),
                  const SizedBox(height: 14),

                  // 7. Disclaimer
                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Header Builders ─────────────────────────────────────────────────────────

  Widget _buildImageHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          DestinationImageView(
            name: _trip.destinationName,
            state: _trip.destinationState,
            locationId: _trip.destinationLocationId,
            imageUrl: _trip.destinationImageUrl,
            height: 160,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
              ),
            ),
          ),
          Positioned(
            bottom: 14, left: 14, right: 14,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentCyan.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.accentCyan.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${_trip.destinationState} • ${_trip.destinationCategory}',
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_trip.destinationName, style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientHeader() {
    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent(context).withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.3)),
            ),
            child: Icon(Icons.location_city_rounded, color: AppColors.cyanAccent(context), size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_trip.destinationName, style: AppTextStyles.titleLarge.copyWith(fontSize: 20, color: AppColors.primaryText(context))),
                const SizedBox(height: 4),
                Text('${_trip.destinationState} • ${_trip.destinationCategory}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context))),
                const SizedBox(height: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.weatherBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text('Official MET Malaysia Location', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 10, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Overview Card ───────────────────────────────────────────────────────────

  Widget _buildOverviewCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.blueAccent(context), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('Trip Schedule', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.cyanAccent(context).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _trip.tripCode,
                      style: TextStyle(
                        color: AppColors.cyanAccent(context),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _trip.isToday
                      ? AppColors.safeGreen.withValues(alpha: 0.2)
                      : _trip.isPast
                          ? AppColors.surfaceGlass(context)
                          : AppColors.weatherBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _trip.isToday
                        ? AppColors.safeGreen.withValues(alpha: 0.6)
                        : AppColors.borderGlass(context),
                  ),
                ),
                child: Text(
                  _trip.relativeDateLabel,
                  style: TextStyle(
                    color: _trip.isToday ? AppColors.safeGreen : (_trip.isPast ? AppColors.mutedText(context) : Colors.white),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Date & Weekday Row
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.calendar_month_rounded,
                  label: 'Date',
                  value: _trip.formattedDate,
                  color: AppColors.blueAccent(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: Icons.access_time_rounded,
                  label: 'Preferred Period',
                  value: '${_trip.preferredPeriod} Trip',
                  color: AppColors.cyanAccent(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Origin Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surfaceGlass(context),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderGlass(context)),
            ),
            child: Row(
              children: [
                const Icon(Icons.my_location_rounded, size: 14, color: AppColors.safeGreen),
                const SizedBox(width: 8),
                Text('Starting From: ', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context))),
                Expanded(
                  child: Text(
                    _trip.originName,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Route Card ──────────────────────────────────────────────────────────────

  Widget _buildRouteCard() {
    final hasCoordinates = _trip.originLatitude != null && _trip.destinationLatitude != null;

    if (!hasCoordinates && _route == null) {
      return const SizedBox.shrink();
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.cyanAccent(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Driving Route', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingRoute)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
                    const SizedBox(width: 10),
                    Text('Calculating driving distance...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 12)),
                  ],
                ),
              ),
            )
          else if (_routeError != null)
            Text(_routeError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.dangerRed))
          else if (_route != null) ...[
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon: Icons.route_rounded,
                    label: 'Distance',
                    value: _route!.distanceFormatted,
                    color: AppColors.blueAccent(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoTile(
                    icon: Icons.schedule_rounded,
                    label: 'Est. Drive Time',
                    value: _route!.durationFormatted,
                    color: AppColors.cyanAccent(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '* Estimated normal driving duration, not live traffic data',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context), fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Official Forecast Section ────────────────────────────────────────────────

  Widget _buildForecastSection() {
    if (!_trip.isWithinForecastRange) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.weatherBlue.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.calendar_today_rounded, color: AppColors.cyanAccent(context), size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Official Forecast Horizon', style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                  const SizedBox(height: 4),
                  Text(
                    'Official MET Malaysia forecasts cover up to 7 days ahead. Official forecast data will be available closer to your travel date on ${_trip.formattedDate}.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingWeather) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
              const SizedBox(width: 12),
              Text('Retrieving official MET Malaysia forecast...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
            ],
          ),
        ),
      );
    }

    if (_weather == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.cautionAmber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Official MET forecast currently unavailable for this date. Check network connection.',
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
              ),
            ),
            TextButton(
              onPressed: () => _loadForecast(forceRefresh: true),
              child: Text('Retry', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 12)),
            ),
          ],
        ),
      );
    }

    final weather = _weather!;
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.cloud_outlined, color: AppColors.cyanAccent(context), size: 17),
                  const SizedBox(width: 7),
                  Text('MET Malaysia Forecast', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.cyanAccent(context).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Official MET API', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weather Summary
          Row(
            children: [
              Icon(_weatherIcon(weather.iconCode), size: 36, color: const Color(0xFFFBBF24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      weather.minTemperature != null && weather.maxTemperature != null
                          ? '${weather.minTemperature!.round()}°C – ${weather.maxTemperature!.round()}°C'
                          : weather.temperature != null ? '${weather.temperature!.round()}°C' : '—',
                      style: AppTextStyles.titleLarge.copyWith(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primaryText(context)),
                    ),
                    Text(weather.condition, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.cyanAccent(context), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 10),

          // Morning / Afternoon / Night Periods
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _PeriodTile(label: 'Morning', condition: weather.morningCondition ?? '—', icon: Icons.wb_twilight_rounded),
              _PeriodTile(label: 'Afternoon', condition: weather.afternoonCondition ?? '—', icon: Icons.wb_sunny_rounded),
              _PeriodTile(label: 'Night', condition: weather.nightCondition ?? '—', icon: Icons.nights_stay_rounded),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Travel Score Card ────────────────────────────────────────────────────────

  Widget _buildTravelScoreCard(TravelScore score) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.explore_outlined, color: AppColors.cyanAccent(context), size: 17),
                  const SizedBox(width: 7),
                  Text('Travel Suitability', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
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
                  style: TextStyle(color: score.color, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(score.recommendation, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), height: 1.4)),

          if (score.preferredPeriodComparison != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.weatherBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded, color: AppColors.weatherBlue, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      score.preferredPeriodComparison!,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.primaryText(context), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (score.recommendedDeparture != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.cyanAccent(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.departure_board_rounded, color: AppColors.cyanAccent(context), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Suggested Departure: ${score.recommendedDeparture}',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.cyanAccent(context), fontWeight: FontWeight.w600, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (score.explanationBullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 10),
            ...score.explanationBullets.take(3).map((b) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
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
                          b.startsWith('• ') ? b.substring(2) : b,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // ─── Notes Card ───────────────────────────────────────────────────────────────

  Widget _buildNotesCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.note_alt_outlined, color: AppColors.cyanAccent(context), size: 17),
                  const SizedBox(width: 7),
                  Text('Personal Notes', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                ],
              ),
              GestureDetector(
                onTap: _editTrip,
                child: Text(
                  _trip.notes != null && _trip.notes!.isNotEmpty ? 'Edit' : 'Add Note',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_trip.notes != null && _trip.notes!.isNotEmpty)
            Text(
              _trip.notes!,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context), height: 1.45),
            )
          else
            Text(
              'No personal notes added for this trip yet. Tap "Add Note" to record activities or packing reminders.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Text(
        'Travel Suitability and Departure suggestions are HappyWay rule-based recommendations derived from official MET Malaysia forecasts. They do not constitute official statements.',
        style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(height: 4),
          Text(value, style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
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
      children: [
        Icon(icon, color: AppColors.cyanAccent(context), size: 16),
        const SizedBox(height: 3),
        Text(label, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.secondaryText(context))),
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
