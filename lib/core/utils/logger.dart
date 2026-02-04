import 'package:flutter/foundation.dart';

/// Simple logger utility for the app
/// Uses debugPrint in debug mode, can be extended for production logging
class AppLogger {
  static void log(String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[BarberApp] $message');
      if (error != null) {
        debugPrint('[BarberApp] Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('[BarberApp] StackTrace: $stackTrace');
      }
    }
    // In production, you can add Firebase Crashlytics, Sentry, etc.
  }
  
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    log(message, error: error, stackTrace: stackTrace);
  }
  
  static void info(String message) {
    log(message);
  }
}
