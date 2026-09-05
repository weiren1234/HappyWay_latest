import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyway/routes/app_routes.dart';
import 'package:happyway/models/user_model.dart';
import 'package:happyway/models/user_preferences.dart';
import 'package:happyway/models/planned_trip.dart';
import 'package:happyway/models/saved_location.dart';
import 'package:happyway/models/travel_location.dart';
import 'package:happyway/screens/login_screen.dart';
import 'package:happyway/screens/register_screen.dart';
import 'package:happyway/screens/email_confirmed_screen.dart';
import 'package:happyway/screens/reset_password_screen.dart';
import 'package:happyway/screens/splash_screen.dart';
import 'package:happyway/providers/auth_provider.dart';
import 'package:happyway/providers/destination_provider.dart';
import 'package:happyway/providers/trip_provider.dart';
import 'package:happyway/providers/navigation_provider.dart';
import 'package:happyway/providers/location_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://syvpbtsyfvhhbwsbwyhc.supabase.co',
      publishableKey: 'sb_publishable_QNnI3ZhpR5rQUX1r9dTLhg_Ihxp6ulC',
    );
  });

  Widget buildTestApp({String initialRoute = AppRoutes.login}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider(autoLoad: false)),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
      ],
      child: MaterialApp(
        initialRoute: initialRoute,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }

  group('Deep Link URI Routing Logic Tests', () {
    test('Identifies email-confirmed deep link correctly', () {
      final uri = Uri.parse('io.happyway.app://email-confirmed#access_token=abc&type=signup');
      expect(uri.scheme, 'io.happyway.app');
      expect(uri.host == 'email-confirmed' || uri.path.contains('email-confirmed'), isTrue);

      expect(uri.host == 'reset-password' || uri.path.contains('reset-password'), isFalse);
    });

    test('Identifies reset-password deep link correctly', () {
      final uri = Uri.parse('io.happyway.app://reset-password#access_token=xyz&type=recovery');
      expect(uri.scheme, 'io.happyway.app');
      expect(uri.host == 'reset-password' || uri.path.contains('reset-password'), isTrue);

      expect(uri.host == 'email-confirmed' || uri.path.contains('email-confirmed'), isFalse);
    });

    test('Ignores external/unrelated URIs', () {
      final uri = Uri.parse('https://happyway.my/about');
      expect(uri.scheme == 'io.happyway.app', isFalse);
    });
  });

  group('Route Generation & Navigation Screen Tests', () {
    testWidgets('AppRoutes.login renders LoginScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.login));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('HappyWay'), findsOneWidget);
      expect(find.text('Sign in to sync your planned trips & saved destinations'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.byType(EmailConfirmedScreen), findsNothing);
    });

    testWidgets('AppRoutes.register renders RegisterScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.register));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterScreen), findsOneWidget);
      expect(find.text('Create Account'), findsWidgets);
      expect(find.byType(EmailConfirmedScreen), findsNothing);
    });

    testWidgets('AppRoutes.emailConfirmed renders EmailConfirmedScreen with Continue to HappyWay CTA', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.emailConfirmed));
      await tester.pumpAndSettle();

      expect(find.byType(EmailConfirmedScreen), findsOneWidget);
      expect(find.text('Email Confirmed'), findsOneWidget);
      expect(find.text('Your account has been verified successfully.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Continue to HappyWay'), findsOneWidget);
    });

    testWidgets('AppRoutes.resetPassword renders ResetPasswordScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.resetPassword));
      await tester.pumpAndSettle();

      expect(find.byType(ResetPasswordScreen), findsOneWidget);
      expect(find.text('Set New Password'), findsOneWidget);
      expect(find.byType(EmailConfirmedScreen), findsNothing);
    });

    testWidgets('AppRoutes.splash renders SplashScreen', (tester) async {
      await tester.pumpWidget(buildTestApp(initialRoute: AppRoutes.splash));
      await tester.pump();

      expect(find.byType(SplashScreen), findsOneWidget);
      expect(find.text('HappyWay'), findsOneWidget);
      expect(find.byType(EmailConfirmedScreen), findsNothing);
    });
  });

  group('Supabase UUID Ownership Model Tests', () {
    const testUserId = 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11';

    test('UserModel references auth user ID and profile display_name', () {
      final user = UserModel.fromSupabase(
        id: testUserId,
        email: 'tanwr-wm23@student.tarc.edu.my',
        profileData: {
          'id': testUserId,
          'display_name': 'Wei Ren',
          'created_at': '2026-08-21T10:00:00Z',
        },
      );

      expect(user.id, testUserId);
      expect(user.name, 'Wei Ren');
      expect(user.email, 'tanwr-wm23@student.tarc.edu.my');
      expect(user.isGuest, isFalse);
    });

    test('UserPreferences references auth user UUID in user_id field', () {
      const prefs = UserPreferences(
        userId: testUserId,
        tripRemindersEnabled: true,
        themeMode: 'dark',
      );

      final json = prefs.toJson();
      expect(json['user_id'], testUserId);
      expect(json['trip_reminders_enabled'], isTrue);
      expect(json['theme_mode'], 'dark');
    });

    test('SavedLocation Supabase payload uses authenticated user UUID in user_id', () {
      final savedLoc = SavedLocation.fromTravelLocation(
        const TravelLocation(
          id: 'met:LOCATION:314',
          name: 'Cameron Highlands',
          latitude: 4.4700,
          longitude: 101.3800,
          state: 'Pahang',
          category: 'Highlands',
          source: TravelLocationSource.metLocation,
          metLocationId: 'LOCATION:314',
          metLocationName: 'Cameron Highlands',
        ),
      );

      final payload = savedLoc.toSupabase(userId: testUserId);
      expect(payload['user_id'], testUserId);
      expect(payload['location_id'], 'met:LOCATION:314');
      expect(payload['location_name'], 'Cameron Highlands');
      expect(payload['latitude'], 4.4700);
      expect(payload['longitude'], 101.3800);
      expect(payload['met_location_id'], 'LOCATION:314');
    });

    test('PlannedTrip Supabase payload uses authenticated user UUID in user_id', () {
      final trip = PlannedTrip(
        destinationLocationId: 'LOCATION:317',
        destinationName: 'Genting Highlands',
        destinationState: 'Pahang',
        destinationCategory: 'Highlands',
        destinationLatitude: 3.4240,
        destinationLongitude: 101.7940,
        travelDate: DateTime(2026, 9, 1),
        originName: 'Current Location',
        createdAt: DateTime(2026, 8, 26),
      );

      final payload = trip.toSupabase(userId: testUserId);
      expect(payload['user_id'], testUserId);
      expect(payload['destination_location_id'], 'LOCATION:317');
      expect(payload['destination_name'], 'Genting Highlands');
      expect(payload['destination_latitude'], 3.4240);
      expect(payload['destination_longitude'], 101.7940);
      expect(payload['travel_date'], '2026-09-01');
    });
  });
}
