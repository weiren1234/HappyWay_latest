import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_bottom_nav.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'saved_screen.dart';
import 'profile_screen.dart';

/// MainScreen provides the parent scaffolding shell, background gradient, tab view switcher,
/// and floating glass bottom navigation bar.
class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    debugPrint('[MainScreen] build: currentIndex = ${navProvider.currentIndex}');

    final screens = const [
      HomeScreen(),
      TripsScreen(),
      SavedScreen(),
      ProfileScreen(),
    ];

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? const [
                    AppColors.backgroundGradientStart,
                    AppColors.backgroundGradientEnd,
                  ]
                : const [
                    AppColors.backgroundGradientStartLight,
                    AppColors.backgroundGradientEndLight,
                  ],
          ),
        ),
        child: Stack(
          children: [
            // Body Content with Tab Switching
            IndexedStack(
              index: navProvider.currentIndex,
              children: screens,
            ),

            // Floating Bottom Navigation Bar
            const Align(
              alignment: Alignment.bottomCenter,
              child: CustomBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }
}
