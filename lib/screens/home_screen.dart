import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/travel_destination.dart';
import '../models/travel_location.dart';
import '../models/travel_route.dart';
import '../models/weather_info.dart';
import '../models/travel_score.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/location_provider.dart';
import '../providers/trip_provider.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/auth_prompt_dialog.dart';
import '../widgets/custom_search_bar.dart';
import '../widgets/destination_card.dart';
import '../widgets/loading_skeleton.dart';
import '../widgets/header_section.dart';
import '../widgets/destination_picker_sheet.dart';
import '../widgets/origin_picker_sheet.dart';
import '../widgets/travel_overview_card.dart';
import '../widgets/recommendation_card.dart';
import '../widgets/trip_reminder_card.dart';
import '../utils/travel_score_calculator.dart';
import 'destination_detail_screen.dart';
import 'travel_insights_screen.dart';
import 'trip_detail_screen.dart';

/// HomeScreen — HappyWay's primary travel planning hub with real GPS location,
/// precise destination search, smart recommendations, OSRM route estimation, and travel analysis.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Selected destination
  TravelLocation? _selectedDestination;
  TravelDestination? _matchingFeaturedDest;

  // Analysis state
  bool _isAnalyzing = false;
  bool _hasAnalyzed = false;
  WeatherInfo? _analyzedWeather;
  TravelRoute? _analyzedRoute;
  bool _isLoadingRoute = false;
  String? _routeError;
  TravelScore? _analyzedScore;

  final RouteService _routeService = RouteService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final destProvider = Provider.of<DestinationProvider>(context, listen: false);
      final locProvider = Provider.of<LocationProvider>(context, listen: false);
      if (locProvider.currentLocation != null) {
        destProvider.updateUserOrigin(locProvider.currentLocation);
      }
    });
  }

  // ─── Location Picker ─────────────────────────────────────────────────────────

  void _openLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DestinationPickerSheet(
        selectedLocationId: _selectedDestination?.id,
        onSelectTravelLocation: (loc) {
          final destProvider = Provider.of<DestinationProvider>(context, listen: false);
          final match = destProvider.featuredDestinations.where((d) {
            return (loc.metLocationId != null && d.metLocationId == loc.metLocationId) ||
                d.name.toLowerCase() == loc.name.toLowerCase();
          }).firstOrNull;

          setState(() {
            _selectedDestination = loc;
            _matchingFeaturedDest = match;
            // Clear prior analysis when destination changes
            _hasAnalyzed = false;
            _analyzedWeather = null;
            _analyzedRoute = null;
            _routeError = null;
            _analyzedScore = null;
          });
        },
      ),
    );
  }

  void _openOriginPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OriginPickerSheet(
        onSelectCurrentLocation: () {
          final locProvider = Provider.of<LocationProvider>(context, listen: false);
          locProvider.selectCurrentLocation();
          setState(() {
            _hasAnalyzed = false;
            _analyzedWeather = null;
            _analyzedRoute = null;
            _routeError = null;
            _analyzedScore = null;
          });
        },
        onSelectTravelLocation: (loc) {
          final locProvider = Provider.of<LocationProvider>(context, listen: false);
          locProvider.setManualLocation(loc);
          // Clear prior analysis if origin changes
          setState(() {
            _hasAnalyzed = false;
            _analyzedWeather = null;
            _analyzedRoute = null;
            _routeError = null;
            _analyzedScore = null;
          });
        },
      ),
    );
  }

  // ─── Analyze Trip ─────────────────────────────────────────────────────────────

  Future<void> _onAnalyzeTrip(BuildContext context, [TravelLocation? explicitDest, TravelDestination? explicitFeatured]) async {
    final loc = explicitDest ?? _selectedDestination;
    if (loc == null) {
      _showSnackBar(context, 'Please select a destination first.');
      return;
    }

    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    final destProvider = Provider.of<DestinationProvider>(context, listen: false);

    if (!locProvider.hasLocation) {
      _showSnackBar(context, 'Please wait for GPS location or select a starting point manually.');
      return;
    }

    // Update state if explicit location is passed from recommendation
    if (explicitDest != null) {
      setState(() {
        _selectedDestination = explicitDest;
        _matchingFeaturedDest = explicitFeatured;
      });
    }

    // Capture navigators before async gap
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    final navigator = Navigator.of(context);

    setState(() => _isAnalyzing = true);
    _showAnalyzingDialog(context, loc);

    // 1. Fetch official MET forecast if a matched MET location exists
    WeatherInfo? weather;
    if (loc.hasWeatherLocation) {
      weather = await destProvider.fetchForecastForTravelLocation(loc);
    }

    if (!mounted) return;
    setState(() => _isAnalyzing = false);
    rootNavigator.pop(); // Close loading dialog

    if (weather == null && loc.hasWeatherLocation && loc.isMetLocation) {
      if (!context.mounted) return;
      _showErrorDialog(context, loc);
      return;
    }

    // 2. Fetch OSRM route using exact destination coordinates (non-blocking)
    setState(() {
      _hasAnalyzed = true;
      _analyzedWeather = weather;
      _isLoadingRoute = true;
      _routeError = null;
      _analyzedRoute = null;
    });

    final origin = locProvider.currentLocation!;
    final destLat = loc.latitude;
    final destLng = loc.longitude;

    TravelRoute? route;
    String? routeErr;

    if (destLat != 0.0 && destLng != 0.0) {
      final result = await _routeService.calculateRouteDetails(
        originName: origin.name,
        originLat: origin.latitude,
        originLng: origin.longitude,
        destName: loc.name,
        destLat: destLat,
        destLng: destLng,
      );
      route = result.route;
      routeErr = result.errorMessage;
    } else {
      routeErr = 'Route unavailable — destination coordinates missing.';
    }

    if (!mounted) return;

    final score = TravelScoreCalculator.calculateScore(weather: weather, route: route);

    setState(() {
      _analyzedRoute = route;
      _routeError = routeErr;
      _isLoadingRoute = false;
      _analyzedScore = score;
    });

    // 3. Navigate to full Travel Insights
    navigator.push(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondaryAnimation) => TravelInsightsScreen(
          travelLocation: loc,
          destination: _matchingFeaturedDest,
          initialWeather: weather,
          route: route,
          userOrigin: origin,
        ),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation.drive(Tween<double>(begin: 0.0, end: 1.0)),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  Future<void> _retryRoute() async {
    final locProvider = Provider.of<LocationProvider>(context, listen: false);
    final loc = _selectedDestination;
    if (loc == null || !locProvider.hasLocation) return;

    final origin = locProvider.currentLocation!;
    final destLat = loc.latitude;
    final destLng = loc.longitude;
    if (destLat == 0.0 || destLng == 0.0) return;

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    final result = await _routeService.calculateRouteDetails(
      originName: origin.name,
      originLat: origin.latitude,
      originLng: origin.longitude,
      destName: loc.name,
      destLat: destLat,
      destLng: destLng,
      forceRefresh: true,
    );

    if (!mounted) return;

    final score = TravelScoreCalculator.calculateScore(
      weather: _analyzedWeather,
      route: result.route,
    );

    setState(() {
      _analyzedRoute = result.route;
      _routeError = result.errorMessage;
      _isLoadingRoute = false;
      _analyzedScore = score;
    });
  }

  // ─── Dialogs ──────────────────────────────────────────────────────────────────

  void _showAnalyzingDialog(BuildContext context, TravelLocation loc) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.accentCyan),
                const SizedBox(height: 20),
                Text(
                  'Preparing your trip to ${loc.name}...',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  loc.hasWeatherLocation
                      ? 'Requesting official MET Malaysia forecast data for ${loc.metLocationName ?? loc.state}'
                      : 'Calculating route and travel practical score',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, TravelLocation loc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(ctx)),
        ),
        title: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.dangerRed, size: 24),
            const SizedBox(width: 10),
            Text('Forecast Unavailable', style: TextStyle(color: AppColors.primaryText(ctx))),
          ],
        ),
        content: Text(
          'Unable to retrieve the latest forecast from MET Malaysia for ${loc.name}. Please check your network connection and try again.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(ctx)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(ctx))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _onAnalyzeTrip(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.weatherBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primaryText(context))),
        backgroundColor: AppColors.cardBg(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: AppColors.borderGlass(context)),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final destProvider = Provider.of<DestinationProvider>(context);
    final locProvider = Provider.of<LocationProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final tripProvider = Provider.of<TripProvider>(context);

    final remindersEnabled = authProvider.preferences?.tripRemindersEnabled ?? true;
    final topReminderTrip = remindersEnabled
        ? TripReminderCard.resolveTopReminder(tripProvider.trips, tripProvider)
        : null;

    final dest = _selectedDestination;
    final hasValidDest = dest != null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: destProvider.loadDestinations,
          color: AppColors.accentCyan,
          backgroundColor: AppColors.cardBg(context),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. App Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('HappyWay', style: AppTextStyles.hero(context)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.weatherBlue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.weatherBlue.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  'MALAYSIA',
                                  style: AppTextStyles.badgeLabel.copyWith(color: AppColors.cyanAccent(context), fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'Plan and explore travel destinations',
                            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => locProvider.retryGpsLocation(),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceGlass(context),
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.borderGlass(context)),
                          ),
                          child: locProvider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
                                )
                              : Icon(Icons.my_location_rounded, color: AppColors.cyanAccent(context), size: 22),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 1b. Proactive Trip Reminder Banner (Compact)
              if (topReminderTrip != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
                    child: TripReminderCard(
                      trip: topReminderTrip,
                      isCompact: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => TripDetailScreen(trip: topReminderTrip)),
                        );
                      },
                    ),
                  ),
                ),

              // 2. Plan Your Trip Card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: GlassCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 3, height: 18,
                              decoration: BoxDecoration(color: AppColors.weatherBlue, borderRadius: BorderRadius.circular(2)),
                            ),
                            const SizedBox(width: 8),
                            Text('Plan Your Trip', style: AppTextStyles.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 11),
                          child: Text(
                            'Check official MET travel forecasts and journey conditions across Malaysia.',
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Current Location Row
                        _CurrentLocationTile(
                          locProvider: locProvider,
                          onTapChange: () => _openOriginPicker(context),
                          onRetryGps: () => locProvider.retryGpsLocation(),
                          onOpenSettings: () => LocationService.openAppSettings(),
                        ),
                        const SizedBox(height: 10),

                        // Destination Selector
                        GestureDetector(
                          onTap: () => _openLocationPicker(context),
                          child: _RowContainer(
                            child: Row(
                              children: [
                                const _DotIcon(color: AppColors.safeGreen, icon: Icons.location_on_rounded),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        hasValidDest ? 'Selected Destination' : 'Destination',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontSize: 10,
                                          color: AppColors.mutedText(context),
                                        ),
                                      ),
                                      Text(
                                        dest?.name ?? 'Select destination',
                                        style: AppTextStyles.titleSmall.copyWith(
                                          color: hasValidDest
                                              ? AppColors.primaryText(context)
                                              : AppColors.cyanAccent(context),
                                          fontWeight: hasValidDest ? FontWeight.w600 : FontWeight.w500,
                                        ),
                                      ),
                                      if (hasValidDest) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          dest.hasWeatherLocation
                                              ? '${dest.category} • Weather: ${dest.metLocationName ?? dest.state}'
                                              : '${dest.category} • ${dest.state}',
                                          style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.cyanAccent(context)),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  hasValidDest ? 'Change' : 'Browse',
                                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.blueAccent(context), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Search shortcut
                        GestureDetector(
                          onTap: () => _openLocationPicker(context),
                          child: _RowContainer(
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded, color: AppColors.mutedText(context), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Search MET location or detailed address...',
                                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.mutedText(context)),
                                  ),
                                ),
                                Icon(Icons.arrow_drop_down_rounded, color: AppColors.mutedText(context)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Analyze Button
                        _AnalyzeButton(
                          enabled: hasValidDest && locProvider.hasLocation && !_isAnalyzing,
                          isLoading: _isAnalyzing,
                          onTap: () {
                            if (_selectedDestination == null) {
                              _showSnackBar(context, 'Please select a destination first.');
                            } else if (!locProvider.hasLocation) {
                              _showSnackBar(context, 'Please wait for GPS location or select a starting point manually.');
                            } else if (!_isAnalyzing) {
                              _onAnalyzeTrip(context);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Travel Overview (shown after analysis)
              if (_hasAnalyzed)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: TravelOverviewCard(
                      fromName: locProvider.currentLocation?.name ?? 'Current Location',
                      toName: dest?.name ?? 'Destination',
                      weatherAreaName: dest?.metLocationName,
                      hasWeatherLocation: dest?.hasWeatherLocation ?? true,
                      route: _analyzedRoute,
                      weather: _analyzedWeather,
                      score: _analyzedScore ?? TravelScoreCalculator.calculateScore(weather: _analyzedWeather),
                      isLoadingRoute: _isLoadingRoute,
                      routeError: _routeError,
                      onRetryRoute: _retryRoute,
                      onViewInsights: () {
                        if (dest != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TravelInsightsScreen(
                                travelLocation: dest,
                                destination: _matchingFeaturedDest,
                                initialWeather: _analyzedWeather,
                                route: _analyzedRoute,
                                userOrigin: locProvider.currentLocation,
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),

              // 4. SMART RECOMMENDATIONS: "Recommended Today"
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 3, height: 18,
                                decoration: BoxDecoration(color: AppColors.safeGreen, borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(width: 8),
                              Text('Smart Recommendations', style: AppTextStyles.titleMedium),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.safeGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('Smart Match', style: TextStyle(color: AppColors.safeGreen, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 11),
                        child: Text(
                          'Score-ranked recommendations matching your travel mood & official MET forecasts',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Preference Selector Chips: "For you:"
                      Row(
                        children: [
                          Text('For you:', style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppColors.cyanAccent(context))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 36,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                itemCount: destProvider.preferenceTags.length,
                                itemBuilder: (context, idx) {
                                  final tag = destProvider.preferenceTags[idx];
                                  final isSelected = tag == destProvider.selectedRecommendationTag;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ChoiceChip(
                                      label: Text(tag),
                                      selected: isSelected,
                                      onSelected: (_) => destProvider.setRecommendationPreference(tag),
                                      labelStyle: TextStyle(
                                        color: isSelected ? Colors.white : AppColors.secondaryText(context),
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                      backgroundColor: AppColors.surfaceGlass(context),
                                      selectedColor: AppColors.blueAccent(context),
                                      side: BorderSide(
                                        color: isSelected ? AppColors.cyanAccent(context) : AppColors.borderGlass(context),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      padding: const EdgeInsets.symmetric(horizontal: 4),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Recommended Destinations List
              if (destProvider.isLoadingRecommendations)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => LoadingSkeleton.destinationCardSkeleton(),
                      childCount: 2,
                    ),
                  ),
                )
              else if (destProvider.recommendations.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: GlassCard(
                      padding: const EdgeInsets.all(20),
                      child: Center(
                        child: Text(
                          'No recommendations available for ${destProvider.selectedRecommendationTag}.',
                          style: AppTextStyles.bodySmall,
                        ),
                      ),
                    ),
                  ),
                )
              else ...[
                // ── Road-Accessible from Your Location ───────────────────────
                if (destProvider.roadAccessibleRecommendations.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.safeGreen),
                          const SizedBox(width: 6),
                          Text(
                            'Recommended from Your Location',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rec = destProvider.roadAccessibleRecommendations[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RecommendationCard(
                              recommendation: rec,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DestinationDetailScreen(destination: rec.destination),
                                ),
                              ),
                              onAnalyze: () {
                                final travelLoc = TravelLocation.fromFeaturedDestination(rec.destination);
                                _onAnalyzeTrip(context, travelLoc, rec.destination);
                              },
                            ),
                          );
                        },
                        childCount: destProvider.roadAccessibleRecommendations.length,
                      ),
                    ),
                  ),
                ],

                // ── Recommended Getaways (Cross-Region / Island) ────────────
                if (destProvider.getawayRecommendations.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.flight_takeoff_rounded, size: 14, color: AppColors.accentCyan),
                          const SizedBox(width: 6),
                          Text(
                            'Recommended Getaways',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primaryText(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final rec = destProvider.getawayRecommendations[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: RecommendationCard(
                              recommendation: rec,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DestinationDetailScreen(destination: rec.destination),
                                ),
                              ),
                              onAnalyze: () {
                                final travelLoc = TravelLocation.fromFeaturedDestination(rec.destination);
                                _onAnalyzeTrip(context, travelLoc, rec.destination);
                              },
                            ),
                          );
                        },
                        childCount: destProvider.getawayRecommendations.length,
                      ),
                    ),
                  ),
                ],
              ],

              // 6. Featured Destinations Filter & Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                  child: CustomSearchBar(
                    searchQuery: destProvider.searchQuery,
                    onSearchChanged: destProvider.setSearchQuery,
                    categories: destProvider.categories,
                    selectedCategory: destProvider.selectedCategory,
                    onCategorySelected: destProvider.selectCategory,
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: HeaderSection(
                    title: destProvider.selectedCategory == 'All'
                        ? 'All Featured Destinations'
                        : destProvider.selectedCategory,
                    subtitle: '${destProvider.filteredDestinations.length} curated destinations across Malaysia',
                  ),
                ),
              ),

              // 7. Featured Destination Cards
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                sliver: destProvider.isLoading
                    ? SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => LoadingSkeleton.destinationCardSkeleton(),
                          childCount: 3,
                        ),
                      )
                    : destProvider.filteredDestinations.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  children: [
                                    const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
                                    const SizedBox(height: 12),
                                    Text('No featured destinations found', style: AppTextStyles.titleMedium),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try searching another location or reset category filter',
                                      style: AppTextStyles.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (_, index) {
                                final d = destProvider.filteredDestinations[index];
                                return DestinationCard(
                                  destination: d,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DestinationDetailScreen(destination: d),
                                    ),
                                  ),
                                  onToggleSave: () {
                                    final auth = Provider.of<AuthProvider>(context, listen: false);
                                    if (auth.isGuest) {
                                      AuthPromptDialog.show(context);
                                      return;
                                    }
                                    destProvider.toggleSaveDestination(d.id);
                                  },
                                );
                              },
                              childCount: destProvider.filteredDestinations.length,
                            ),
                          ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Current Location Tile ────────────────────────────────────────────────────

