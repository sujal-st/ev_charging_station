import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart' as app_auth;
import 'station_admin_dashboard.dart';
import 'station_admin_login.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with retry mechanism
  bool firebaseInitialized = false;
  int retryCount = 0;
  const maxRetries = 3;

  while (!firebaseInitialized && retryCount < maxRetries) {
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCH8k7QZ_PEA-xzo-zNEPoogeDIdNPvssc',
          appId: '1:62918470007:android:77335e8a99c426673ed972',
          messagingSenderId: '62918470007',
          projectId: 'ev-charging-station-855bc',
          storageBucket: 'ev-charging-station-855bc.firebasestorage.app',
          authDomain: 'ev-charging-station-855bc.firebaseapp.com',
        ),
      );
      firebaseInitialized = true;
      print('Firebase initialized successfully');
    } catch (e) {
      retryCount++;
      print('Failed to initialize Firebase (attempt $retryCount): $e');
      print('Error type: ${e.runtimeType}');
      
      if (retryCount < maxRetries) {
        print('Retrying Firebase initialization in 2 seconds...');
        await Future.delayed(const Duration(seconds: 2));
      } else {
        print('Max retries reached. Continuing without Firebase...');
        // Continue running the app even if Firebase fails  
      }
    }
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ],
      child: const StationAdminApp(),
    ),
  );
}

class StationAdminApp extends StatelessWidget {
  const StationAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Charging Station Admin',
      theme: ThemeData(
        primarySwatch: Colors.green,
        primaryColor: Colors.green,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const StationAdminSplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StationAdminSplashScreen extends StatefulWidget {
  const StationAdminSplashScreen({super.key});

  @override
  State<StationAdminSplashScreen> createState() => _StationAdminSplashScreenState();
}

class _StationAdminSplashScreenState extends State<StationAdminSplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Check if user is already logged in
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
    final isLoggedIn = authProvider.isLoggedIn;
    final userRole = authProvider.userData?.role;

    if (!mounted) return;

    if (isLoggedIn && userRole == 'charging_station_user') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StationAdminDashboard()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const StationAdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.ev_station,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'CHARGING STATION ADMIN',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Manage Your Stations & Bookings',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

