import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'dart:io';

class UserAvatar extends ConsumerWidget {
  final String? photoUrl;
  final String name;
  final double radius;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.radius = 30,
    this.fontSize,
  });

  String _getInitials(String name) {
    if (name.isEmpty) return "U";
    final parts = name.trim().split(" ");
    if (parts.length > 1) {
      return "${parts[0][0]}${parts[1][0]}".toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiService = ref.read(apiServiceProvider);
    final resolvedUrl = apiService.resolveUrl(photoUrl);

    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildInitialsAvatar();
    }

    return _buildImageAvatar(resolvedUrl);
  }

  Widget _buildInitialsAvatar() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.emerald,
            AppTheme.emerald.withOpacity(0.6),
          ],
        ),
      ),
      child: Center(
        child: Text(
          _getInitials(name),
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize ?? (radius * 0.8),
          ),
        ),
      ),
    );
  }

  Widget _buildImageAvatar(String url) {
    ImageProvider imageProvider;
    if (url.startsWith('http')) {
      imageProvider = NetworkImage(url);
    } else {
      imageProvider = FileImage(File(url));
    }

    return CircleAvatar(
      radius: radius,
      backgroundImage: imageProvider,
      backgroundColor: Colors.transparent,
      onBackgroundImageError: (exception, stackTrace) => _buildInitialsAvatar(),
    );
  }
}