class _CurrentLocationTile extends StatelessWidget {
  final LocationProvider locProvider;
  final VoidCallback onTapChange;
  final VoidCallback onRetryGps;
  final VoidCallback onOpenSettings;

  const _CurrentLocationTile({
    required this.locProvider,
    required this.onTapChange,
    required this.onRetryGps,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final state = locProvider.permissionState;

    Widget trailing;
    if (locProvider.isLoading) {
      trailing = const SizedBox(
        width: 16, height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentCyan),
      );
    } else if (state == LocationPermissionState.permanentlyDenied) {
      trailing = GestureDetector(
        onTap: () async { await LocationService.openAppSettings(); },
        child: Text('Settings', style: AppTextStyles.bodySmall.copyWith(color: AppColors.weatherBlue, fontWeight: FontWeight.w600)),
      );
    } else if (state == LocationPermissionState.denied || state == LocationPermissionState.serviceDisabled) {
      trailing = GestureDetector(
        onTap: onTapChange,
        child: Text('Select', style: AppTextStyles.bodySmall.copyWith(color: AppColors.weatherBlue, fontWeight: FontWeight.w600)),
      );
    } else {
      trailing = GestureDetector(
        onTap: onTapChange,
        child: Text('Change', style: AppTextStyles.bodySmall.copyWith(color: AppColors.weatherBlue, fontWeight: FontWeight.w600)),
      );
    }

    String locationTitle;
    String locationSubtitle;
    Color dotColor = AppColors.weatherBlue;

    if (locProvider.isLoading) {
      locationTitle = 'Locating...';
      locationSubtitle = 'Requesting GPS position';
    } else if (locProvider.currentLocation != null) {
      locationTitle = locProvider.currentLocation!.name;
      locationSubtitle = locProvider.currentLocation!.subtitle;
      dotColor = locProvider.isGps ? AppColors.safeGreen : AppColors.cautionAmber;
    } else if (state == LocationPermissionState.permanentlyDenied) {
      locationTitle = 'Permission Denied';
      locationSubtitle = 'Tap Settings to allow location access';
      dotColor = AppColors.dangerRed;
    } else if (state == LocationPermissionState.serviceDisabled) {
      locationTitle = 'GPS Disabled';
      locationSubtitle = 'Enable location services or select manually';
      dotColor = AppColors.dangerRed;
    } else {
      locationTitle = 'Location Unavailable';
      locationSubtitle = 'Tap Select to choose a start point';
      dotColor = AppColors.cautionAmber;
    }

    return _RowContainer(
      child: Row(
        children: [
          _DotIcon(color: dotColor, icon: Icons.my_location_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locProvider.isGps ? 'Origin (GPS)' : 'Origin (Manual)',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
                ),
                Text(locationTitle, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context))),
                if (locationSubtitle.isNotEmpty)
                  Text(
                    locationSubtitle,
                    style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.mutedText(context)),
                  ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

// ─── Analyze Button ───────────────────────────────────────────────────────────

class _AnalyzeButton extends StatelessWidget {
  final bool enabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _AnalyzeButton({required this.enabled, required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [const Color(0xFF2563EB), const Color(0xFF3B82F6)]
                  : [AppColors.surfaceGlass(context), AppColors.surfaceGlass(context)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: enabled ? AppColors.blueAccent(context).withValues(alpha: 0.5) : AppColors.borderGlass(context),
            ),
            boxShadow: enabled
                ? [BoxShadow(color: AppColors.weatherBlue.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Analyze Destination',
                style: AppTextStyles.titleSmall.copyWith(
                  color: enabled ? Colors.white : AppColors.mutedText(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white.withValues(alpha: 0.2) : AppColors.surfaceGlass(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? Colors.white : AppColors.mutedText(context),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _RowContainer extends StatelessWidget {
  final Widget child;
  const _RowContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceGlass(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGlass(context)),
      ),
      child: child,
    );
  }
}

class _DotIcon extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _DotIcon({required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 16),
    );
  }
}
