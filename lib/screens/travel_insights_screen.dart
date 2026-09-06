import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/met_location.dart';
import '../models/weather_info.dart';
import '../models/travel_score.dart';
import '../models/travel_route.dart';
import '../models/user_location.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/location_provider.dart';
import '../services/route_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/create_trip_sheet.dart';
import '../widgets/destination_image_view.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/hourly_weather_card.dart';
import '../utils/travel_score_calculator.dart';
import '../utils/canonical_destination_id.dart';

class TravelInsightsScreen extends StatefulWidget {
  final TravelLocation? travelLocation;
  final TravelDestination? destination;
  final MetLocation? metLocation;
  final WeatherInfo? initialWeather;
  final TravelRoute? route;
  final UserLocation? userOrigin;

  const TravelInsightsScreen({
    super.key,
    this.travelLocation,
    this.destination,
    this.metLocation,
    this.initialWeather,
    this.route,
    this.userOrigin,
  }) : assert(travelLocation != null || destination != null || metLocation != null,
            'Either travelLocation, destination, or metLocation must be provided');

  @override
  State<TravelInsightsScreen> createState() => _TravelInsightsScreenState();
}

class _TravelInsightsScreenState extends State<TravelInsightsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  WeatherInfo? _weather;
  TravelRoute? _route;
  bool _isLoadingWeather = false;
  bool _isLoadingRoute = false;
  String? _weatherError;
  String? _routeError;

  final RouteService _routeService = RouteService();

  UserLocation? get _effectiveOrigin =>
      widget.userOrigin ?? Provider.of<LocationProvider>(context, listen: false).currentLocation;

  String get _locationName =>
      widget.travelLocation?.name ??
      widget.destination?.name ??
      widget.metLocation?.formattedName ??
      'Unknown';

  String get _locationState =>
      widget.travelLocation?.state ??
      widget.destination?.state ??
      widget.metLocation?.state ??
      'Malaysia';

  String get _locationCategory =>
      widget.travelLocation?.category ??
      widget.destination?.category ??
      widget.metLocation?.categoryLabel ??
      'Destination';

  String get _locationId =>
      widget.travelLocation?.id ??
      widget.destination?.id ??
      widget.metLocation?.id ??
      '';

  String? get _metLocationName =>
      widget.travelLocation?.metLocationName ??
      widget.destination?.name ??
      widget.metLocation?.formattedName;

  bool get _hasWeatherLocation =>
      widget.travelLocation != null ? widget.travelLocation!.hasWeatherLocation : true;

  bool get _isFeatured => widget.destination != null;
  String? get _imageUrl => widget.travelLocation?.imageUrl ?? widget.destination?.imageUrl;

  String get _originName => _effectiveOrigin?.name ?? 'Current Location';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeOut);
    _animationController.forward();

    _weather = widget.initialWeather ?? widget.destination?.weather;
    _route = widget.route;

    if (_weather == null) {
      _loadOfficialForecast();
    }

    if (_route == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadRoute();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOfficialForecast({bool forceRefresh = false}) async {
    if (!_hasWeatherLocation) {
      setState(() {
        _weather = null;
        _isLoadingWeather = false;
      });
      return;
    }

    setState(() {
      _isLoadingWeather = true;
      _weatherError = null;
    });

    final destProvider = Provider.of<DestinationProvider>(context, listen: false);

    WeatherInfo? weather;
    if (widget.travelLocation != null) {
      weather = await destProvider.fetchForecastForTravelLocation(widget.travelLocation!, forceRefresh: forceRefresh);
    } else if (widget.destination != null) {
      weather = await destProvider.fetchForecastForDestination(widget.destination!, forceRefresh: forceRefresh);
    } else if (widget.metLocation != null) {
      weather = await destProvider.fetchForecastForMetLocation(widget.metLocation!, forceRefresh: forceRefresh);
    }

    if (mounted) {
      setState(() {
        _weather = weather;
        _isLoadingWeather = false;
        if (weather == null && _hasWeatherLocation) {
          _weatherError = 'Unable to load the latest weather forecast. Please check your connection and try again.';
        }
      });
    }
  }

  Future<void> _loadRoute({bool forceRefresh = false}) async {
    final origin = _effectiveOrigin;
    final destLat = widget.travelLocation?.latitude ??
        widget.metLocation?.latitude ??
        widget.destination?.latitude;
    final destLng = widget.travelLocation?.longitude ??
        widget.metLocation?.longitude ??
        widget.destination?.longitude;

    if (origin == null ||
        destLat == null ||
        destLng == null ||
        destLat == 0.0 ||
        destLng == 0.0 ||
        origin.latitude == 0.0 ||
        origin.longitude == 0.0) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          if (origin == null) {
            _routeError = null;
          } else {
            _routeError = 'Route unavailable — destination coordinates missing.';
          }
        });
      }
      return;
    }

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    final result = await _routeService.calculateRouteDetails(
      originName: origin.name,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destName: _locationName,
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

  @override
  Widget build(BuildContext context) {
    final destProvider = Provider.of<DestinationProvider>(context);
    final isSaved = widget.destination != null
        ? destProvider.isDestinationSaved(widget.destination!)
        : (widget.travelLocation != null
            ? destProvider.isLocationSaved(CanonicalDestinationId.fromTravelLocation(widget.travelLocation!))
            : destProvider.isLocationSaved(_locationId));
    final travelScore = TravelScoreCalculator.calculateScore(
      weather: _weather,
      route: _route,
      activityTags: widget.destination?.activityTags,
      travelDate: DateTime.now(),
    );

    return Scaffold(
      backgroundColor: AppColors.scaffoldBg(context),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [

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
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Travel Analysis', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                  Text(
                    'Today · ${DateFormat('d MMM').format(DateTime.now())}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.cyanAccent(context), fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
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
                    child: Icon(Icons.refresh_rounded, color: AppColors.primaryText(context), size: 18),
                  ),
                  onPressed: (_isLoadingWeather || _isLoadingRoute) ? null : () {
                    _loadOfficialForecast(forceRefresh: true);
                    _loadRoute(forceRefresh: true);
                  },
                ),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSaved ? AppColors.accentCyan.withValues(alpha: 0.2) : AppColors.surfaceGlass(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: isSaved ? AppColors.accentCyan : AppColors.borderGlass(context)),
                    ),
                    child: Icon(
                      isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                      color: isSaved ? AppColors.cyanAccent(context) : AppColors.primaryText(context),
                      size: 18,
                    ),
                  ),
                  onPressed: () async {
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    if (!auth.isAuthenticated || auth.isGuest) {
                      AuthPromptDialog.show(context);
                      return;
                    }
                    bool success = false;
                    if (widget.destination != null) {
                      success = await destProvider.toggleSaveAnyDestination(widget.destination!);
                    } else if (widget.travelLocation != null) {
                      success = await destProvider.toggleSaveTravelLocation(widget.travelLocation!);
                    } else if (widget.metLocation != null) {
                      success = await destProvider.toggleSaveMetLocation(widget.metLocation!);
                    }
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
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    if (_isFeatured && _imageUrl != null)
                      _buildFeaturedHeader()
                    else if (widget.travelLocation?.source == TravelLocationSource.geocodedPlace)
                      _buildGeocodedHeader()
                    else
                      _buildSearchedHeader(),
                    const SizedBox(height: 18),

                    _buildTripSummaryCard(),
                    const SizedBox(height: 14),

                    if (_isLoadingWeather)
                      _buildLoadingCard()
                    else if (_weatherError != null)
                      _buildWeatherErrorCard()
                    else ...[
                      _buildTravelScoreCard(travelScore),
                      const SizedBox(height: 14),

                      _buildForecastCard(),
                      const SizedBox(height: 14),

                      _buildDepartureCard(travelScore),
                      const SizedBox(height: 14),

                      _buildScoreBreakdownCard(travelScore),
                      const SizedBox(height: 14),

                      _buildRecommendationsCard(travelScore),
                      const SizedBox(height: 14),

                      _buildDisclaimer(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        decoration: BoxDecoration(
          color: AppColors.cardBg(context).withValues(alpha: 0.95),
          border: Border(top: BorderSide(color: AppColors.borderGlass(context))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (!auth.isAuthenticated || auth.isGuest) {
                  AuthPromptDialog.show(context);
                  return;
                }
                final travelLoc = widget.travelLocation ??
                    (widget.destination != null
                        ? TravelLocation.fromFeaturedDestination(widget.destination!)
                        : (widget.metLocation != null
                            ? TravelLocation.fromMetLocation(widget.metLocation!)
                            : null));
                CreateTripSheet.show(
                  context,
                  initialDestination: travelLoc,
                );
              },
              icon: const Icon(Icons.luggage_rounded, size: 18),
              label: const Text(
                'Plan This Trip',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.weatherBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          DestinationImageView(
            name: _locationName,
            state: _locationState,
            locationId: _locationId,
            imageUrl: _imageUrl,
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
                    '$_locationState • $_locationCategory',
                    style: const TextStyle(color: AppColors.accentCyan, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 6),
                Text(_locationName, style: AppTextStyles.titleLarge.copyWith(color: Colors.white, fontSize: 22)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeocodedHeader() {
    const badgeColor = Color(0xFF00E676);
    final formattedAddr = widget.travelLocation?.formattedAddress;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: badgeColor.withValues(alpha: 0.3),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.location_on_rounded, color: badgeColor, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_locationName, style: AppTextStyles.titleLarge.copyWith(fontSize: 20)),
                const SizedBox(height: 4),
                if (formattedAddr != null && formattedAddr.isNotEmpty && formattedAddr != _locationName)
                  Text(
                    formattedAddr,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Detailed Place • $_locationState',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _hasWeatherLocation
                        ? 'Exact Coordinates • Weather: ${_metLocationName ?? _locationState}'
                        : 'Exact GPS Coordinates',
                    style: const TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchedHeader() {
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
                Text(_locationName, style: AppTextStyles.titleLarge.copyWith(fontSize: 20, color: AppColors.primaryText(context))),
                const SizedBox(height: 4),
                Text('$_locationCategory • $_locationState', style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context))),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripSummaryCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: AppColors.blueAccent(context), borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              Text('Trip Summary', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Column(
                children: [
                  Container(width: 10, height: 10, decoration: const BoxDecoration(color: AppColors.weatherBlue, shape: BoxShape.circle)),
                  Container(width: 1.5, height: 24, color: AppColors.borderGlass(context)),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: AppColors.cyanAccent(context), shape: BoxShape.circle)),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('From', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
                        Text(_originName, style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('To', style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
                        Text(_locationName, style: AppTextStyles.titleSmall.copyWith(color: AppColors.cyanAccent(context), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.directions_car_rounded, color: AppColors.mutedText(context), size: 22),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.dividerColor(context)),
          const SizedBox(height: 12),

          if (_isLoadingRoute)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan)),
                    const SizedBox(width: 10),
                    Text('Calculating route...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
                  ],
                ),
              ),
            )
          else if (_routeError != null)
            _RouteErrorRow(error: _routeError!, onRetry: () => _loadRoute(forceRefresh: true))
          else if (_route != null) ...[
            Row(
              children: [
                Expanded(child: _SummaryTile(icon: Icons.route_rounded, label: 'Distance', value: _route!.distanceFormatted, color: AppColors.blueAccent(context))),
                const SizedBox(width: 12),
                Expanded(child: _SummaryTile(icon: Icons.schedule_rounded, label: 'Est. Drive Time', value: _route!.durationFormatted, color: AppColors.cyanAccent(context))),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '* Estimated driving time, not live traffic data',
              style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context), fontStyle: FontStyle.italic),
            ),
          ] else if (_effectiveOrigin == null)
            Text('Select a starting point on the Home screen to see route details.', style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context)))
          else
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
                      'Weather-based analysis only • Route information unavailable',
                      style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTravelScoreCard(TravelScore score) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: score.score / 100.0,
                  strokeWidth: 6,
                  backgroundColor: score.color.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(score.color),
                  strokeCap: StrokeCap.round,
                ),
                Text('${score.score}', style: AppTextStyles.titleLarge.copyWith(color: score.color, fontWeight: FontWeight.w800, fontSize: 18)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  score.isRouteAvailable ? "Today's Travel Score" : "Today's Weather Suitability",
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: score.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: score.color.withValues(alpha: 0.4)),
                  ),
                  child: Text(score.levelName, style: TextStyle(color: score.color, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 5),
                Text('Best Time Today: ${score.bestTravelPeriod}',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.cyanAccent(context), fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForecastCard() {
    if (_weather == null) {
      return GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: AppColors.mutedText(context), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Weather forecast is currently unavailable for this destination.',
                style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
              ),
            ),
          ],
        ),
      );
    }

    return HourlyWeatherCard(
      weather: _weather!,
      title: "Hourly Forecast",
    );
  }

  String _formatDepartureWithDate(String? departure, DateTime travelDate) {
    if (departure == null || departure.isEmpty) return 'Morning or Early Afternoon';
    final now = DateTime.now();
    final isToday = travelDate.year == now.year &&
        travelDate.month == now.month &&
        travelDate.day == now.day;
    final datePrefix = isToday ? 'Today' : DateFormat('d MMM').format(travelDate);
    return '$datePrefix \u00b7 $departure';
  }

  Widget _buildDepartureCard(TravelScore score) {
    String? estimatedArrival;
    final reason = score.departureReason ?? '';
    final onMatch = RegExp(r'on (\d+ \w+) at (\d+:\d+ [AP]M)', caseSensitive: false).firstMatch(reason);
    if (onMatch != null) {
      estimatedArrival = '${onMatch.group(1)} · Around ${onMatch.group(2)}';
    } else if (_route != null && score.recommendedDeparture != null) {
      final timeMatch = RegExp(r'(\d+):(\d+)\s*([AP]M)', caseSensitive: false).firstMatch(score.recommendedDeparture!);
      if (timeMatch != null) {
        int hour = int.parse(timeMatch.group(1)!);
        final min = int.parse(timeMatch.group(2)!);
        final isPm = timeMatch.group(3)!.toUpperCase() == 'PM';
        if (isPm && hour < 12) hour += 12;
        if (!isPm && hour == 12) hour = 0;
        final depDateTime = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, hour, min);
        final arrDateTime = depDateTime.add(Duration(minutes: _route!.durationMinutes));
        if (arrDateTime.day != depDateTime.day) {
          final arrDatePrefix = DateFormat('d MMM').format(arrDateTime);
          final arrTime = DateFormat('h:mm a').format(arrDateTime);
          estimatedArrival = '$arrDatePrefix · Around $arrTime';
        }
      }
    }

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.departure_board_rounded, color: AppColors.cyanAccent(context), size: 17),
              const SizedBox(width: 7),
              Text('Recommended Departure', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent(context).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cyanAccent(context).withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_filled_rounded, color: AppColors.cyanAccent(context), size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDepartureWithDate(score.recommendedDeparture, DateTime.now()),
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.cyanAccent(context), fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        score.departureReason ?? 'Travel during optimal weather windows for the best road conditions.',
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (estimatedArrival != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.blueAccent(context).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.blueAccent(context).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppColors.blueAccent(context), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated Arrival',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.mutedText(context),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          estimatedArrival,
                          style: AppTextStyles.titleSmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBreakdownCard(TravelScore score) {
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
                  Icon(Icons.analytics_outlined, color: AppColors.blueAccent(context), size: 17),
                  const SizedBox(width: 7),
                  Text('Score Breakdown', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: score.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  score.levelName,
                  style: TextStyle(color: score.color, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _ScoreBar(
            label: 'Weather Suitability',
            points: score.weatherSubscore,
            maxPoints: 100,
            color: AppColors.blueAccent(context),
            description: _weather?.condition ?? 'Stable',
          ),
          const SizedBox(height: 12),

          if (score.journeySubscore != null) ...[
            _ScoreBar(
              label: 'Journey Practicality',
              points: score.journeySubscore!,
              maxPoints: 100,
              color: AppColors.cyanAccent(context),
              description: _route != null ? '${_route!.durationFormatted} drive' : 'Direct driving route available',
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceGlass(context),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderGlass(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: AppColors.mutedText(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Journey Practicality: Driving route unavailable from origin. Overall score is calculated from official weather suitability.',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context), fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsCard(TravelScore score) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFFBBF24), size: 17),
              const SizedBox(width: 7),
              Text('Why This Score?', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
            ],
          ),
          const SizedBox(height: 10),
          ...score.explanationBullets.map((bullet) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle, size: 5, color: AppColors.cyanAccent(context)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet.startsWith('• ') ? bullet.substring(2) : bullet,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context), fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )),

          if (score.recommendedActivities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.local_activity_outlined, color: AppColors.cyanAccent(context), size: 16),
                const SizedBox(width: 7),
                Text('Recommended Activities', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
              ],
            ),
            const SizedBox(height: 8),
            ...score.recommendedActivities.map((act) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.safeGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          act,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          if (score.highlights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: AppColors.dividerColor(context)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFFBBF24), size: 16),
                const SizedBox(width: 7),
                Text('Travel Highlights', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
              ],
            ),
            const SizedBox(height: 8),
            ...score.highlights.map((tip) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Icon(Icons.circle, size: 5, color: AppColors.cyanAccent(context)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tip,
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context), fontSize: 12),
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

  Widget _buildLoadingCard() {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const CircularProgressIndicator(color: AppColors.accentCyan),
            const SizedBox(height: 12),
            Text('Loading weather forecast...', style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherErrorCard() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: AppColors.dangerRed.withValues(alpha: 0.3),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.dangerRed, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _weatherError!,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)),
            ),
          ),
          TextButton(
            onPressed: () => _loadOfficialForecast(forceRefresh: true),
            child: Text('Retry', style: TextStyle(color: AppColors.cyanAccent(context))),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Source: MET Malaysia\nRoute & travel times are estimates.',
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context), fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
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

class _ScoreBar extends StatelessWidget {
  final String label;
  final int points;
  final int maxPoints;
  final Color color;
  final String description;

  const _ScoreBar({
    required this.label,
    required this.points,
    required this.maxPoints,
    required this.color,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final progress = points / maxPoints;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
            Text('$points / $maxPoints pts', style: AppTextStyles.bodySmall.copyWith(color: color, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(description, style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context))),
      ],
    );
  }
}

class _RouteErrorRow extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _RouteErrorRow({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.dangerRed, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(error, style: AppTextStyles.bodySmall.copyWith(color: AppColors.secondaryText(context)))),
        TextButton(onPressed: onRetry, child: Text('Retry', style: TextStyle(color: AppColors.cyanAccent(context), fontSize: 12))),
      ],
    );
  }
}
