class AppPaymentConfig {
  // Khalti Public Key - Replace with your actual Khalti public key
  // For testing, use test key from Khalti dashboard
  // For production, use live key from Khalti dashboard
  static const String khaltiPublicKey = '6c487b458d6d48c7ab4c9dbab34e04c7';
  
  // Khalti Secret Key - SECURITY WARNING: This should ideally be on your backend server
  // The epayment/initiate endpoint requires secret key
  // For production, move this to a backend API endpoint
  static const String khaltiSecretKey = '05bf95cc57244045b8df5fad06748dab';
  
  // Payment configuration
  static const bool isProduction = true; // Set to true for production
  
  // Khalti API endpoints
  static String get khaltiBaseUrl => isProduction 
      ? 'https://khalti.com/api/v2' 
      : 'https://a.khalti.com/api/v2';
  
  // Payment verification endpoint
  static String get verificationEndpoint => '$khaltiBaseUrl/payment/verify/';
  
  // Webhook secret (for webhook verification - set in your backend)
  static const String webhookSecret = '';
}

