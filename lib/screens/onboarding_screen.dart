import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/glass_card.dart';
import '../routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'Discover Destinations',
      'subtitle': 'Explore 450+ locations across Malaysia with official MET Malaysia weather forecasts.',
      'icon': Icons.travel_explore_rounded,
      'badge': 'SMART EXPLORATION',
      'color': AppColors.weatherBlue,
      'iconBg': Color(0xFF1E3A8A),
    },
    {
      'title': 'Official MET Malaysia Forecasts',
      'subtitle': 'Get official forecasts with morning, afternoon, and night weather conditions.',
      'icon': Icons.cloud_outlined,
      'badge': 'WEATHER INSIGHTS',
      'color': AppColors.accentCyan,
      'iconBg': Color(0xFF0C4A6E),
    },
    {
      'title': 'Smart Travel Planning',
      'subtitle': 'Get Travel Suitability Scores, estimated driving times, and recommended departure windows for your journey.',
      'icon': Icons.route_rounded,
      'badge': 'SMART PLANNING',
      'color': AppColors.safeGreen,
      'iconBg': Color(0xFF064E3B),
    },
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('first_launch_completed', true);
    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    auth.completeOnboarding();
    auth.continueAsGuest();
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.main, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.backgroundGradientStart,
              Color(0xFF0F172A),
              AppColors.backgroundGradientEnd,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_rounded, color: AppColors.safeGreen, size: 20),
                        const SizedBox(width: 6),
                        Text('HappyWay', style: AppTextStyles.titleSmall),
                      ],
                    ),
                    if (!isLastPage)
                      TextButton(
                        onPressed: _finishOnboarding,
                        child: Text(
                          'Skip',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 48),
                  ],
                ),
              ),

              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final item = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          GlassCard(
                            padding: const EdgeInsets.all(32),
                            borderRadius: 32,
                            backgroundColor: (item['color'] as Color).withValues(alpha: 0.12),
                            borderColor: (item['color'] as Color).withValues(alpha: 0.35),
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: item['iconBg'] as Color,
                                border: Border.all(
                                  color: (item['color'] as Color).withValues(alpha: 0.5),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (item['color'] as Color).withValues(alpha: 0.35),
                                    blurRadius: 32,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Icon(
                                item['icon'] as IconData,
                                color: item['color'] as Color,
                                size: 68,
                              ),
                            ),
                          ),
                          const SizedBox(height: 36),

                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: (item['color'] as Color).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (item['color'] as Color).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              item['badge'] as String,
                              style: AppTextStyles.badgeLabel.copyWith(
                                color: item['color'] as Color,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Text(
                            item['title'] as String,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 12),

                          Text(
                            item['subtitle'] as String,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.5,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                child: Column(
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _currentPage == index
                                ? AppColors.accentCyan
                                : AppColors.glassBorder,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: _onNext,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF38BDF8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.weatherBlue.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
