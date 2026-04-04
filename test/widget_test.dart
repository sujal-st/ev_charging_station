import 'package:ev_charging_station/main.dart';
import 'package:ev_charging_station/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ev_charging_station/providers/auth_provider.dart' as app_auth;
import 'package:ev_charging_station/providers/booking_provider.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockAuthProvider extends Mock implements app_auth.AuthProvider {}
class MockBookingProvider extends Mock implements BookingProvider {}

void main() {
  testWidgets('Navigates to LoginScreen after splash if onboarding is complete', (WidgetTester tester) async {
    // Set the mock instance.
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true, 'is_logged_in': false});

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<app_auth.AuthProvider>(create: (_) => MockAuthProvider()),
          ChangeNotifierProvider<BookingProvider>(create: (_) => MockBookingProvider()),
        ],
        child: const MaterialApp(home: SplashScreen()),
      ),
    );

    // The splash screen is displayed for 2 seconds.
    await tester.pump(const Duration(seconds: 2));

    // Pump again to trigger the navigation.
    await tester.pumpAndSettle();

    // Verify that the app has navigated to the LoginScreen.
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}