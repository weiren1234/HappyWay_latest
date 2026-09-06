import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../main.dart' show scaffoldMessengerKey;
import '../models/saved_location.dart';
import '../models/travel_destination.dart';
import '../providers/auth_provider.dart';
import '../providers/destination_provider.dart';
import '../providers/location_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../widgets/header_section.dart';
import '../widgets/create_trip_sheet.dart';
import '../widgets/destination_image_view.dart';
import '../routes/app_routes.dart';
import 'destination_detail_screen.dart';
import 'travel_insights_screen.dart';
import '../utils/canonical_destination_id.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {

  void _openDetail(BuildContext ctx, SavedLocation item, TravelDestination? featuredMatch) {
    if (featuredMatch != null) {
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => DestinationDetailScreen(destination: featuredMatch),
        ),
      );
    } else {

      final locProvider = Provider.of<LocationProvider>(ctx, listen: false);
      Navigator.push(
        ctx,
        MaterialPageRoute(
          builder: (_) => TravelInsightsScreen(
            travelLocation: item.toTravelLocation(),
            destination: null,
            userOrigin: locProvider.currentLocation,
          ),
        ),
      );
    }
  }

  void _openAnalysis(BuildContext ctx, SavedLocation item, TravelDestination? featuredMatch) {
    final locProvider = Provider.of<LocationProvider>(ctx, listen: false);
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => TravelInsightsScreen(
          travelLocation: item.toTravelLocation(),
          destination: featuredMatch,
          userOrigin: locProvider.currentLocation,
        ),
      ),
    );
  }

  void _openPlanTrip(BuildContext ctx, SavedLocation item) {
    CreateTripSheet.show(
      ctx,
      initialDestination: item.toTravelLocation(),
    );
  }

  Future<void> _handleDelete(BuildContext ctx, SavedLocation item) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.cardBg(ctx),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.borderGlass(ctx)),
        ),
        title: Text(
          'Remove Saved Location?',
          style: TextStyle(color: AppColors.primaryText(ctx), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          'Are you sure you want to remove "${item.name}" from your saved locations?',
          style: TextStyle(color: AppColors.secondaryText(ctx), fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.secondaryText(ctx))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.dangerRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!ctx.mounted) return;

    final destProvider = Provider.of<DestinationProvider>(ctx, listen: false);

    final error = await destProvider.removeSavedLocationWithUndo(item.id);

    if (!ctx.mounted) return;

    if (error != null) {

      scaffoldMessengerKey.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(error, style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.dangerRed.withValues(alpha: 0.9),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 4),
          ),
        );
      return;
    }

    scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Removed from Saved',
            style: TextStyle(color: AppColors.primaryText(ctx), fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.cardBg(ctx),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.borderGlass(ctx)),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'UNDO',
            textColor: AppColors.cyanAccent(ctx),
            onPressed: () => _handleUndo(ctx, item),
          ),
        ),
      );
  }

  Future<void> _handleUndo(BuildContext ctx, SavedLocation item) async {
    if (!ctx.mounted) return;
    final destProvider = Provider.of<DestinationProvider>(ctx, listen: false);

    final error = await destProvider.restoreSavedLocation(item);

    if (!ctx.mounted) return;

    if (error != null) {
      scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text(error, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.dangerRed.withValues(alpha: 0.9),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final destProvider = Provider.of<DestinationProvider>(context);
    final savedList = destProvider.savedLocations;

    if (auth.isGuest) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.weatherBlue.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bookmark_outline_rounded, color: AppColors.weatherBlue, size: 34),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Sign in to continue',
                    style: AppTextStyles.titleLarge.copyWith(color: AppColors.primaryText(context), fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sign in to save destinations and plan your trips.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.secondaryText(context)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.weatherBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('Sign In', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.register),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cyanAccent(context),
                        side: BorderSide(color: AppColors.cyanAccent(context)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Create Account', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              HeaderSection(
                title: 'Saved Locations',
                subtitle: savedList.isEmpty
                    ? 'No saved trip locations'
                    : '${savedList.length} ${savedList.length == 1 ? 'location' : 'locations'} saved',
              ),
              const SizedBox(height: 14),

              Expanded(
                child: destProvider.isLoadingSaved
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: AppColors.accentCyan),
                            const SizedBox(height: 12),
                            Text(
                              'Loading saved destinations...',
                              style: TextStyle(color: AppColors.secondaryText(context), fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: destProvider.loadSavedLocations,
                        color: AppColors.accentCyan,
                        backgroundColor: AppColors.cardBg(context),
                        child: savedList.isEmpty
                            ? const _EmptyState()
                            : ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(
                                  parent: BouncingScrollPhysics(),
                                ),
                                itemCount: savedList.length,
                                itemBuilder: (context, index) {
                                  final item = savedList[index];
                                  final itemCanonical = CanonicalDestinationId.fromSavedLocation(item);
                                  final featuredMatch = destProvider.featuredDestinations
                                      .where((d) => CanonicalDestinationId.fromDestination(d) == itemCanonical)
                                      .firstOrNull ?? (
                                    destProvider.recommendations
                                        .map((r) => r.destination)
                                        .where((d) => CanonicalDestinationId.fromDestination(d) == itemCanonical)
                                        .firstOrNull
                                  );
                                  return _SavedCard(
                                    key: ValueKey(item.id),
                                    item: item,
                                    featuredMatch: featuredMatch,
                                    onTapCard: () => _openDetail(context, item, featuredMatch),
                                    onAnalyze: () => _openAnalysis(context, item, featuredMatch),
                                    onPlanTrip: () => _openPlanTrip(context, item),
                                    onDelete: () =>
                                        _handleDelete(context, item),
                                  );
                                },
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

class _SavedCard extends StatelessWidget {
  final SavedLocation item;
  final TravelDestination? featuredMatch;
  final VoidCallback onTapCard;
  final VoidCallback onAnalyze;
  final VoidCallback onPlanTrip;
  final VoidCallback onDelete;

  const _SavedCard({
    super.key,
    required this.item,
    required this.featuredMatch,
    required this.onTapCard,
    required this.onAnalyze,
    required this.onPlanTrip,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isGeocoded = item.sourceType == 'geocodedPlace';
    const badgeColor = Color(0xFF00E676);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),

      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: onTapCard,
          borderRadius: BorderRadius.circular(24),
          splashColor: AppColors.accentCyan.withValues(alpha: 0.08),
          highlightColor: AppColors.accentCyan.withValues(alpha: 0.04),
          child: GlassCard(
            padding: EdgeInsets.zero,

            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Row(
                children: [

                  DestinationImageView(
                    name: item.name,
                    state: item.state,
                    locationId: item.metLocationId ?? item.id,
                    imageUrl: item.imageUrl,
                    width: 90,
                    height: 108,
                    fit: BoxFit.cover,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(24)),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: AppTextStyles.titleSmall.copyWith(color: AppColors.primaryText(context)),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isGeocoded
                                      ? badgeColor.withValues(alpha: 0.15)
                                      : AppColors.weatherBlue.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isGeocoded
                                        ? badgeColor.withValues(alpha: 0.4)
                                        : AppColors.weatherBlue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Text(
                                  isGeocoded ? 'Detailed Place' : item.category,
                                  style: TextStyle(
                                    color: isGeocoded ? badgeColor : AppColors.cyanAccent(context),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: onDelete,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: AppColors.dangerRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.dangerRed,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),

                          Row(
                            children: [
                              Icon(
                                isGeocoded
                                    ? Icons.pin_drop_outlined
                                    : Icons.location_on_outlined,
                                color: isGeocoded ? badgeColor : AppColors.cyanAccent(context),
                                size: 12,
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  item.metLocationName != null && isGeocoded
                                      ? '${item.state} • Weather: ${item.metLocationName}'
                                      : item.state,
                                  style: AppTextStyles.bodySmall.copyWith(fontSize: 11, color: AppColors.secondaryText(context)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              _ActionButton(
                                label: 'Analysis',
                                icon: Icons.insights_rounded,
                                onTap: onAnalyze,
                              ),
                              const SizedBox(width: 8),
                              _ActionButton(
                                label: 'Plan Trip',
                                icon: Icons.luggage_rounded,
                                isPrimary: true,
                                onTap: onPlanTrip,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: onTap,

      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isPrimary
              ? AppColors.blueAccent(context).withValues(alpha: 0.25)
              : AppColors.surfaceGlass(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary
                ? AppColors.blueAccent(context).withValues(alpha: 0.6)
                : AppColors.borderGlass(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12,
                color: isPrimary ? AppColors.cyanAccent(context) : AppColors.cyanAccent(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: AppTextStyles.badgeLabel.copyWith(
                color: isPrimary ? AppColors.blueAccent(context) : AppColors.secondaryText(context),
                fontSize: 10,
                fontWeight: isPrimary ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.cyanAccent(context).withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.cyanAccent(context).withValues(alpha: 0.25), width: 2),
            ),
            child: Icon(Icons.bookmark_outline_rounded,
                size: 48, color: AppColors.cyanAccent(context)),
          ),
          const SizedBox(height: 18),
          Text('No Saved Locations', style: AppTextStyles.titleMedium.copyWith(color: AppColors.primaryText(context))),
          const SizedBox(height: 6),
          Text(
            'Tap the bookmark icon on any destination or\nsearched location to view it here.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.mutedText(context)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
