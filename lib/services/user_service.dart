import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/base_api_service.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Service for user profile operations.
final userServiceProvider = Provider((ref) => UserService(ref.read(baseApiProvider)));

class UserService {
  final BaseApiService _api;
  
  UserService(this._api);

  /// Update user profile.
  Future<Map<String, dynamic>?> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.patch('/profile/$userId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating profile', e);
      return null;
    }
  }

  /// Update user permissions.
  Future<Map<String, dynamic>?> updatePermissions(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.patch('/profile/$userId/permissions', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating permissions', e);
      return null;
    }
  }

  /// Get staff profile.
  Future<Map<String, dynamic>?> getStaffProfile(String staffId) async {
    try {
      final response = await _api.dio.get('/shops/staff/$staffId');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff profile', e);
      return null;
    }
  }

  /// Update staff profile.
  Future<Map<String, dynamic>?> updateStaffProfile(String staffId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.patch('/shops/staff/$staffId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating staff profile', e);
      return null;
    }
  }

  /// Get staff reviews.
  Future<List<dynamic>> getStaffReviews(String staffId) async {
    try {
      final response = await _api.dio.get('/reviews/', queryParameters: {'staff_id': staffId});
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching staff reviews', e);
      return [];
    }
  }

  /// Get staff review statistics.
  Future<Map<String, dynamic>?> getStaffReviewStats(String staffId) async {
    try {
      final response = await _api.dio.get('/reviews/stats', queryParameters: {'staff_id': staffId});
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching review stats', e);
      return null;
    }
  }
}
