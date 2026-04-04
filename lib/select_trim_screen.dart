import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/vehicle_service.dart';
import 'my_vehicles_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class SelectTrimScreen extends StatefulWidget {
  final String brand;
  final String model;
  final bool isFromSignup;

  const SelectTrimScreen({
    super.key,
    required this.brand,
    required this.model,
    this.isFromSignup = false,
  });

  @override
  State<SelectTrimScreen> createState() => _SelectTrimScreenState();
}

class _SelectTrimScreenState extends State<SelectTrimScreen> {
  final VehicleService _vehicleService = VehicleService();
  final bool _isSaving = false;
  // Car brand model trims
  final Map<String, Map<String, List<String>>> carBrandModelTrims = {
    "BYD": {
      "Atto 3": ["Advanced Variant 49.92 kWh", "Superior Variant 60.48 kWh"],
      "Seal": ["Premium", "Performance"],
      "Dolphin": ["Active", "Boost", "Premium"],
      "Han EV": ["Premium", "Performance"],
    },
    "Tesla": {
      "Model 3": ["Standard Range", "Long Range", "Performance"],
      "Model S": ["Standard", "Plaid"],
      "Model X": ["Standard", "Plaid"],
      "Model Y": ["Standard Range", "Long Range", "Performance"],
    },
    "Leapmotor": {
      "T03": ["Standard", "Premium"],
      "C11": ["Standard", "Premium", "Flagship"],
      "C01": ["Standard", "Premium"],
    },
    "Tata": {
      "Nexon EV": ["Prime", "Max", "Dark Edition"],
      "Tiago EV": ["XE", "XT", "XZ+"],
      "Tigor EV": ["XE", "XM", "XZ+"],
    },
    "MG": {
      "ZS EV": ["Excite", "Exclusive"],
      "Comet EV": ["Pace", "Play", "Plush"],
    },
    "Hyundai": {
      "Kona Electric": ["Premium", "Ultimate"],
      "Ioniq 5": ["SE", "SEL", "Limited"],
      "Ioniq 6": ["SE", "SEL", "Limited"],
    },
    "Dongfeng": {
      "Fengshen E70": ["Standard", "Premium"],
      "Fengshen Yixuan EV": ["Standard", "Premium"],
    },
    "Nammi": {
      "EV1": ["Standard", "Premium"],
    },
    "Seres": {
      "SF5": ["Standard", "Premium"],
      "SF7": ["Standard", "Premium", "Flagship"],
    },
    "Jaecoo": {
      "J7": ["Standard", "Premium"],
      "J8": ["Standard", "Premium", "Flagship"],
    },
  };

  // Bike/Scooter brand model trims
  final Map<String, Map<String, List<String>>> bikeBrandModelTrims = {
    "Ultraviolette": {
      "F77": ["Airstrike", "Shadow", "Laser"],
    },
    "NIU": {
      "NQi GT": ["Standard", "Pro"],
      "MQi+": ["Standard", "Sport"],
      "UQi GT": ["Standard", "Pro"],
    },
    "Ather": {
      "450X": ["Standard", "Pro"],
      "450 Plus": ["Standard", "Pro"],
    },
    "Segway": {
      "E110S": ["Standard", "Premium"],
      "E125S": ["Standard", "Premium"],
      "E300SE": ["Standard", "Premium"],
    },
    "Yatri": {
      "P-0": ["Standard", "Premium"],
      "P-1": ["Standard", "Premium"],
    },
    "Super Soco": {
      "TC Max": ["Standard", "Premium"],
      "CPx": ["Standard", "Premium"],
      "CUx": ["Standard", "Premium"],
    },
    "Komaki": {
      "X-One": ["Standard", "Premium"],
      "XGT X5": ["Standard", "Premium"],
      "MX3": ["Standard", "Premium"],
    },
    "Yadea": {
      "G5": ["Standard", "Premium"],
      "C1S": ["Standard", "Premium"],
      "KS5": ["Standard", "Premium"],
    },
  };

  @override
  Widget build(BuildContext context) {
    // Determine if the brand is a car or bike brand and get the appropriate trims
    List<String> trims = [];

    if (carBrandModelTrims.containsKey(widget.brand)) {
      trims = carBrandModelTrims[widget.brand]?[widget.model] ?? [];
    } else {
      trims = bikeBrandModelTrims[widget.brand]?[widget.model] ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Trim"),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(color: Colors.black),
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header showing selected model
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Text(
                  "${widget.brand} ${widget.model}",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // List of trims
          Expanded(
            child: ListView.separated(
              itemCount: trims.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final trim = trims[index];
                return ListTile(
                  title: Text(trim),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    // Navigate to success screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupSuccessScreen(
                          brand: widget.brand,
                          model: widget.model,
                          trim: trim,
                          isFromSignup: widget.isFromSignup,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Success screen after vehicle selection
class SignupSuccessScreen extends StatefulWidget {
  final String brand;
  final String model;
  final String trim;
  final bool isFromSignup;

  const SignupSuccessScreen({
    super.key,
    required this.brand,
    required this.model,
    required this.trim,
    this.isFromSignup = false,
  });

  @override
  State<SignupSuccessScreen> createState() => _SignupSuccessScreenState();
}

class _SignupSuccessScreenState extends State<SignupSuccessScreen> {
  bool _isLoading = false;

  Future<void> saveVehicleAndContinue() async {
    if (_isLoading) return; // Prevent multiple taps
    
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No authenticated user found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Extract battery capacity from trim text if present
      String batteryCapacity = '';
      final trimLower = widget.trim.toLowerCase();
      if (trimLower.contains('kwh')) {
        // Extract kWh value from trim
        final regex = RegExp(r'(\d+\.?\d*)\s*kwh', caseSensitive: false);
        final match = regex.firstMatch(widget.trim);
        if (match != null) {
          batteryCapacity = '${match.group(1)} kWh';
        }
      }
      
      // Add vehicle to Firestore
      final vehicleId = await VehicleService().addVehicle(
        userId: user.uid,
        brand: widget.brand,
        model: widget.model,
        trim: widget.trim,
        batteryCapacity: batteryCapacity,
        isDefault: true,
      );

      print('Vehicle added successfully with ID: $vehicleId');

      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vehicle saved successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Wait a brief moment to ensure Firestore has processed the write
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // If from signup, sign out and redirect to login screen
      if (widget.isFromSignup) {
        // Sign out the user after saving vehicle
        await FirebaseAuth.instance.signOut();
        // Clear login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', false);
        
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
      } else {
        // Navigate to ProfileScreen first, then push MyVehiclesScreen on top
        // This ensures that when back is pressed from MyVehiclesScreen, it goes to ProfileScreen
        // The stream listener in MyVehiclesScreen will automatically show the new vehicle
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfileScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
        
        // Wait a frame to ensure ProfileScreen is built
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (!mounted) return;
        
        // Now push MyVehiclesScreen on top of ProfileScreen
        // The stream will automatically update with the new vehicle
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MyVehiclesScreen(),
          ),
        );
      }
      
    } catch (e) {
      print('Error saving vehicle: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save vehicle: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 50,
                ),
              ),
              const SizedBox(height: 24),
              // Success message
              const Text(
                "Signup Successful!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              // Vehicle details
              Text(
                "Vehicle: ${widget.brand} ${widget.model} ${widget.trim}",
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                "You can now find charging stations near you.",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Continue button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : saveVehicleAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isLoading ? Colors.grey : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: _isLoading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                            SizedBox(width: 12),
                            Text("Saving & Navigating..."),
                          ],
                        )
                      : const Text("Save Vehicle & Continue"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
