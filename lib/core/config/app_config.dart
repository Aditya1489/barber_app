/// Application configuration
/// 
/// To change the API base URL, modify the values below:
/// - For Android Emulator: Use 'http://10.0.2.2:8000/api/v1'
/// - For iOS Simulator: Use 'http://127.0.0.1:8000/api/v1' or 'http://localhost:8000/api/v1'
/// - For Physical Devices: Use your computer's local IP (e.g., 'http://192.168.1.XXX:8000/api/v1')
/// 
/// To find your local IP:
/// - macOS/Linux: Run `ifconfig` or `ip addr` and look for your local network IP
/// - Windows: Run `ipconfig` and look for IPv4 Address
class AppConfig {
  // Base API URL - Update this with your server's IP address
  // For development, you can use environment variables or const values
  static const String _defaultBaseUrl = 'http://10.0.2.2:8000/api/v1';
  static const String _iosBaseUrl = 'http://127.0.0.1:8000/api/v1';
  
  /// Get the base URL based on the platform
  static String getBaseUrl() {
    // Check for environment variable first (if using flutter_dotenv)
    // For now, use platform detection
    if (const bool.fromEnvironment('USE_LOCALHOST', defaultValue: false)) {
      return _iosBaseUrl;
    }
    
    // Platform-specific URLs
    // Note: For physical iOS devices, you'll need to replace _iosBaseUrl 
    // with your computer's actual IP address
    return _defaultBaseUrl;
  }
  
  /// Get iOS-specific base URL
  /// For physical devices, replace with your computer's IP: 'http://YOUR_IP:8000/api/v1'
  static String getIosBaseUrl() {
    return _iosBaseUrl;
  }
  
  /// Connection timeout in seconds
  static const int connectTimeoutSeconds = 10;
  
  /// Receive timeout in seconds  
  static const int receiveTimeoutSeconds = 10;
}
