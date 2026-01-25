import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';

class StaffPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> staffData;

  const StaffPreviewScreen({super.key, required this.staffData});

  @override
  ConsumerState<StaffPreviewScreen> createState() => _StaffPreviewScreenState();
}

class _StaffPreviewScreenState extends ConsumerState<StaffPreviewScreen> {
  Map<String, dynamic>? _fullProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final profile = await apiService.getStaffProfile(widget.staffData['id']);
      if (mounted) {
        setState(() {
          _fullProfile = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final data = _fullProfile ?? widget.staffData;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                CircleAvatar(
                  radius: 60,
                  backgroundImage: _getProfileImageProvider(data['photo'] ?? data['imageUrl']),
                ),
                const SizedBox(height: 16),
                Text(
                  data['name'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                ),
                Text(
                  data['role']?.toUpperCase() ?? "BARBER",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.emerald, letterSpacing: 1.5),
                ),
                const SizedBox(height: 24),
                _buildStats(isDark, data),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBG : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                       const SizedBox(height: 12),
                       Text(
                         data['description'] ?? "No description available.",
                         style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.7), height: 1.6),
                       ),
                       const SizedBox(height: 24),
                       Text("Work Portfolio", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                       const SizedBox(height: 12),
                       _buildPortfolio(data['workPhotos'] as List?)
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStats(bool isDark, Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildStatItem(isDark, "${data['experience'] ?? 0} Years", "Experience"),
        Container(width: 1, height: 40, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 24)),
        _buildStatItem(isDark, "${data['rating'] ?? 0.0}", "Rating"),
        Container(width: 1, height: 40, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), margin: const EdgeInsets.symmetric(horizontal: 24)),
        _buildStatItem(isDark, "${data['reviewsCount'] ?? 0}", "Reviews"),
      ],
    );
  }

  Widget _buildStatItem(bool isDark, String value, String label) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        Text(label, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
      ],
    );
  }

  Widget _buildPortfolio(List? photos) {
    if (photos == null || photos.isEmpty) return const Text("No portfolio photos.");

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index].toString();
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: photo.startsWith('http')
              ? Image.network(photo, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error))
              : Image.file(File(photo), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.error)),
        );
      },
    );
  }
  ImageProvider _getProfileImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const NetworkImage("https://picsum.photos/200");
    }
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }
}
