/// Application configuration
/// 
/// API Configuration:
/// - Production: https://backend-barber-zb9j.onrender.com/api/v1
/// - Local Android Emulator: http://10.0.2.2:8000/api/v1
/// - Local iOS Simulator: http://127.0.0.1:8000/api/v1
class AppConfig {
  // Production API URL (Render deployment)
  static const String _productionBaseUrl = 'https://backend-barber-zb9j.onrender.com/api/v1';
  
  // Local development URLs (uncomment for local testing)
  // static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';
  // static const String _iosBaseUrl = 'http://127.0.0.1:8000/api/v1';
  
  // Set to true to use Render backend, false for local development
  static const bool useProduction = false;
  
  /// Get the base URL based on configuration
  static String getBaseUrl() {
    if (useProduction) {
      return _productionBaseUrl;
    }
    // For local Android emulator (use 10.0.2.2) or Physical Device (use Mac IP)
    // Update the IP below to your Mac's local IP for physical device testing
    final url = 'http://192.168.0.101:8000/api/v1';
    print("🏠 LOCAL MODE: getBaseUrl returning $url");
    return url;
  }
  
  /// Get iOS-specific base URL
  static String getIosBaseUrl() {
    if (useProduction) {
      return _productionBaseUrl;
    }
    // For local iOS simulator (127.0.0.1) or Physical Device (use Mac IP)
    final url = 'http://192.168.0.101:8000/api/v1';
    print("🎯 DEBUG: getIosBaseUrl returning $url");
    return url;
  }
  
  /// Connection timeout in seconds
  static const int connectTimeoutSeconds = 30;  // Increased for Render cold starts
  
  /// Receive timeout in seconds  
  static const int receiveTimeoutSeconds = 30;  // Increased for Render cold starts
}
