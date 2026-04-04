import 'package:flutter/material.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Help Center',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Introduction
            _buildSection(
              title: 'Welcome to Bijuli Ghar - EV Charging Station Finder',
              content: [
                'Bijuli Ghar is your comprehensive solution for finding, booking, and managing EV charging stations. This guide will help you understand and use all features of the application effectively.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Table of Contents
            _buildSection(
              title: 'Table of Contents',
              content: [
                '1. Getting Started',
                '2. Account Management',
                '3. Finding Charging Stations',
                '4. Booking a Charging Station',
                '5. Managing Your Vehicles',
                '6. Payment Methods',
                '7. Favorites',
                '8. My Bookings',
                '9. Profile Management',
                '10. Troubleshooting',
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            
            // Section 1: Getting Started
            _buildSection(
              title: '1. Getting Started',
              content: [
                '1.1 Download and Installation',
                'Download the Bijuli Ghar app from the App Store (iOS) or Google Play Store (Android). Once installed, open the app to begin.',
                '',
                '1.2 First Launch',
                'When you first open the app, you will see the login screen. If you are a new user, tap on "Don\'t have an account? Sign Up" to create a new account.',
                '',
                '1.3 App Navigation',
                'The app uses a bottom navigation bar with four main sections:',
                '• Home: Browse and search for charging stations',
                '• Favorites: View your saved favorite stations',
                '• My Bookings: Manage your charging bookings',
                '• Profile: Access your account settings and information',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 2: Account Management
            _buildSection(
              title: '2. Account Management',
              content: [
                '2.1 Creating an Account',
                'To create a new account:',
                '1. Tap "Don\'t have an account? Sign Up" on the login screen',
                '2. Fill in the required information:',
                '   • Full Name',
                '   • Email Address',
                '   • Phone Number (must include country code, e.g., +977)',
                '   • Password (minimum 6 characters)',
                '   • Confirm Password',
                '   • Gender',
                '   • Date of Birth',
                '3. Tap "Continue" to proceed',
                '4. You will receive an OTP (One-Time Password) via SMS to verify your phone number',
                '5. Enter the 6-digit OTP code in the verification screen',
                '6. After verification, you can optionally add a vehicle or skip to complete registration',
                '',
                '2.2 Phone Number Verification',
                'Phone verification is mandatory for account security:',
                '• Enter the 6-digit OTP sent to your phone number',
                '• If you don\'t receive the OTP, tap "Resend OTP" after 60 seconds',
                '• The OTP is valid for a limited time',
                '• For development/testing, you can use test phone numbers configured in Firebase',
                '',
                '2.3 Logging In',
                'To log in to your account:',
                '1. Enter your email address',
                '2. Enter your password',
                '3. Tap "Login"',
                '4. If you forget your password, tap "Forgot Password?" to reset it',
                '',
                '2.4 Password Reset',
                'If you forget your password:',
                '1. Tap "Forgot Password?" on the login screen',
                '2. Enter your email address',
                '3. Tap "Send Reset Link"',
                '4. Check your email for a password reset link',
                '5. Click the link and follow the instructions to set a new password',
                '',
                '2.5 Logging Out',
                'To log out:',
                '1. Go to Profile tab',
                '2. Scroll down and tap "Log out"',
                '3. Confirm your action in the dialog',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 3: Finding Charging Stations
            _buildSection(
              title: '3. Finding Charging Stations',
              content: [
                '3.1 Home Screen Overview',
                'The Home screen displays a map with all available charging stations in your area. You can:',
                '• View station locations on the map',
                '• See station availability status',
                '• View distance from your current location',
                '',
                '3.2 Searching for Stations',
                'To search for a charging station:',
                '1. Use the search bar at the top of the Home screen',
                '2. Enter the station name or location',
                '3. Tap on a result to view station details',
                '',
                '3.3 Viewing Station Details',
                'When you tap on a station, you will see:',
                '• Station name and address',
                '• Distance from your location',
                '• Available connectors and types',
                '• Pricing information',
                '• Station status (Available/Busy)',
                '• Contact information',
                '• Parking availability',
                '• Description',
                '',
                '3.4 Filtering Stations',
                'You can filter stations by:',
                '• Availability status',
                '• Connector type',
                '• Distance',
                '• Price range',
                '',
                '3.5 Using Location Services',
                'The app uses your device\'s location to:',
                '• Show nearby stations',
                '• Calculate distances',
                '• Provide navigation directions',
                'Make sure location services are enabled for the app in your device settings.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 4: Booking a Charging Station
            _buildSection(
              title: '4. Booking a Charging Station',
              content: [
                '4.1 Creating a Booking',
                'To book a charging station:',
                '1. Find a station on the Home screen or search results',
                '2. Tap on the station to view details',
                '3. Tap "Book Now" button',
                '4. Select your vehicle from the list (or add a new one)',
                '5. Choose a connector type',
                '6. Select a date for charging',
                '7. Select a time slot',
                '8. Review booking details',
                '9. Tap "Confirm Booking"',
                '',
                '4.2 Selecting Connectors',
                'When booking, you can see:',
                '• Available connectors (shown in green)',
                '• Booked time slots (shown in red)',
                '• All time slots for the selected connector',
                'You can select any connector, even if it has booked slots, as long as you choose an available time slot.',
                '',
                '4.3 Time Slot Selection',
                'The time slot picker shows:',
                '• Available slots in green',
                '• Booked slots in red',
                '• All available times for your selected date',
                'Select an unbooked time slot to proceed with your booking.',
                '',
                '4.4 Booking Confirmation',
                'After confirming your booking:',
                '• You will receive a booking confirmation',
                '• The booking will appear in "My Bookings"',
                '• You can view booking details anytime',
                '',
                '4.5 Payment for Bookings',
                'Payment is processed through Khalti payment gateway:',
                '• Select your payment method',
                '• Enter payment details',
                '• Complete the transaction',
                '• Receive payment confirmation',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 5: Managing Your Vehicles
            _buildSection(
              title: '5. Managing Your Vehicles',
              content: [
                '5.1 Adding a Vehicle',
                'To add a new vehicle:',
                '1. Go to Profile → My Vehicle',
                '2. Tap "Add Vehicle" button',
                '3. Select vehicle brand from the list',
                '4. Select vehicle model',
                '5. Select vehicle trim/variant',
                '6. Review vehicle details',
                '7. Tap "Save Vehicle"',
                '',
                '5.2 Viewing Your Vehicles',
                'To view all your vehicles:',
                '1. Go to Profile → My Vehicle',
                '2. You will see a list of all your registered vehicles',
                '3. Each vehicle shows:',
                '   • Brand, Model, and Trim',
                '   • Vehicle details',
                '',
                '5.3 Editing Vehicle Information',
                'Currently, vehicle information cannot be edited after creation. If you need to update vehicle details, you may need to contact support.',
                '',
                '5.4 Deleting a Vehicle',
                'To remove a vehicle from your account, contact support or use the delete option if available in the vehicle details screen.',
                '',
                '5.5 Vehicle Selection During Booking',
                'When creating a booking, you can:',
                '• Select from your saved vehicles',
                '• Add a new vehicle on the spot',
                'The selected vehicle information is used to determine compatible connector types.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 6: Payment Methods
            _buildSection(
              title: '6. Payment Methods',
              content: [
                '6.1 Adding Payment Methods',
                'To add a payment method:',
                '1. Go to Profile → Payment methods',
                '2. Tap "Add Payment Method"',
                '3. Select payment type (Credit Card, Debit Card, etc.)',
                '4. Enter payment details',
                '5. Save the payment method',
                '',
                '6.2 Managing Payment Methods',
                'In the Payment methods screen, you can:',
                '• View all saved payment methods',
                '• Set a default payment method',
                '• Remove payment methods',
                '',
                '6.3 Payment Processing',
                'The app uses Khalti payment gateway for secure transactions:',
                '• All payments are encrypted',
                '• Payment information is securely stored',
                '• You receive payment confirmations',
                '',
                '6.4 Payment History',
                'View your payment history in the booking details or payment tracking section.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 7: Favorites
            _buildSection(
              title: '7. Favorites',
              content: [
                '7.1 Adding Stations to Favorites',
                'To add a station to favorites:',
                '1. Open a station\'s detail screen',
                '2. Tap the heart icon (favorite button)',
                '3. The station will be saved to your favorites',
                '',
                '7.2 Viewing Favorite Stations',
                'To view your favorite stations:',
                '1. Tap the "Favorites" tab in the bottom navigation',
                '2. You will see all your saved favorite stations',
                '3. Stations are sorted by distance (if location is available)',
                '',
                '7.3 Removing from Favorites',
                'To remove a station from favorites:',
                '1. Go to Favorites tab',
                '2. Tap the heart icon on the station you want to remove',
                '3. The station will be removed from your favorites',
                '',
                '7.4 Favorite Station Features',
                'Favorite stations show:',
                '• Station name and address',
                '• Distance from your location',
                '• Availability status',
                '• Quick access to station details',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 8: My Bookings
            _buildSection(
              title: '8. My Bookings',
              content: [
                '8.1 Viewing Your Bookings',
                'To view all your bookings:',
                '1. Tap "My Bookings" in the bottom navigation',
                '2. You will see a list of all your bookings',
                '3. Bookings are organized by status:',
                '   • Upcoming',
                '   • Completed',
                '   • Cancelled',
                '',
                '8.2 Booking Details',
                'Each booking shows:',
                '• Station name and location',
                '• Booking date and time',
                '• Vehicle information',
                '• Connector type',
                '• Booking status',
                '• Payment information',
                '',
                '8.3 Managing Bookings',
                'You can:',
                '• View booking details',
                '• Track payment status',
                '• View booking history',
                '• Contact station for support',
                '',
                '8.4 Booking Status',
                'Booking statuses include:',
                '• Pending: Awaiting confirmation',
                '• Confirmed: Booking is confirmed',
                '• Completed: Charging session finished',
                '• Cancelled: Booking was cancelled',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 9: Profile Management
            _buildSection(
              title: '9. Profile Management',
              content: [
                '9.1 Viewing Your Profile',
                'To view your profile:',
                '1. Tap "Profile" in the bottom navigation',
                '2. You will see your name and email at the top',
                '',
                '9.2 Updating Personal Information',
                'To update your personal information:',
                '1. Go to Profile → Personal info',
                '2. Edit any of the following fields:',
                '   • Full Name',
                '   • Email',
                '   • Phone Number',
                '   • Gender',
                '   • Date of Birth',
                '3. Tap "Save Changes" to update',
                '',
                '9.3 Profile Picture',
                'To change your profile picture:',
                '1. Go to Profile → Personal info',
                '2. Tap the camera icon on your profile picture',
                '3. Select a photo from your gallery or take a new one',
                '4. Crop and adjust the image',
                '5. Save the changes',
                '',
                '9.4 Account Settings',
                'In the Profile section, you can access:',
                '• Payment methods',
                '• Personal information',
                '• Vehicle management',
                '• Help center',
                '• Privacy policy',
                '• About the app',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Section 10: Troubleshooting
            _buildSection(
              title: '10. Troubleshooting',
              content: [
                '10.1 OTP Not Received',
                'If you don\'t receive the OTP:',
                '• Check your phone number is correct',
                '• Ensure you have network connectivity',
                '• Wait 60 seconds and tap "Resend OTP"',
                '• For development, use test phone numbers configured in Firebase',
                '• Check if Firebase billing is enabled (required for production)',
                '',
                '10.2 Login Issues',
                'If you cannot log in:',
                '• Verify your email and password are correct',
                '• Use "Forgot Password" to reset your password',
                '• Ensure you have internet connectivity',
                '• Check if your account is active',
                '',
                '10.3 Booking Problems',
                'If you experience booking issues:',
                '• Ensure you have selected a vehicle',
                '• Check that the time slot is available',
                '• Verify your payment method is valid',
                '• Check your internet connection',
                '',
                '10.4 Location Services',
                'If location features are not working:',
                '• Enable location services in device settings',
                '• Grant location permissions to the app',
                '• Ensure GPS is enabled',
                '',
                '10.5 Payment Issues',
                'If payment fails:',
                '• Verify your payment method details',
                '• Check your account balance',
                '• Ensure you have internet connectivity',
                '• Contact Khalti support if issues persist',
                '',
                '10.6 App Crashes or Freezes',
                'If the app crashes or freezes:',
                '• Close and restart the app',
                '• Clear app cache (device settings)',
                '• Update to the latest app version',
                '• Restart your device',
                '• Reinstall the app if problems persist',
                '',
                '10.7 Contact Support',
                'For additional help:',
                '• Check this Help Center for common issues',
                '• Contact support through the app',
                '• Email: support@bijulighar.com',
                '• Phone: Available in app settings',
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Footer
            _buildSection(
              title: 'Additional Information',
              content: [
                'App Version: 1.0.0',
                'Last Updated: 2024',
                '',
                'For the most up-to-date information and features, please ensure you are using the latest version of the app.',
                '',
                'Thank you for using Bijuli Ghar - Your trusted EV charging station finder!',
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<String> content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...content.map((text) {
          if (text.isEmpty) {
            return const SizedBox(height: 8);
          }
          final isBold = text.startsWith('•') || 
                        text.contains(':') && !text.contains('http') ||
                        RegExp(r'^\d+\.').hasMatch(text);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
          );
        }),
      ],
    );
  }
}
