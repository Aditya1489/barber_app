import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';

class ShopPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const ShopPreviewScreen({super.key, required this.shopData});

  @override
  ConsumerState<ShopPreviewScreen> createState() => _ShopPreviewScreenState();
}

class _ShopPreviewScreenState extends ConsumerState<ShopPreviewScreen> {
  List<dynamic> _services = [];
  List<dynamic> _staff = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final results = await Future.wait([
        apiService.getShopServices(widget.shopData['id']),
        apiService.getShopStaff(widget.shopData['id']),
      ]);
      
      if (mounted) {
        setState(() {
          _services = results[0];
          _staff = results[1];
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
    final theme = isDark ? AppTheme.getDarkTheme() : AppTheme.getLightTheme();
    final photos = (widget.shopData['photos'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF18181B) : const Color(0xFFF5F5F7),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF18181B) : Colors.white,
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: photos.isNotEmpty 
                  ? _buildPhotoGallery(photos)
                  : Image.network(
                      "https://picsum.photos/800/600",
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.shopData['name'],
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 16),
                            SizedBox(width: 4),
                            Text("New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 16, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                      const SizedBox(width: 4),
                      Text(
                        widget.shopData['address'],
                        style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (widget.shopData['description'] != null) ...[
                     Text("About", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                     const SizedBox(height: 8),
                     Text(
                       widget.shopData['description'],
                       style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.7), height: 1.5),
                     ),
                     const SizedBox(height: 24),
                  ],
                  Text("Meet the Team", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 12),
                  _buildStaffList(isDark),
                  const SizedBox(height: 24),
                  Text("Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 12),
                  _buildServicesList(isDark),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos) {
     return PageView.builder(
       itemCount: photos.length,
       itemBuilder: (context, index) {
         final photo = photos[index];
         return photo.startsWith('http') 
            ? Image.network(photo, fit: BoxFit.cover)
            : Image.file(File(photo), fit: BoxFit.cover);
       },
     );
  }

  Widget _buildStaffList(bool isDark) {
    if (_staff.isEmpty) return const Text("No staff added yet.");

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _staff.length,
        itemBuilder: (context, index) {
          final member = _staff[index];
          return InkWell(
            onTap: () => context.push('/staff-preview', extra: member),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 35,
                    backgroundImage: _getImageProvider(member['imageUrl']),
                  ),
                  const SizedBox(height: 8),
                  Text(member['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(member['role'] ?? "Staff", style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildServicesList(bool isDark) {
    if (_services.isEmpty) return const Text("No services available.");

    return Column(
      children: _services.map((service) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
             Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 Text("${service['duration']} mins", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
               ],
             ),
             Text("\$${service['price']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.emerald)),
          ],
        ),
      )).toList(),
    );
  }
  ImageProvider _getImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const NetworkImage("https://picsum.photos/200");
    }
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }
}
