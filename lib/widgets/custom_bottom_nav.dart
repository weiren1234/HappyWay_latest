import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/navigation_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class CustomBottomNavBar extends StatelessWidget {
  const CustomBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = Provider.of<NavigationProvider>(context);
    final currentIndex = navProvider.currentIndex;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = [
      _NavItemData(icon: Icons.grid_view_rounded, label: 'Home'),
      _NavItemData(icon: Icons.route_rounded, label: 'Trips'),
      _NavItemData(icon: Icons.bookmark_outline_rounded, label: 'Saved'),
      _NavItemData(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.navBarBackground : AppColors.navBarBackgroundLight,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(
                color: isDark ? AppColors.glassBorderLight : AppColors.glassBorderLightMode,
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black45 : const Color(0x140F172A),
                  blurRadius: 20,
                  offset: isDark ? const Offset(0, 10) : const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = currentIndex == index;

                return GestureDetector(
                  onTap: () {
                    final tabNames = ['Home', 'Trips', 'Saved', 'Profile'];
                    final tabName = index < tabNames.length ? tabNames[index] : 'Unknown';
                    debugPrint('[BottomNav] tapped $tabName -> $index');
                    navProvider.setTab(index);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark
                              ? AppColors.weatherBlue.withValues(alpha: 0.2)
                              : AppColors.weatherBlue.withValues(alpha: 0.12))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(24),
                      border: isSelected
                          ? Border.all(
                              color: isDark
                                  ? AppColors.weatherBlue.withValues(alpha: 0.5)
                                  : AppColors.weatherBlue.withValues(alpha: 0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.icon,
                          color: isSelected
                              ? (isDark ? AppColors.accentCyan : AppColors.weatherBlue)
                              : (isDark ? AppColors.textSecondary : AppColors.textSecondaryLight),
                          size: 22,
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          Text(
                            item.label,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: isDark ? AppColors.textPrimary : AppColors.textPrimaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;

  _NavItemData({required this.icon, required this.label});
}
