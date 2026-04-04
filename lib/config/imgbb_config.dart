/// ImgBB API Configuration
/// 
/// To get your API key:
/// 1. Go to https://imgbb.com/
/// 2. Sign up or log in
/// 3. Go to API section in your account dashboard
/// 4. Generate your API key
/// 5. Replace the key below
class ImgBBConfig {
  // TODO: Replace with your ImgBB API key
  // Get it from: https://api.imgbb.com/
  static const String apiKey = '33caf171d578ea6f25099166100c6a99';
  
  static const String uploadEndpoint = 'https://api.imgbb.com/1/upload';
  
  /// Maximum file size: 32MB (ImgBB free tier limit)
  static const int maxFileSizeBytes = 32 * 1024 * 1024;
  
  /// Recommended compression to reduce upload time
  static const int recommendedMaxSizeBytes = 5 * 1024 * 1024; // 5MB
}

