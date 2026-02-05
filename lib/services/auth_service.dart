import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/base_api_service.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Authentication service handling login and registration.
final authServiceProvider = Provider((ref) => AuthService(ref.read(baseApiProvider)));

class AuthService {
  final BaseApiService _api;
  
  AuthService(this._api);

  /// Login with email and password.
  Future<Map<String, dynamic>?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) {
      AppLogger.error('Login called with empty email or password');
      return null;
    }
    try {
      final response = await _api.dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error logging in', e);
      return null;
    }
  }

  /// Register a new user.
  Future<Map<String, dynamic>?> register(Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.post('/auth/register', data: data);
      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error registering', e);
      return null;
    }
  }
}
