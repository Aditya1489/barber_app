import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barber_sync/services/api_service.dart';

class StaffReviewsScreen extends ConsumerStatefulWidget {
  final String staffId;
  
  const StaffReviewsScreen({super.key, required this.staffId});

  @override
  ConsumerState<StaffReviewsScreen> createState() => _StaffReviewsScreenState();
}

class _StaffReviewsScreenState extends ConsumerState<StaffReviewsScreen> {
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    final api = ref.read(apiServiceProvider);
    final reviews = await api.getStaffReviews(widget.staffId);
    final stats = await api.getStaffReviewStats(widget.staffId);
    
    if (mounted) {
      setState(() {
        _reviews = reviews;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A0A) : Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Reviews'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReviews,
              color: isDark ? const Color(0xFF10B981) : Colors.blue,
              child: CustomScrollView(
                slivers: [
                  // Stats Header
                  SliverToBoxAdapter(
                    child: _buildStatsHeader(isDark),
                  ),
                  
                  // Reviews List
                  if (_reviews.isEmpty)
                    SliverFillRemaining(
                      child: _buildEmptyState(isDark),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildReviewCard(_reviews[index], isDark)
                              .animate(delay: Duration(milliseconds: index * 50))
                              .fadeIn()
                              .slideX(begin: 0.1),
                          childCount: _reviews.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsHeader(bool isDark) {
    final avgRating = _stats?['averageRating'] ?? 0.0;
    final totalReviews = _stats?['totalReviews'] ?? 0;
    final distribution = _stats?['ratingDistribution'] as Map<String, dynamic>? ?? {};
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
              : [Colors.amber.shade100, Colors.orange.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Average Rating
          Column(
            children: [
              Text(
                avgRating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.amber : Colors.amber.shade800,
                ),
              ),
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < avgRating.round() ? LucideIcons.star : LucideIcons.star,
                    size: 16,
                    color: i < avgRating.round() 
                        ? Colors.amber 
                        : (isDark ? Colors.grey[600] : Colors.grey[400]),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '$totalReviews reviews',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(width: 24),
          
          // Distribution Chart
          Expanded(
            child: Column(
              children: [5, 4, 3, 2, 1].map((star) {
                final count = distribution['$star'] ?? 0;
                final percent = totalReviews > 0 ? count / totalReviews : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Text(
                        '$star',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(LucideIcons.star, size: 10, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percent,
                            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation(Colors.amber),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildReviewCard(dynamic review, bool isDark) {
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final customerName = review['customerName'] ?? 'Anonymous';
    final comment = review['comment'] ?? '';
    final createdAt = review['createdAt'] ?? '';
    
    // Parse date
    String formattedDate = '';
    try {
      final date = DateTime.parse(createdAt);
      formattedDate = '${date.day}/${date.month}/${date.year}';
    } catch (_) {}
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.amber.withOpacity(0.2),
                child: Text(
                  customerName.isNotEmpty ? customerName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customerName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              // Star Rating
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating ? LucideIcons.star : LucideIcons.star,
                    size: 14,
                    color: i < rating ? Colors.amber : Colors.grey[400],
                  );
                }),
              ),
            ],
          ),
          
          // Comment
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              comment,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.messageSquare,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Reviews Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your customer reviews will appear here',
            style: TextStyle(
              color: isDark ? Colors.grey[600] : Colors.grey[500],
            ),
          ),
        ],
      ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
    );
  }
}
