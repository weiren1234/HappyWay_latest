import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:happyway/screens/login_screen.dart';
import 'package:happyway/screens/register_screen.dart';
import 'package:happyway/screens/forgot_password_screen.dart';
import 'package:happyway/screens/reset_password_screen.dart';
import 'package:happyway/providers/auth_provider.dart';
import 'package:happyway/providers/destination_provider.dart';
import 'package:happyway/providers/trip_provider.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://syvpbtsyfvhhbwsbwyhc.supabase.co',
      publishableKey: 'sb_publishable_QNnI3ZhpR5rQUX1r9dTLhg_Ihxp6ulC',
    );
  });

  Widget buildTestableWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DestinationProvider()),
        ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Login Form Validation Tests', () {
    testWidgets('Shows error on empty submit and removes error immediately on user typing', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const LoginScreen()));
      await tester.pumpAndSettle();

      final signInBtn = find.widgetWithText(ElevatedButton, 'Sign In');
      await tester.tap(signInBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);

      final emailField = find.byType(TextFormField).first;
      await tester.enterText(emailField, 'tanwr-wm23@student.tarc.edu.my');
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsNothing);
      expect(find.text('Please enter a valid email address.'), findsNothing);

      expect(find.text('Please enter your password.'), findsOneWidget);

      final passwordField = find.byType(TextFormField).last;
      await tester.enterText(passwordField, '123456');
      await tester.pumpAndSettle();

      expect(find.text('Please enter your password.'), findsNothing);
    });
  });

  group('Register Form Validation Tests', () {
    testWidgets('Validates name, email, password, and confirm password interactively', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const RegisterScreen()));
      await tester.pumpAndSettle();

      final createAccountBtn = find.widgetWithText(ElevatedButton, 'Create Account');
      await tester.tap(createAccountBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your display name.'), findsOneWidget);
      expect(find.text('Please enter your email.'), findsOneWidget);
      expect(find.text('Please enter your password.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'Wei Ren');
      await tester.pumpAndSettle();
      expect(find.text('Please enter your display name.'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(1), 'tanwr-wm23@student.tarc.edu.my');
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email.'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(2), '123');
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 6 characters.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(2), '123456');
      await tester.pumpAndSettle();
      expect(find.text('Password must be at least 6 characters.'), findsNothing);

      await tester.enterText(find.byType(TextFormField).at(3), '654321');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsNothing);
    });
  });

  group('Forgot Password Form Validation Tests', () {
    testWidgets('Validates email format interactively', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ForgotPasswordScreen()));
      await tester.pumpAndSettle();

      final sendBtn = find.widgetWithText(ElevatedButton, 'Send Reset Link');
      await tester.tap(sendBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'user-123@company.com.my');
      await tester.pumpAndSettle();
      expect(find.text('Please enter your email.'), findsNothing);
    });
  });

  group('Reset Password Form Validation Tests', () {
    testWidgets('Validates new password & confirm password interactively', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ResetPasswordScreen()));
      await tester.pumpAndSettle();

      final updateBtn = find.widgetWithText(ElevatedButton, 'Update Password');
      await tester.tap(updateBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a new password.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'mypassword123');
      await tester.pumpAndSettle();
      expect(find.text('Please enter a new password.'), findsNothing);

      await tester.enterText(find.byType(TextFormField).last, 'wrongpassword');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).last, 'mypassword123');
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsNothing);
    });
  });
}
