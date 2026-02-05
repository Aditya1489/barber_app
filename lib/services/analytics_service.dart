import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/base_api_service.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Service for analytics operations.
final analyticsServiceProvider = Provider((ref) => AnalyticsService(ref.read(baseApiProvider)));

class AnalyticsService {
  final BaseApiService _api;
  
  AnalyticsService(this._api);

  /// Get owner analytics.
  Future<Map<String, dynamic>?> getOwnerAnalytics(String ownerId, {String? period, String? shopId}) async {
    try {
      final response = await _api.dio.get('/analytics/owner/$ownerId', queryParameters: {
        if (period != null) 'period': period,
        if (shopId != null) 'shop_id': shopId,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching owner analytics', e);
      return null;
    }
  }

  /// Get staff earnings.
  Future<Map<String, dynamic>?> getStaffEarnings(String staffId, {String? period}) async {
    try {
      final response = await _api.dio.get('/analytics/staff/$staffId', queryParameters: {
        if (period != null) 'period': period,
      });
      if (response.statusCode == 200) {
        return response.data;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error fetching staff earnings', e);
      return null;
    }
  }
}
