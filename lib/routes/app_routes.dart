import 'package:flutter/material.dart';
import '../models/travel_destination.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/email_confirmed_screen.dart';
import '../screens/main_screen.dart';
import '../screens/change_password_screen.dart';
import '../screens/destination_detail_screen.dart';

import '../theme/app_theme.dart';

class AppRoutes {
  AppRoutes._();

  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String emailConfirmed = '/email-confirmed';
  static const String main = '/main';
  static const String destinationDetail = '/destination-detail';
  static const String changePassword = '/change-password';

  static Widget _wrapDarkAuth(Widget child) {
    return Theme(
      data: AppTheme.darkTheme,
      child: child,
    );
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
      case '/splash':
        return MaterialPageRoute(builder: (_) => _wrapDarkAuth(const SplashScreen()));

      case onboarding:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const OnboardingScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case login:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const LoginScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case register:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const RegisterScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case forgotPassword:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const ForgotPasswordScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case resetPassword:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const ResetPasswordScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case emailConfirmed:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => _wrapDarkAuth(const EmailConfirmedScreen()),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case main:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => const MainScreen(),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 400),
        );

      case changePassword:
        return PageRouteBuilder(
          pageBuilder: (ctx, anim, secAnim) => const ChangePasswordScreen(),
          transitionsBuilder: (ctx, animation, secAnim, child) => FadeTransition(
            opacity: animation,
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        );

      case destinationDetail:
        final destination = settings.arguments as TravelDestination;
        return PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              DestinationDetailScreen(destination: destination),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 0.05);
            const end = Offset.zero;
            const curve = Curves.easeOutCubic;

            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final fadeTween = Tween<double>(begin: 0.0, end: 1.0);

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: child,
              ),
            );
          },
        );

      default:
        return MaterialPageRoute(builder: (_) => const MainScreen());
    }
  }
}
