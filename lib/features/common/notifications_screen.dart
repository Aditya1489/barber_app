import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/providers/user_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    final apiService = ref.read(apiServiceProvider);
    try {
      final notifs = await apiService.getNotifications(user.id);
      if (mounted) {
        setState(() {
          _notifications = notifs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markRead(String id) async {
    final apiService = ref.read(apiServiceProvider);
    await apiService.markNotificationAsRead(id);
    // Optimistic update
    setState(() {
      final index = _notifications.indexWhere((n) => n['id'] == id);
      if (index != -1) {
        _notifications[index]['isRead'] = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _notifications.isEmpty 
                    ? Center(child: Text("No notifications", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) => _buildNotificationCard(isDark, _notifications[index]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.arrowLeft, size: 20),
            ),
          ),
          const SizedBox(width: 20),
          const Text(
            "Notifications",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(bool isDark, Map<String, dynamic> notif) {
    final isRead = notif['isRead'] == true;
    
    return InkWell(
      onTap: () => !isRead ? _markRead(notif['id']) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(24),
          border: !isRead ? Border.all(color: AppTheme.emerald, width: 1) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isRead ? (isDark ? Colors.white : Colors.black) : AppTheme.emerald).withOpacity(0.1), 
                shape: BoxShape.circle
              ),
              child: Icon(LucideIcons.bell, size: 20, color: isRead ? (isDark ? Colors.white : Colors.black).withOpacity(0.4) : AppTheme.emerald),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif['title'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isRead ? null : AppTheme.emerald)),
                  const SizedBox(height: 4),
                  Text(notif['body'], style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                  const SizedBox(height: 8),
                  Text(
                    notif['createdAt'].toString().substring(0, 10), // Simple date
                    style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3))
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
