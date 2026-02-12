import 'dart:io';
import 'package:dio/dio.dart';
import 'package:barber_sync/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/core/config/app_config.dart';
import 'package:barber_sync/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: Platform.isAndroid 
          ? AppConfig.getBaseUrl() 
          : AppConfig.getIosBaseUrl(),
      connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
      receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add Auth Token
        final prefs = await SharedPreferences.getInstance();
        final userJson = prefs.getString('auth_user');
        if (userJson != null) {
          try {
            final userMap = jsonDecode(userJson);
            final token = userMap['token'];
            if (token != null) {
              print('DEBUG: Attaching token: ${token.substring(0, 10)}...');
              options.headers['Authorization'] = 'Bearer $token';
            } else {
              print('DEBUG: No token found in stored user data.');
            }
          } catch (e) {
            print('DEBUG: Error parsing stored user: $e');
          }
        } else {
          print('DEBUG: No stored user found.');
        }
        return handler.next(options);
      },
    ));
  }
  
  String get baseUrl => _dio.options.baseUrl.replaceAll('/api/v1', '');

  String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('assets/')) return null;
    
    // DON'T resolve if it's an absolute local path (starts with /data, /Users, /var etc)
    // This prevents 404s when local paths accidentally leak into the database
    if (path.startsWith('/data/') || path.startsWith('/Users/') || path.startsWith('/var/')) {
      return path; 
    }
    
    // Ensure relative paths from server are full URLs
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  // OTP Authentication
  Future<bool> requestOtp(String phone) async {
    try {
      final response = await _dio.post('/auth/otp/request', data: {
        'phone': phone,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error requesting OTP', e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> verifyOtp(String phone, String code) async {
    try {
      final response = await _dio.post('/auth/otp/verify', data: {
        'phone': phone,
        'code': code,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error verifying OTP', e);
      return null;
    }
  }

  // OTP Update Phone
  Future<bool> requestUpdateOtp(String newPhone) async {
    try {
      final response = await _dio.post('/auth/otp/request-update', data: {
        'new_phone': newPhone,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error requesting update OTP', e);
      return false;
    }
  }

  Future<bool> verifyUpdateOtp(String newPhone, String code) async {
    try {
      final response = await _dio.post('/auth/otp/verify-update', data: {
        'new_phone': newPhone,
        'code': code,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error verifying update OTP', e);
      return false;
    }
  }

  Future<Map<String, dynamic>?> selectRole(String userId, String role, String? shopId) async {
    try {
      final response = await _dio.post('/auth/login/select-role', data: {
        'user_id': userId,
        'role': role,
        'shop_id': shopId,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error selecting role', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> registerUser(String token, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post(
        '/auth/register', 
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error registering user', e);
      return null;
    }
  }

  Future<String?> uploadFile(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await _dio.post('/uploads', data: formData);
      if (response.statusCode == 200 && response.data != null) {
        return response.data['url'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error uploading file', e);
      return null;
    }
  }

  Future<List<BarberShop>> getShops({double? lat, double? lng, double? radius}) async {
    try {
      final response = await _dio.get('/shops', queryParameters: {
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radius != null) 'radius': radius,
      });
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => BarberShop.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shops', e);
      return [];
    }
  }

  Future<List<dynamic>> getShopsByOwner(String ownerId) async {
    if (ownerId.isEmpty) {
      AppLogger.error('getShopsByOwner called with empty ownerId');
      return [];
    }
    try {
      final response = await _dio.get('/shops/owned-by/$ownerId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching owner shops: $e');
      return [];
    }
  }

  Future<List<Appointment>> getAppointments({String? customerId, String? staffId, String? shopId, int? limit}) async {
    try {
      final response = await _dio.get('/bookings/', queryParameters: {
        if (customerId != null) 'customer_id': customerId,
        if (staffId != null) 'staff_id': staffId,
        if (shopId != null) 'shop_id': shopId,
        if (limit != null) 'limit': limit,
      });
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => Appointment.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching appointments: $e');
      return [];
    }
  }

  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      final response = await _dio.patch('/bookings/$bookingId/status', queryParameters: {
        'new_status': status,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error updating booking status: $e');
      return false;
    }
  }

  Future<User?> updateProfile(String userId, Map<String, dynamic> data) async {
    if (userId.isEmpty) {
      AppLogger.error('updateProfile called with empty userId');
      return null;
    }
    try {
      final response = await _dio.put('/profile/$userId', data: data);
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating profile: $e');
      return null;
    }
  }

  Future<String?> getNavigationLink(String shopId, {double? lat, double? lng}) async {
    if (shopId.isEmpty) {
      AppLogger.error('getNavigationLink called with empty shopId');
      return null;
    }
    try {
      final response = await _dio.get(
        '/shops/$shopId/navigation',
        queryParameters: {
          if (lat != null) 'customer_lat': lat,
          if (lng != null) 'customer_lng': lng,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return response.data['googleMapsUrl'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching navigation link: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updatePermissions(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/profile/$userId/permissions', data: data);
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data);
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating permissions: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getOwnerAnalytics(String ownerId, {String? period, String? shopId}) async {
    try {
      final response = await _dio.get(
        '/analytics/owner/$ownerId',
        queryParameters: {
          if (period != null) 'period': period.toLowerCase(),
          if (shopId != null) 'shop_id': shopId,
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching owner analytics: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaffEarnings(String staffId, {String? period}) async {
    try {
      final response = await _dio.get(
        '/analytics/staff/$staffId/earnings',
        queryParameters: {
          if (period != null) 'period': period.toLowerCase(),
        },
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff earnings: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaffProfile(String staffId) async {
    if (staffId.isEmpty) {
      AppLogger.error('getStaffProfile called with empty staffId');
      return null;
    }
    try {
      final response = await _dio.get('/shops/staff/$staffId/profile');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff profile: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> createShop(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/shops/', data: data);
      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating shop: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateShop(String shopId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/shops/$shopId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating shop: $e');
      return null;
    }
  }

  Future<List<dynamic>> getShopServices(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/services');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop services: $e');
      return [];
    }
  }

  Future<List<dynamic>> getPopularServices(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/services/popular');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching popular services: $e');
      return [];
    }
  }

  Future<dynamic> addService(String shopId, Map<String, dynamic> data) async {
    if (shopId.isEmpty) {
      AppLogger.error('addService called with empty shopId');
      return null;
    }
    try {
      final response = await _dio.post('/shops/$shopId/services', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error adding service: $e');
      return null;
    }
  }

  Future<dynamic> updateService(String shopId, String serviceId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/shops/$shopId/services/$serviceId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating service: $e');
      return null;
    }
  }

  Future<bool> deleteService(String shopId, String serviceId) async {
    if (shopId.isEmpty || serviceId.isEmpty) {
      AppLogger.error('deleteService called with empty shopId or serviceId');
      return false;
    }
    try {
      final response = await _dio.delete('/shops/$shopId/services/$serviceId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      AppLogger.error('Error deleting service: $e');
      return false;
    }
  }

  // Staff Management
  Future<List<dynamic>> getShopStaff(String shopId) async {
    try {
      final response = await _dio.get('/shops/$shopId/staff');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop staff: $e');
      return [];
    }
  }

  Future<dynamic> createStaffForShop(String shopId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/shops/$shopId/staff-create', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating staff: $e');
      return null;
    }
  }

  Future<bool> removeStaffFromShop(String shopId, String staffId) async {
    if (shopId.isEmpty || staffId.isEmpty) {
      AppLogger.error('removeStaffFromShop called with empty shopId or staffId');
      return false;
    }
    try {
      final response = await _dio.delete('/shops/$shopId/staff/$staffId');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      AppLogger.error('Error removing staff: $e');
      return false;
    }
  }
  
  Future<dynamic> updateStaffProfile(String staffId, Map<String, dynamic> data) async {
     try {
       final response = await _dio.put('/shops/staff/$staffId/profile', data: data);
       if (response.statusCode == 200) {
         return response.data;
       }
       return null;
     } catch (e) {
       AppLogger.error('Error updating staff profile: $e');
       return null;
     }
  }

  // Notifications
  Future<List<dynamic>> getNotifications(String userId) async {
    try {
      final response = await _dio.get('/notifications/$userId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    try {
      await _dio.put('/notifications/$notifId/read');
    } catch (e) {
      AppLogger.error('Error marking notification read: $e');
    }
  }

  // Shop Reviews
  Future<List<dynamic>> getShopReviews(String shopId) async {
    try {
      final response = await _dio.get('/reviews/shop/$shopId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching shop reviews: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getShopReviewStats(String shopId) async {
    try {
      final response = await _dio.get('/reviews/shop/$shopId/stats');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching shop review stats: $e');
      return null;
    }
  }

  // Staff Reviews
  Future<List<dynamic>> getStaffReviews(String staffId) async {
    try {
      final response = await _dio.get('/reviews/staff/$staffId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching staff reviews: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>?> getStaffReviewStats(String staffId) async {
    try {
      final response = await _dio.get('/reviews/staff/$staffId/stats');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff review stats: $e', e);
      return null;
    }
  }

  Future<bool> updateFCMToken(String userId, String token) async {
    try {
      final response = await _dio.post('/profile/$userId/fcm-token', data: {
        'fcm_token': token,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error updating FCM token: $e', e);
      return false;
    }
  }

  Future<List<Map<String, dynamic>>> getAuditTrail({
    required String ownerId,
    String? shopId,
    String? actionType,
  }) async {
    try {
      final response = await _dio.get(
        '/owner/audit-trail/$ownerId',
        queryParameters: {
          if (shopId != null) 'shop_id': shopId,
          if (actionType != null) 'action_type': actionType,
        },
      );
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching audit trail: $e', e);
      return [];
    }
  }

  Future<bool> overrideBooking(String bookingId, String ownerId, String reason, String newStatus) async {
    try {
      final response = await _dio.post('/bookings/$bookingId/override', queryParameters: {
        'owner_id': ownerId,
        'reason': reason,
        'new_status': newStatus,
      });
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error overriding booking: $e');
      return false;
    }
  }
}
