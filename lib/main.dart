import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/destination_provider.dart';
import 'providers/location_provider.dart';
import 'providers/trip_provider.dart';
import 'providers/auth_provider.dart';
import 'theme/app_theme.dart';
import 'routes/app_routes.dart';

import 'package:app_links/app_links.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER_ERROR] ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[FLUTTER_STACK] ${details.stack}');
    }
  };
  await Supabase.initialize(
    url: 'https://syvpbtsyfvhhbwsbwyhc.supabase.co',
    publishableKey: 'sb_publishable_QNnI3ZhpR5rQUX1r9dTLhg_Ihxp6ulC',
  );
  runApp(const HappyWayApp());
}

/// HappyWayApp is the root widget for the Smart Travel Assistant application.
class HappyWayApp extends StatefulWidget {
  const HappyWayApp({super.key});

  @override
  State<HappyWayApp> createState() => _HappyWayAppState();
}

class _HappyWayAppState extends State<HappyWayApp> {
  late final StreamSubscription<AuthState> _authSubscription;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();

    // Supabase auth state listener for password recovery event
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamed(AppRoutes.resetPassword);
      }
    });
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();

    // Check if initial deep link opened the app
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    }).catchError((_) {});

    // Listen to incoming deep links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('Deep link error: $err');
      },
    );
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received incoming deep link: $uri (scheme: ${uri.scheme}, host: ${uri.host}, path: ${uri.path})');
    if (uri.scheme != 'io.happyway.app') return;

    if (uri.host == 'email-change-confirmed' || uri.path.contains('email-change-confirmed')) {
      // Email-change confirmation deep link (single-confirmation flow, Secure Email Change OFF).
      // Explicitly refresh the authenticated Supabase user/session and AuthProvider state
      // so Profile immediately shows the new email without requiring logout/restart.
      debugPrint('[DeepLink] email-change-confirmed received — refreshing user and navigating to main, '
          'currentUser.email = ${Supabase.instance.client.auth.currentUser?.email}');
      final navContext = navigatorKey.currentContext;
      if (navContext != null) {
        try {
          final authProvider = Provider.of<AuthProvider>(navContext, listen: false);
          authProvider.refreshAuthenticatedUser();
        } catch (e) {
          debugPrint('[DeepLink] Error calling refreshAuthenticatedUser: $e');
        }
      }
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.main,
        (route) => false,
      );
    } else if (uri.host == 'email-confirmed' || uri.path.contains('email-confirmed')) {
      // Signup email verification deep link (new account, user not yet authenticated).
      navigatorKey.currentState?.pushNamedAndRemoveUntil(
        AppRoutes.emailConfirmed,
        (route) => false,
      );
    } else if (uri.host == 'reset-password' || uri.path.contains('reset-password')) {
      // Password recovery deep link.
      navigatorKey.currentState?.pushNamed(AppRoutes.resetPassword);
    }
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: Consumer2<AuthProvider, ThemeProvider>(
        builder: (context, authProvider, themeProvider, child) {
          final prefTheme = authProvider.preferences?.themeMode;
          if (prefTheme != null) {
            final expectedMode = prefTheme == 'light' ? ThemeMode.light : ThemeMode.dark;
            if (themeProvider.themeMode != expectedMode) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                themeProvider.setThemeMode(prefTheme);
              });
            }
          }

          return MaterialApp(
            navigatorKey: navigatorKey,
            scaffoldMessengerKey: scaffoldMessengerKey,
            title: 'HappyWay - Smart Travel Assistant',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            initialRoute: AppRoutes.splash,
            onGenerateRoute: AppRoutes.onGenerateRoute,
          );
        },
      ),
    );
  }
}
