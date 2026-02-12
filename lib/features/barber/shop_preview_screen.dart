import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/widgets/user_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ShopPreviewScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const ShopPreviewScreen({super.key, required this.shopData});

  @override
  ConsumerState<ShopPreviewScreen> createState() => _ShopPreviewScreenState();
}

class _ShopPreviewScreenState extends ConsumerState<ShopPreviewScreen> {
  List<dynamic> _services = [];
  List<dynamic> _staff = [];
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _reviewStats;
  List<dynamic> _popularServices = [];
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  final PageController _photoPageController = PageController();
  int _currentPhotoIndex = 0;
  String? _activeSectionKey;



  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _activeSectionKey ??= 'about';
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final results = await Future.wait([
        apiService.getShopServices(widget.shopData['id']),
        apiService.getShopStaff(widget.shopData['id']),
        apiService.getShopReviews(widget.shopData['id']),
        apiService.getShopReviewStats(widget.shopData['id']),
        apiService.getPopularServices(widget.shopData['id']),
      ]);
      
      if (mounted) {
        setState(() {
          _services = results[0] as List;
          // Sort staff to put Owner first
          _staff = (results[1] as List)..sort((a, b) {
            bool aIsOwner = (a['role']?.toString().toLowerCase().contains('owner') ?? false);
            bool bIsOwner = (b['role']?.toString().toLowerCase().contains('owner') ?? false);
            if (aIsOwner && !bIsOwner) return -1;
            if (!aIsOwner && bIsOwner) return 1;
            return 0;
          });
          _reviews = results[2] as List;
          _reviewStats = results[3] as Map<String, dynamic>?;
          _popularServices = results[4] as List;
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
    final photos = (widget.shopData['photos'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF9FAFB),
      body: _isLoading && _staff.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                slivers: [
                  _buildSliverAppBar(isDark, photos),
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildNavigationChips(isDark),
                        _buildShopContent(isDark),
                      ],
                    ),
                  ),
                ],
              ),
              _buildStickyBookNow(isDark),
            ],
          ),
    );
  }

  Widget _buildSliverAppBar(bool isDark, List<String> photos) {
    return SliverAppBar(
      expandedHeight: 320,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.3),
          child: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            photos.isNotEmpty 
                ? _buildPhotoGallery(photos)
                : Image.network(
                    "https://images.unsplash.com/photo-1503951914875-452162b0f3f1?auto=format&fit=crop&q=80&w=800",
                    fit: BoxFit.cover,
                  ),
            // Dark Gradient Overlay
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      (isDark ? const Color(0xFF0C0C0E) : Colors.black).withOpacity(0.8),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.4],
                  ),
                ),
              ),
            ),
            // Identity Line & Badges Overlay
            Positioned(
              bottom: 12,
              left: 20,
              right: 20,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badges Row
                    Builder(
                      builder: (context) {
                        final status = _getShopStatus();
                        return Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: status['color'],
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(LucideIcons.clock, size: 10, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    status['label'], 
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5)
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: const Text('~15 MIN WAIT', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            ),
                          ],
                        );
                      }
                    ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                    
                    const SizedBox(height: 8),
                    
                    // Shop Name with Shadow
                    Text(
                      widget.shopData['name'],
                      style: TextStyle(
                        fontSize: 36, 
                        fontWeight: FontWeight.w900, 
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 2)),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                    
                    const SizedBox(height: 8),
                    
                    // Tagline
                    Row(
                      children: [
                        Icon(LucideIcons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          'Premium Grooming Experience',
                          style: TextStyle(
                            fontSize: 14, 
                            color: Colors.white.withOpacity(0.9), 
                            fontWeight: FontWeight.w600,
                            shadows: [
                              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationChips(bool isDark) {
    final Map<String, String> sectionMap = {
      'about': 'About',
      'team': 'Team',
      'services': 'Services',
      'reviews': 'Reviews',
    };
    final sectionKeys = sectionMap.keys.toList();
    return Container(
      color: isDark ? const Color(0xFF0C0C0E) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: sectionKeys.map((key) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(sectionMap[key]!),
              selected: _activeSectionKey == key,
              onSelected: (val) { if(val) setState(() => _activeSectionKey = key); },
              backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
              selectedColor: AppTheme.emerald,
              labelStyle: TextStyle(
                color: _activeSectionKey == key ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                fontWeight: FontWeight.bold,
                fontSize: 12
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide.none,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildShopContent(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Content switched by tabs
          if (_activeSectionKey == 'about') ...[
             const SizedBox(height: 8),
             _sectionTitle('The Experience'),
             const SizedBox(height: 12),
             Text(
               widget.shopData['description'] ?? 'Experience top-tier grooming services tailored to your style.',
               style: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6), height: 1.6),
             ),
             const SizedBox(height: 32),
             _buildTrustBanner(isDark),
          ] else if (_activeSectionKey == 'team') ...[
             const SizedBox(height: 8),
             _sectionTitle('Meet The Team'),
             const SizedBox(height: 16),
             _buildStaffGrid(isDark), // Consider modifying to vertical grid if needed for 'Full View'
          ] else if (_activeSectionKey == 'services') ...[
             const SizedBox(height: 8),
             _sectionTitle('Our Services'),
             const SizedBox(height: 16),
             _buildServicesGrouped(isDark),
          ] else if (_activeSectionKey == 'reviews') ...[
             const SizedBox(height: 8),
             _sectionTitle('Client Reviews'),
             const SizedBox(height: 16),
             _buildReviewsSection(isDark),
          ],
          
          const SizedBox(height: 120), // Bottom padding for CTA
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Colors.grey),
    );
  }

  Widget _buildStaffGrid(bool isDark) {
    if (_staff.isEmpty) return const Text('No staff found');

    return SizedBox(
      height: 140,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _staff.length,
        itemBuilder: (context, index) {
          final member = _staff[index];
          bool isOwner = member['role']?.toString().toLowerCase().contains('owner') ?? false;

          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 16),
            child: InkWell(
              onTap: () => context.push('/staff-preview', extra: member),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      UserAvatar(
                        radius: 38,
                        photoUrl: member['profilePhoto'] ?? member['imageUrl'] ?? member['photo'],
                        name: member['name'],
                      ),
                      if (isOwner)
                        Positioned(
                          top: 0, right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.crown, color: Colors.white, size: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    member['name'].split(' ').first,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    maxLines: 1,
                  ),
                  Text(
                    isOwner ? 'Owner & Master Barber' : (member['role'] ?? 'Staff Member'),
                    style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 100 * index)).scale(begin: const Offset(0.9, 0.9));
        },
      ),
    );
  }


  Widget _buildReviewsSection(bool isDark) {
    if (_reviews.isEmpty) {
      return Center(
        child: Column(
          children: [
            Icon(LucideIcons.messageSquare, size: 48, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
            const SizedBox(height: 16),
            Text("No reviews yet", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.5))),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Summary Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (_reviewStats?['averageRating'] ?? 0.0).toString(),
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      final rating = (_reviewStats?['averageRating'] ?? 0.0);
                      return Icon(
                        index < rating.round() ? LucideIcons.star : LucideIcons.star,
                        size: 16,
                        color: index < rating.round() ? Colors.amber : Colors.grey.withOpacity(0.3),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text("${_reviews.length} Verified Reviews", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        // Review List
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _reviews.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            final review = _reviews[index];
            final rating = review['rating'] as int;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      UserAvatar(
                        name: review['customerName'] ?? "Anonymous",
                        radius: 16,
                        photoUrl: null, // Photos if available
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(review['customerName'] ?? "Client", style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text("Verified Client", style: TextStyle(fontSize: 9, color: AppTheme.emerald.withOpacity(0.8))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.star, size: 10, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(rating.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.amber)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (review['comment'] != null && review['comment'].isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(review['comment'], style: TextStyle(fontSize: 13, height: 1.5, color: (isDark ? Colors.white : Colors.black).withOpacity(0.8))),
                  ]
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrustBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.emerald.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.emerald.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _trustIcon(LucideIcons.heart, 'Loved by Clients'),
          _trustIcon(LucideIcons.shieldCheck, 'Clean & Hygienic'),
          _trustIcon(LucideIcons.medal, 'Certified Masters'),
        ],
      ),
    );
  }

  Widget _trustIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, size: 18, color: AppTheme.emerald),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildServicesGrouped(bool isDark) {
    if (_services.isEmpty) return const Text('No services available');

    // Use popular services if available, otherwise fall back to first 2
    final popularPicks = _popularServices.isNotEmpty 
        ? _popularServices.take(2).toList() 
        : _services.take(2).toList();
    
    // Get IDs of popular picks to exclude from main menu
    final popularIds = popularPicks.map((s) => s['id']).toSet();
    final mainMenu = _services.where((s) => !popularIds.contains(s['id'])).toList();

    return Column(
      children: [
        _serviceCategory(isDark, 'Popular Picks', popularPicks, isHot: true),
        if (mainMenu.isNotEmpty) ...[
          const SizedBox(height: 24),
          _serviceCategory(isDark, 'Main Menu', mainMenu),
        ],
      ],
    );
  }

  Widget _serviceCategory(bool isDark, String title, List<dynamic> items, {bool isHot = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (isHot) ...[
              const SizedBox(width: 8),
              const Icon(LucideIcons.flame, color: Colors.orange, size: 14),
            ]
          ],
        ),
        const SizedBox(height: 12),
        ...items.map((s) => _serviceCard(isDark, s, isHot)),
      ],
    );
  }

  Widget _serviceCard(bool isDark, dynamic service, bool highlight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (highlight) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: const Text('TOP', style: TextStyle(color: AppTheme.emerald, fontSize: 8, fontWeight: FontWeight.bold)),
                      ),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  service['description'] ?? 'Professional ${service['name']} service',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(LucideIcons.clock, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text("${service['duration']} mins", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Service Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey.withOpacity(0.1),
            ),
            child: service['imageUrl'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      ref.read(apiServiceProvider).resolveUrl(service['imageUrl']) ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          child: const Icon(LucideIcons.scissors, color: Colors.grey, size: 24),
                        );
                      },
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.all(12),
                    child: const Icon(LucideIcons.scissors, color: Colors.grey, size: 24),
                  ),
          ),
          const SizedBox(width: 12),
          Text(
            "\$${service['price']}",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.emerald),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }

  Widget _buildStickyBookNow(bool isDark) {
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (isDark ? const Color(0xFF0C0C0E) : Colors.white).withOpacity(0.95),
          border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {}, // CTA placeholder
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: const Text(
                'BOOK APPOINTMENT',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(List<String> photos) {
     final apiService = ref.read(apiServiceProvider);
     return Stack(
       children: [
         PageView.builder(
           controller: _photoPageController,
           itemCount: photos.length,
           onPageChanged: (i) => setState(() => _currentPhotoIndex = i),
           itemBuilder: (context, index) {
             final photo = photos[index];
             final resolved = apiService.resolveUrl(photo);
             if (resolved == null) return const Center(child: Icon(LucideIcons.imageOff));
             
             return resolved.startsWith('http') 
                ? Image.network(resolved, fit: BoxFit.cover)
                : Image.file(File(resolved), fit: BoxFit.cover);
           },
         ),
         if (photos.length > 1)
           Positioned(
             top: 48, // Safe area padding
             right: 20,
             child: Container(
               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
               decoration: BoxDecoration(
                 color: Colors.black.withOpacity(0.5),
                 borderRadius: BorderRadius.circular(20),
               ),
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   const Icon(LucideIcons.image, color: Colors.white, size: 12),
                   const SizedBox(width: 6),
                   Text(
                     "${_currentPhotoIndex + 1}/${photos.length}",
                     style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                   ),
                 ],
               ),
             ),
           ),
       ],
     );
  }
  Map<String, dynamic> _getShopStatus() {
    try {
      // 1. Check for manual override (from staff/owner toggle)
      if (widget.shopData.containsKey('isAvailable')) {
        final isAvailableVal = widget.shopData['isAvailable'];
        debugPrint("ShopPreview: isAvailable key found. Value: $isAvailableVal (${isAvailableVal.runtimeType})");
        
        bool? isAvailable;
        if (isAvailableVal is bool) isAvailable = isAvailableVal;
        if (isAvailableVal is String) isAvailable = isAvailableVal.toLowerCase() == 'true';
        if (isAvailableVal is int) isAvailable = isAvailableVal == 1;

        if (isAvailable == false) {
           return {'isOpen': false, 'label': 'CLOSED (OFFLINE)', 'color': Colors.redAccent}; // Explicit label
        } else if (isAvailable == true) {
           return {'isOpen': true, 'label': 'OPEN NOW', 'color': AppTheme.emerald};
        }
      } else {
        debugPrint("ShopPreview: isAvailable key MISSING in shopData. Keys: ${widget.shopData.keys.toList()}");
      }

      // 2. Fallback to Operating Hours Logic
      final hours = widget.shopData['hours'];
      if (hours == null || hours is! Map || hours.isEmpty) {
        // Default to Open if no hours set (common for new implementations)
        return {'isOpen': true, 'label': 'OPEN NOW', 'color': AppTheme.emerald}; 
      }

      final now = DateTime.now();
      final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final today = dayNames[now.weekday - 1];

      if (!hours.containsKey(today)) {
         return {'isOpen': false, 'label': 'CLOSED', 'color': Colors.grey};
      }

      final todayHours = hours[today];
      if (todayHours == null || todayHours is! Map || !todayHours.containsKey('start') || !todayHours.containsKey('end')) {
         return {'isOpen': false, 'label': 'CLOSED', 'color': Colors.grey};
      }

      final startParts = todayHours['start'].toString().split(':');
      final endParts = todayHours['end'].toString().split(':');
      
      final nowMinutes = now.hour * 60 + now.minute;
      final startMinutes = int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      if (nowMinutes >= startMinutes && nowMinutes < endMinutes) {
         return {'isOpen': true, 'label': 'OPEN NOW', 'color': AppTheme.emerald};
      } else {
         return {'isOpen': false, 'label': 'CLOSED', 'color': Colors.redAccent};
      }
    } catch (e) {
      debugPrint('Error parsing shop status: $e');
      return {'isOpen': true, 'label': 'OPEN NOW', 'color': AppTheme.emerald}; // Fallback
    }
  }
}
