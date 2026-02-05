import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/base_api_service.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Service for shop-related operations.
final shopServiceProvider = Provider((ref) => ShopService(ref.read(baseApiProvider)));

class ShopService {
  final BaseApiService _api;
  
  ShopService(this._api);

  /// Get all shops with optional location filter.
  Future<List<BarberShop>> getShops({double? lat, double? lng, double? radius}) async {
    try {
      final response = await _api.dio.get('/shops', queryParameters: {
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

  /// Get shops owned by a specific user.
  Future<List<dynamic>> getShopsByOwner(String ownerId) async {
    if (ownerId.isEmpty) {
      AppLogger.error('getShopsByOwner called with empty ownerId');
      return [];
    }
    try {
      final response = await _api.dio.get('/shops/owned-by/$ownerId');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching owner shops: $e');
      return [];
    }
  }

  /// Create a new shop.
  Future<Map<String, dynamic>?> createShop(Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.post('/shops', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating shop', e);
      return null;
    }
  }

  /// Update an existing shop.
  Future<Map<String, dynamic>?> updateShop(String shopId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.patch('/shops/$shopId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating shop', e);
      return null;
    }
  }

  /// Get services for a shop.
  Future<List<dynamic>> getShopServices(String shopId) async {
    try {
      final response = await _api.dio.get('/shops/$shopId/services');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching services', e);
      return [];
    }
  }

  /// Add a service to a shop.
  Future<Map<String, dynamic>?> addService(String shopId, Map<String, dynamic> data) async {
    try {
      data['shopId'] = shopId;
      final response = await _api.dio.post('/shops/$shopId/services', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error adding service', e);
      return null;
    }
  }

  /// Update a service.
  Future<Map<String, dynamic>?> updateService(String shopId, String serviceId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.patch('/shops/$shopId/services/$serviceId', data: data);
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error updating service', e);
      return null;
    }
  }

  /// Delete a service.
  Future<bool> deleteService(String shopId, String serviceId) async {
    try {
      final response = await _api.dio.delete('/shops/$shopId/services/$serviceId');
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error deleting service', e);
      return false;
    }
  }

  /// Get staff for a shop.
  Future<List<dynamic>> getShopStaff(String shopId) async {
    try {
      final response = await _api.dio.get('/shops/$shopId/staff');
      if (response.statusCode == 200) {
        return response.data as List<dynamic>;
      }
      return [];
    } catch (e) {
      AppLogger.error('Error fetching staff', e);
      return [];
    }
  }

  /// Create staff for a shop.
  Future<Map<String, dynamic>?> createStaffForShop(String shopId, Map<String, dynamic> data) async {
    try {
      final response = await _api.dio.post('/shops/$shopId/staff', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error creating staff', e);
      return null;
    }
  }

  /// Remove staff from a shop.
  Future<bool> removeStaffFromShop(String shopId, String staffId) async {
    try {
      final response = await _api.dio.delete('/shops/$shopId/staff/$staffId');
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error removing staff', e);
      return false;
    }
  }

  /// Get navigation link for a shop.
  String? getNavigationLink(String shopId, {double? lat, double? lng}) {
    // This is typically handled client-side
    return null;
  }
}
