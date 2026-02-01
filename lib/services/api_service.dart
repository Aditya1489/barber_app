import 'dart:io';
import 'package:dio/dio.dart';
import 'package:barber_sync/models/models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiServiceProvider = Provider((ref) => ApiService());

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    baseUrl: Platform.isAndroid ? 'http://10.0.2.2:8000/api/v1' : 'http://192.168.0.114:8000/api/v1',
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));
  
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

  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error logging in: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> register(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/auth/register', data: data);
      if (response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error registering: $e');
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
      if (response.statusCode == 200) {
        return response.data['url'];
      }
      return null;
    } catch (e) {
      print('Error uploading file: $e');
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
      print('Error fetching shops: $e');
      return [];
    }
  }

  Future<List<dynamic>> getShopsByOwner(String ownerId) async {
    try {
      final response = await _dio.get('/shops/owned-by/$ownerId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Error fetching owner shops: $e');
      return [];
    }
  }

  Future<List<Appointment>> getAppointments({String? customerId, String? staffId, String? shopId}) async {
    try {
      final response = await _dio.get('/bookings/', queryParameters: {
        if (customerId != null) 'customer_id': customerId,
        if (staffId != null) 'staff_id': staffId,
        if (shopId != null) 'shop_id': shopId,
      });
      if (response.statusCode == 200) {
        final List data = response.data;
        return data.map((e) => Appointment.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching appointments: $e');
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
      print('Error updating booking status: $e');
      return false;
    }
  }

  Future<User?> updateProfile(String userId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.put('/profile/$userId', data: data);
      if (response.statusCode == 200) {
        return User.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print('Error updating profile: $e');
      return null;
    }
  }

  Future<String?> getNavigationLink(String shopId, {double? lat, double? lng}) async {
    try {
      final response = await _dio.get(
        '/shops/$shopId/navigation',
        queryParameters: {
          if (lat != null) 'customer_lat': lat,
          if (lng != null) 'customer_lng': lng,
        },
      );
      if (response.statusCode == 200) {
        return response.data['googleMapsUrl'];
      }
      return null;
    } catch (e) {
      print('Error fetching navigation link: $e');
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
      print('Error updating permissions: $e');
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
      print('Error fetching owner analytics: $e');
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
      print('Error fetching staff earnings: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> getStaffProfile(String staffId) async {
    try {
      final response = await _dio.get('/shops/staff/$staffId/profile');
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error fetching staff profile: $e');
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
      print('Error creating shop: $e');
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
      print('Error updating shop: $e');
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
      print('Error fetching shop services: $e');
      return [];
    }
  }

  Future<dynamic> addService(String shopId, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/shops/$shopId/services', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      print('Error adding service: $e');
      rethrow;
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
      print('Error updating service: $e');
      rethrow;
    }
  }

  Future<void> deleteService(String shopId, String serviceId) async {
    try {
      await _dio.delete('/shops/$shopId/services/$serviceId');
    } catch (e) {
      print('Error deleting service: $e');
      rethrow;
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
      print('Error fetching shop staff: $e');
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
      print('Error creating staff: $e');
      return null;
    }
  }

  Future<void> removeStaffFromShop(String shopId, String staffId) async {
    try {
      await _dio.delete('/shops/$shopId/staff/$staffId');
    } catch (e) {
      print('Error removing staff: $e');
      rethrow;
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
       print('Error updating staff profile: $e');
       rethrow;
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
      print('Error fetching notifications: $e');
      return [];
    }
  }

  Future<void> markNotificationAsRead(String notifId) async {
    try {
      await _dio.put('/notifications/$notifId/read');
    } catch (e) {
      print('Error marking notification read: $e');
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
      print('Error fetching staff reviews: $e');
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
      print('Error fetching staff review stats: $e');
      return null;
    }
  }
}
