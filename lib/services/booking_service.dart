import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/base_api_service.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Service for booking/appointment operations.
final bookingServiceProvider = Provider((ref) => BookingService(ref.read(baseApiProvider)));

class BookingService {
  final BaseApiService _api;
  
  BookingService(this._api);

  /// Get appointments with optional filters.
  Future<List<Appointment>> getAppointments({
    String? customerId,
    String? staffId,
    String? shopId,
    int? limit,
  }) async {
    try {
      final response = await _api.dio.get('/bookings/', queryParameters: {
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
      AppLogger.error('Error fetching appointments', e);
      return [];
    }
  }

  /// Update booking status.
  Future<bool> updateBookingStatus(String bookingId, String status) async {
    try {
      final response = await _api.dio.patch('/bookings/$bookingId', data: {'status': status});
      return response.statusCode == 200;
    } catch (e) {
      AppLogger.error('Error updating booking status', e);
      return false;
    }
  }
}
