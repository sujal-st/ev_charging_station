import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'super_admin_dashboard.dart';
import '../login_screen.dart';
import '../providers/auth_provider.dart' as app_auth;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with error handling
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyCH8k7QZ_PEA-xzo-zNEPoogeDIdNPvssc',
          appId: '1:62918470007:android:77335e8a99c426673ed972',
          messagingSenderId: '62918470007',
          projectId: 'ev-charging-station-855bc',
          storageBucket: 'ev-charging-station-855bc.appspot.com',
          authDomain: 'ev-charging-station-855bc.firebaseapp.com',
        ),
      );
    }
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
    // Continue anyway - Firebase might already be initialized
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => app_auth.AuthProvider()),
      ],
      child: const SuperAdminApp(),
    ),
  );
}

class SuperAdminApp extends StatelessWidget {
  const SuperAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Super Admin',
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const SuperAdminMain(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SuperAdminMain extends StatefulWidget {
  const SuperAdminMain({super.key});

  @override
  State<SuperAdminMain> createState() => _SuperAdminMainState();
}

class _SuperAdminMainState extends State<SuperAdminMain> {
  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user != null) {
      // Check user role
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'ev_charging_user';
          
          if (mounted) {
            setState(() {
              _isAuthenticated = role == 'super_user';
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isAuthenticated = false;
              _isLoading = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isAuthenticated = false;
            _isLoading = false;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isAuthenticated = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!_isAuthenticated) {
      return const LoginScreen();
    }

    return const SuperAdminDashboard();
  }
}

