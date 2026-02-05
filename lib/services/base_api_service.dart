import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/core/config/app_config.dart';
import 'package:barber_sync/core/utils/logger.dart';

/// Base API client that handles HTTP configuration and common utilities.
/// Other services extend this or use the shared Dio instance.
final baseApiProvider = Provider((ref) => BaseApiService());

class BaseApiService {
  final Dio dio = Dio(BaseOptions(
    baseUrl: Platform.isAndroid 
        ? AppConfig.getBaseUrl() 
        : AppConfig.getIosBaseUrl(),
    connectTimeout: Duration(seconds: AppConfig.connectTimeoutSeconds),
    receiveTimeout: Duration(seconds: AppConfig.receiveTimeoutSeconds),
  ));
  
  String get baseUrl => dio.options.baseUrl.replaceAll('/api/v1', '');

  /// Resolves relative URLs to full server URLs.
  String? resolveUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http')) return path;
    if (path.startsWith('assets/')) return null;
    
    // Don't resolve absolute local paths
    if (path.startsWith('/data/') || path.startsWith('/Users/') || path.startsWith('/var/')) {
      return path; 
    }
    
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return '$baseUrl$cleanPath';
  }

  /// Uploads a file and returns the URL.
  Future<String?> uploadFile(File file) async {
    try {
      String fileName = file.path.split('/').last;
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });
      final response = await dio.post('/uploads', data: formData);
      if (response.statusCode == 200 && response.data != null) {
        return response.data['url'] as String?;
      }
      return null;
    } catch (e) {
      AppLogger.error('Error uploading file', e);
      return null;
    }
  }
}
