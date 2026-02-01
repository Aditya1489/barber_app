import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/widgets/user_avatar.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
      final profile = await apiService.getStaffProfile(widget.staffData['id'] ?? widget.staffData['staffId']);
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
    final isOnline = true; // Mock availability

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0C0E) : const Color(0xFFF8F9FA), // Softer blacks
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
            child: IconButton(
              icon: Icon(LucideIcons.arrowLeft, size: 18, color: isDark ? Colors.white : Colors.black),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ),
      body: _isLoading && _fullProfile == null
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            physics: const ClampingScrollPhysics(),
            children: [
                const SizedBox(height: 10),
                _buildProfileHero(isDark, data, isOnline),
                const SizedBox(height: 24),
                _buildStats(isDark, data),
                const SizedBox(height: 24),
                _buildAboutSection(isDark, data),
                const SizedBox(height: 32),
                _buildPortfolioSection(isDark, data),
                const SizedBox(height: 24),
                _buildSoftCTA(isDark, data),
            ],
          ),
    );
  }

  Widget _buildProfileHero(bool isDark, Map<String, dynamic> data, bool isOnline) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Availability Glow
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? AppTheme.emerald : Colors.grey).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ],
                  border: Border.all(color: (isOnline ? AppTheme.emerald : Colors.grey).withOpacity(0.3), width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: UserAvatar(
                    radius: 60,
                    photoUrl: data['profilePhoto'] ?? data['photo'] ?? data['imageUrl'],
                    name: data['name'],
                    fontSize: 40,
                  ),
                ),
              ),
              // Verification Badge
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  child: const Icon(LucideIcons.check, color: Colors.white, size: 14),
                ).animate().scale(delay: 400.ms, curve: Curves.elasticOut),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            data['name'],
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black),
          ),
          const SizedBox(height: 6),
          // Role
          Text(
            data['role']?.toUpperCase() ?? "BARBER",
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          // Experience badge
          if (_getExperienceBadgeInfo(data['experience'] ?? 0) != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: (_getExperienceBadgeInfo(data['experience'] ?? 0)!['color'] as Color).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: (_getExperienceBadgeInfo(data['experience'] ?? 0)!['color'] as Color).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    data['experience'] >= 10 ? LucideIcons.crown : (data['experience'] >= 5 ? LucideIcons.medal : LucideIcons.scissors),
                    size: 14,
                    color: _getExperienceBadgeInfo(data['experience'] ?? 0)!['color'] as Color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getExperienceBadgeInfo(data['experience'] ?? 0)!['label'] as String,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getExperienceBadgeInfo(data['experience'] ?? 0)!['color'] as Color),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn();
  }

  List<Map<String, dynamic>> _getAchievementBadges(Map<String, dynamic> data) {
    final experience = data['experience'] ?? 0;
    
    List<Map<String, dynamic>> badges = [];
    
    // Experience badges only
    if (experience >= 10) {
      badges.add({'icon': LucideIcons.crown, 'label': 'Master Barber', 'color': Colors.purple});
    } else if (experience >= 5) {
      badges.add({'icon': LucideIcons.medal, 'label': 'Experienced Pro', 'color': Colors.blue});
    } else if (experience >= 2) {
      badges.add({'icon': LucideIcons.scissors, 'label': 'Skilled Stylist', 'color': Colors.teal});
    }
    
    return badges;
  }

  Widget _buildTrustIndicators(bool isDark) {
    final data = _fullProfile ?? widget.staffData;
    final badges = _getAchievementBadges(data);
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Badges only (review option is in stats row beside NEW Badge)
          ...badges.asMap().entries.map((entry) {
            final badge = entry.value;
            return Padding(
              padding: EdgeInsets.only(right: entry.key < badges.length - 1 ? 12 : 0),
              child: _trustBadge(isDark, badge['icon'], badge['label'], badge['color']),
            );
          }).toList(),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _trustBadge(bool isDark, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Map<String, dynamic>? _getExperienceBadgeInfo(int experience) {
    if (experience >= 10) {
      return {'label': 'Master Barber', 'color': Colors.purple};
    } else if (experience >= 5) {
      return {'label': 'Experienced Pro', 'color': Colors.blue};
    } else if (experience >= 2) {
      return {'label': 'Skilled Stylist', 'color': Colors.teal};
    }
    return null;
  }

  Widget _buildStats(bool isDark, Map<String, dynamic> data) {
    final rating = (data['rating'] ?? 0.0) is int ? (data['rating'] as int).toDouble() : (data['rating'] ?? 0.0) as double;
    final reviews = (data['reviewsCount'] ?? 0) as int;
    final experience = data['experience'] ?? 0;
    final staffId = data['id'] ?? data['staffId'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Experience
            Expanded(
              child: _buildStatColumn(
                isDark,
                "$experience",
                "Years",
                LucideIcons.briefcase,
                Colors.blue,
              ),
            ),
            Container(width: 1, height: 40, color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
            // Rating
            Expanded(
              child: _buildStatColumn(
                isDark,
                rating.toStringAsFixed(1),
                "Rating",
                LucideIcons.star,
                rating > 0 ? Colors.amber : Colors.grey,
              ),
            ),
            Container(width: 1, height: 40, color: (isDark ? Colors.white : Colors.black).withOpacity(0.08)),
            // Reviews (tappable)
            Expanded(
              child: GestureDetector(
                onTap: staffId != null ? () => context.push('/staff-reviews', extra: staffId) : null,
                child: _buildStatColumn(
                  isDark,
                  "$reviews",
                  "Reviews",
                  LucideIcons.messageSquare,
                  reviews > 0 ? Colors.purple : Colors.grey,
                  showArrow: true,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildStatColumn(bool isDark, String value, String label, IconData icon, Color color, {bool showArrow = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
            if (showArrow) ...[
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 14, color: color.withOpacity(0.6)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildStatItemWithIcon(bool isDark, String value, String label, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black)),
          ],
        ),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(width: 1, height: 30, color: (isDark ? Colors.white : Colors.black).withOpacity(0.05));
  }

  Widget _buildStatItem(bool isDark, String value, String label, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color ?? (isDark ? Colors.white : Colors.black))),
        const SizedBox(height: 4),
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildAboutSection(bool isDark, Map<String, dynamic> data) {
    final aboutText = data['description'] ?? "";

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text("About".toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
           const SizedBox(height: 16),
           Text(
             aboutText.isEmpty ? "No description provided yet. This barber is known for professional service and precision cuts." : aboutText,
             style: TextStyle(
               color: (isDark ? Colors.white : Colors.black).withOpacity(0.8), 
               height: 1.8,
               fontSize: 15,
             ),
           ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildPortfolioSection(bool isDark, Map<String, dynamic> data) {
    final photos = data['workPhotos'] as List? ?? [];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Work Portfolio".toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
              if (photos.isNotEmpty) Text("${photos.length} Photos", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (photos.isEmpty)
           const Padding(
             padding: EdgeInsets.symmetric(horizontal: 24),
             child: Text("No portfolio photos yet.", style: TextStyle(color: Colors.grey, fontSize: 13)),
           )
        else
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: photos.length,
              separatorBuilder: (c, i) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final photo = photos[index].toString();
                final resolved = ref.read(apiServiceProvider).resolveUrl(photo);
                if (resolved == null) return const SizedBox();

                // Mocking pinning and tagging for preview
                bool isPinned = index == 0; 

                return Container(
                  width: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: isPinned ? Border.all(color: AppTheme.emerald, width: 2) : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      resolved.startsWith('http')
                          ? Image.network(resolved, fit: BoxFit.cover)
                          : Image.file(File(resolved), fit: BoxFit.cover),
                      // Service Tag
                      Positioned(
                        bottom: 12, left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            (data['skills'] as List?)?.take(2).join(' · ') ?? 'Portfolio',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      if (isPinned)
                        Positioned(
                          top: 12, left: 12,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppTheme.emerald, shape: BoxShape.circle),
                            child: const Icon(LucideIcons.star, color: Colors.white, size: 12),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildReviewsSection(bool isDark, Map<String, dynamic> data) {
    final rating = (data['rating'] ?? 0.0) is int ? (data['rating'] as int).toDouble() : (data['rating'] ?? 0.0) as double;
    final reviews = (data['reviewsCount'] ?? 0) as int;
    final staffId = data['id'] ?? data['staffId'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Customer Reviews".toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 2)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (staffId != null) {
                context.push('/staff-reviews', extra: staffId);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBG : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  // Rating circle
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : "NEW",
                          style: TextStyle(
                            fontSize: rating > 0 ? 18 : 12,
                            fontWeight: FontWeight.w900,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        if (rating > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(5, (i) => Icon(
                              i < rating.round() ? LucideIcons.star : LucideIcons.star,
                              size: 8,
                              color: i < rating.round() ? Colors.amber : Colors.grey.withOpacity(0.3),
                            )),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Review info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reviews > 0 ? "$reviews Reviews" : "No reviews yet",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          reviews > 0 ? "Tap to read what customers say" : "Be the first to leave a review!",
                          style: TextStyle(
                            fontSize: 12,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.chevronRight, size: 18, color: Colors.amber.shade700),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 450.ms);
  }

  Widget _buildSoftCTA(bool isDark, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
           Container(
             padding: const EdgeInsets.all(16),
             decoration: BoxDecoration(
               color: AppTheme.emerald.withOpacity(0.05),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(color: AppTheme.emerald.withOpacity(0.1)),
             ),
             child: Row(
               children: [
                 const Icon(LucideIcons.calendar, color: AppTheme.emerald, size: 20),
                 const SizedBox(width: 16),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: const [
                       Text("Available Today", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.emerald)),
                       Text("Responds in minutes", style: TextStyle(fontSize: 11, color: Colors.grey)),
                     ],
                   ),
                 ),
               ],
             ),
           ),
           const SizedBox(height: 24),
           SizedBox(
             width: double.infinity,
             height: 60,
             child: ElevatedButton(
               onPressed: null, // Disabled in preview
               style: ElevatedButton.styleFrom(
                 backgroundColor: AppTheme.emerald,
                 disabledBackgroundColor: AppTheme.emerald.withOpacity(0.3),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
               ),
               child: const Text("BOOK APPOINTMENT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)),
             ),
           ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }
}
