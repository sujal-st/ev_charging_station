import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
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
              title: 'Privacy Policy',
              subtitle: 'Last Updated: 2025',
              content: [
                'Welcome to Bijuli Ghar - EV Charging Station Finder ("we," "our," or "us"). We are committed to protecting your privacy and ensuring the security of your personal information. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
                '',
                'By using our app, you agree to the collection and use of information in accordance with this policy. If you do not agree with our policies and practices, please do not use our app.',
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 32),
            
            // Information We Collect
            _buildSection(
              title: '1. Information We Collect',
              content: [
                '1.1 Personal Information',
                'We collect the following personal information when you create an account and use our services:',
                '• Full Name',
                '• Email Address',
                '• Phone Number (with country code)',
                '• Gender',
                '• Date of Birth',
                '• Profile Picture (optional)',
                '',
                '1.2 Vehicle Information',
                'To facilitate charging station bookings, we collect:',
                '• Vehicle Brand',
                '• Vehicle Model',
                '• Vehicle Trim/Variant',
                '',
                '1.3 Location Data',
                'We collect and process location information to:',
                '• Show nearby charging stations',
                '• Calculate distances to stations',
                '• Provide navigation directions',
                '• Improve location-based services',
                'Location data is collected only when you grant permission and while the app is in use.',
                '',
                '1.4 Booking and Transaction Information',
                'When you make a booking, we collect:',
                '• Booking date and time',
                '• Selected charging station',
                '• Connector type preference',
                '• Payment information (processed securely through Khalti)',
                '• Transaction history',
                '',
                '1.5 Usage Data',
                'We automatically collect certain information about your device and app usage:',
                '• Device type and operating system',
                '• App version',
                '• Usage patterns and preferences',
                '• Crash reports and error logs',
                '',
                '1.6 Favorites and Preferences',
                'We store your favorite charging stations and app preferences to enhance your user experience.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // How We Use Your Information
            _buildSection(
              title: '2. How We Use Your Information',
              content: [
                'We use the collected information for the following purposes:',
                '',
                '2.1 Service Provision',
                '• To create and manage your account',
                '• To process and manage your bookings',
                '• To facilitate payments through Khalti payment gateway',
                '• To provide customer support',
                '• To send booking confirmations and updates',
                '',
                '2.2 Location Services',
                '• To display nearby charging stations',
                '• To calculate distances and provide navigation',
                '• To improve location-based recommendations',
                '',
                '2.3 Communication',
                '• To send important notifications about your bookings',
                '• To respond to your inquiries and support requests',
                '• To send service-related updates (with your consent)',
                '',
                '2.4 App Improvement',
                '• To analyze app usage and improve functionality',
                '• To fix bugs and technical issues',
                '• To develop new features',
                '',
                '2.5 Security and Fraud Prevention',
                '• To verify your identity',
                '• To prevent fraudulent activities',
                '• To protect the security of our services',
                '',
                '2.6 Legal Compliance',
                '• To comply with applicable laws and regulations',
                '• To respond to legal requests and court orders',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Data Storage and Security
            _buildSection(
              title: '3. Data Storage and Security',
              content: [
                '3.1 Data Storage',
                'Your data is stored securely using:',
                '• Firebase Authentication and Firestore (Google Cloud Platform)',
                '• Local device storage (SharedPreferences) for app preferences',
                '• ImgBB for profile and station image storage',
                '',
                '3.2 Security Measures',
                'We implement industry-standard security measures to protect your information:',
                '• Encrypted data transmission (HTTPS/TLS)',
                '• Secure authentication through Firebase',
                '• Regular security audits and updates',
                '• Access controls and authentication',
                '• Secure payment processing through Khalti',
                '',
                '3.3 Data Retention',
                'We retain your personal information for as long as necessary to:',
                '• Provide our services to you',
                '• Comply with legal obligations',
                '• Resolve disputes',
                '• Enforce our agreements',
                'You may request deletion of your account and data at any time.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Third-Party Services
            _buildSection(
              title: '4. Third-Party Services',
              content: [
                'Our app uses the following third-party services that may collect information:',
                '',
                '4.1 Firebase (Google)',
                'We use Firebase for:',
                '• User authentication',
                '• Cloud database (Firestore)',
                '• Phone number verification',
                '• Analytics',
                'Firebase\'s privacy policy: https://firebase.google.com/support/privacy',
                '',
                '4.2 Khalti Payment Gateway',
                'We use Khalti for payment processing:',
                '• Payment transactions are processed securely by Khalti',
                '• We do not store your full payment card details',
                '• Khalti\'s privacy policy applies to payment data',
                'Khalti\'s privacy policy: https://khalti.com/privacy-policy',
                '',
                '4.3 ImgBB',
                'We use ImgBB for image storage:',
                '• Profile pictures and station photos are stored on ImgBB servers',
                '• Images are publicly accessible via URLs',
                '',
                '4.4 Location Services',
                'We use device location services and mapping APIs to provide navigation and location-based features.',
                '',
                '4.5 Analytics',
                'We may use analytics services to understand app usage and improve our services.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Data Sharing and Disclosure
            _buildSection(
              title: '5. Data Sharing and Disclosure',
              content: [
                'We do not sell your personal information. We may share your information only in the following circumstances:',
                '',
                '5.1 Service Providers',
                'We may share information with trusted service providers who assist us in:',
                '• Payment processing (Khalti)',
                '• Cloud storage (Firebase/Google)',
                '• Image hosting (ImgBB)',
                '• Analytics and app improvement',
                '',
                '5.2 Charging Station Owners',
                'When you make a booking, we share necessary information with the charging station owner:',
                '• Your name',
                '• Contact information',
                '• Booking details',
                '• Vehicle information (if relevant)',
                '',
                '5.3 Legal Requirements',
                'We may disclose your information if required by law or to:',
                '• Comply with legal processes',
                '• Respond to government requests',
                '• Protect our rights and safety',
                '• Prevent fraud or security threats',
                '',
                '5.4 Business Transfers',
                'In the event of a merger, acquisition, or sale of assets, your information may be transferred to the new entity.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Your Rights and Choices
            _buildSection(
              title: '6. Your Rights and Choices',
              content: [
                'You have the following rights regarding your personal information:',
                '',
                '6.1 Access and Correction',
                '• You can access and update your personal information through the Profile section',
                '• You can modify your name, email, phone number, and other profile details',
                '',
                '6.2 Account Deletion',
                '• You can request deletion of your account by contacting us',
                '• Upon deletion, we will remove your personal information, subject to legal retention requirements',
                '',
                '6.3 Location Permissions',
                '• You can grant or revoke location permissions through your device settings',
                '• Some features may not work without location permissions',
                '',
                '6.4 Notification Preferences',
                '• You can manage notification settings through your device settings',
                '• You may opt out of promotional communications',
                '',
                '6.5 Data Portability',
                '• You can request a copy of your data in a portable format',
                '• Contact us to exercise this right',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Children's Privacy
            _buildSection(
              title: '7. Children\'s Privacy',
              content: [
                'Our app is not intended for users under the age of 18. We do not knowingly collect personal information from children. If you believe we have collected information from a child, please contact us immediately, and we will take steps to delete such information.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // International Data Transfers
            _buildSection(
              title: '8. International Data Transfers',
              content: [
                'Your information may be transferred to and processed in countries other than your country of residence. These countries may have data protection laws that differ from those in your country. By using our app, you consent to the transfer of your information to these countries.',
                '',
                'We ensure that appropriate safeguards are in place to protect your information in accordance with this Privacy Policy.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Changes to Privacy Policy
            _buildSection(
              title: '9. Changes to This Privacy Policy',
              content: [
                'We may update this Privacy Policy from time to time. We will notify you of any changes by:',
                '• Posting the new Privacy Policy in the app',
                '• Updating the "Last Updated" date',
                '• Sending you a notification (for significant changes)',
                '',
                'You are advised to review this Privacy Policy periodically for any changes. Your continued use of the app after changes are posted constitutes acceptance of the updated policy.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Contact Information
            _buildSection(
              title: '10. Contact Us',
              content: [
                'If you have any questions, concerns, or requests regarding this Privacy Policy or our data practices, please contact us:',
                '',
                'Email: privacy@bijulighar.com',
                'Phone: Available in app settings',
                'Address: [Your Company Address]',
                '',
                'We will respond to your inquiries within a reasonable timeframe.',
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Consent
            _buildSection(
              title: '11. Your Consent',
              content: [
                'By using Bijuli Ghar - EV Charging Station Finder, you consent to our Privacy Policy and agree to its terms. If you do not agree with this policy, please do not use our app.',
                '',
                'Thank you for trusting Bijuli Ghar with your information. We are committed to protecting your privacy and providing you with a secure and reliable service.',
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
    String? subtitle,
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
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ...content.map((text) {
          if (text.isEmpty) {
            return const SizedBox(height: 8);
          }
          final isBold = text.startsWith('•') || 
                        (text.contains(':') && !text.contains('http') && text.length < 100) ||
                        RegExp(r'^\d+\.\d+').hasMatch(text) ||
                        RegExp(r'^[A-Z][a-z]+ [A-Z]').hasMatch(text);
          final isLink = text.contains('http');
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
                color: isLink ? Colors.blue : Colors.black87,
                height: 1.5,
                decoration: isLink ? TextDecoration.underline : null,
              ),
            ),
          );
        }),
      ],
    );
  }
}
