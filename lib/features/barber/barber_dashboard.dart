import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/widgets/user_avatar.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/core/providers/locale_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/models/models.dart';
import 'package:intl/intl.dart';

import 'package:barber_sync/services/notification_service.dart';
import 'package:barber_sync/services/fcm_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barber_sync/l10n/app_localizations.dart';

class BarberDashboardScreen extends ConsumerStatefulWidget {
  const BarberDashboardScreen({super.key});

  @override
  ConsumerState<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends ConsumerState<BarberDashboardScreen> {
  int _currentIndex = 0;
  String _sortBy = 'Recently Booked'; // Default sort
  List<String> _selectedServiceFilters = []; // New service filter
  String _activeTaskTab = 'Requests'; // Default tab in Appointments
  
  Map<String, dynamic>? _analytics;
  List<Appointment> _appointments = [];
  Map<String, dynamic>? _staffProfile;
  Map<String, dynamic>? _shopProfile;
  bool _isLoading = true;
  
  // Revamped Earnings State
  int _earningsSummaryIndex = 0;
  String _earningsPeriod = 'Week';
  final PageController _earningsSummaryController = PageController();
  late AppLocalizations l10n;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    l10n = AppLocalizations.of(context)!;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      final user = ref.read(userProvider);
      if (user != null) {
        ref.read(fcmServiceProvider).initialize(user.id);
      }
      // Note: Polling already started in login_screen.dart
      // No need to start again here to avoid duplicate polling
    });
  }
  
  @override
  void dispose() {
    ref.read(notificationServiceProvider).stopPolling();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final apiService = ref.read(apiServiceProvider);

    try {
      if (user.role == AppRole.owner) {
        final results = await Future.wait([
          apiService.getOwnerAnalytics(user.id, period: 'Daily'),
          apiService.getShopsByOwner(user.id),
        ]);
        
        _analytics = results[0] as Map<String, dynamic>?;
        final shops = results[1] as List<dynamic>;
        
        if (shops.isNotEmpty) {
          _shopProfile = Map<String, dynamic>.from(shops.first as Map);
          final shopId = _shopProfile?['id'] as String?;
          if (shopId != null) {
            _appointments = await apiService.getAppointments(shopId: shopId, limit: 50);
          }
        }
      } else {
        // Barber role
        // 1. Get Profile first to get the Staff ID
        final profile = await apiService.getStaffProfile(user.id);
        _staffProfile = profile;

        if (_staffProfile != null) {
          final staffId = _staffProfile!['id'];
          final results = await Future.wait([
            apiService.getStaffEarnings(user.id, period: 'Daily'),
            apiService.getAppointments(staffId: staffId, limit: 50),
          ]);
          _analytics = results[0] as Map<String, dynamic>?;
          _appointments = results[1] as List<Appointment>;

          // Sync Profile Photo to UserProvider
          final photo = _staffProfile!['photo'] ?? _staffProfile!['imageUrl'];
            if (photo != null && photo != user.profilePhoto) {
               Future.microtask(() async {
                  final currentUser = ref.read(userProvider);
                  if (currentUser != null) {
                    await ref.read(userProvider.notifier).setUser(currentUser.copyWith(profilePhoto: photo));
                  }
               });
            }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading dashboard: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getServiceNames(List<String> serviceIds) {
    if (serviceIds.isEmpty) return "No services";
    
    final shopServices = (_shopProfile?['services'] as List?) ?? 
                        (_staffProfile?['shop']?['services'] as List?) ?? [];
    
    if (shopServices.isEmpty) return "${serviceIds.length} Services";

    List<String> names = [];
    for (var id in serviceIds) {
      final service = shopServices.firstWhere(
        (s) => s['id'] == id,
        orElse: () => null,
      );
      if (service != null && service['name'] != null) {
        names.add(service['name']);
      }
    }

    if (names.isEmpty) return "${serviceIds.length} Services";
    return names.join(", ");
  }

  // --- REVAMPED EARNINGS HELPERS ---
  
  Map<String, double> _getLineChartData() {
    Map<String, double> dailyData = {};
    DateTime now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      DateTime day = now.subtract(Duration(days: i));
      String dateStr = DateFormat.yMd(Localizations.localeOf(context).toString()).format(day);
      dailyData[dateStr] = 0.0;
    }

    for (var appt in _appointments) {
      if (appt.status == AppointmentStatus.completed && dailyData.containsKey(appt.date)) {
        dailyData[appt.date] = (dailyData[appt.date] ?? 0.0) + appt.totalAmount;
      }
    }
    return dailyData;
  }

  List<Map<String, dynamic>> _getServiceRankedList() {
    Map<String, double> serviceRevenue = {};
    final shopServices = (_shopProfile?['services'] as List?) ?? 
                        (_staffProfile?['shop']?['services'] as List?) ?? [];

    for (var appt in _appointments) {
      if (appt.status == AppointmentStatus.completed) {
        for (var sId in appt.services) {
          final service = shopServices.firstWhere((s) => s['id'] == sId, orElse: () => null);
          String sName = service != null ? service['name'] : 'Unknown';
          serviceRevenue[sName] = (serviceRevenue[sName] ?? 0.0) + (appt.totalAmount / appt.services.length);
        }
      }
    }

    var list = serviceRevenue.entries.map((e) => {'name': e.key, 'revenue': e.value}).toList();
    list.sort((a, b) => (b['revenue'] as double).compareTo(a['revenue'] as double));
    return list;
  }

  Map<String, double> _getProductivityData() {
    double morning = 0, afternoon = 0, evening = 0;
    for (var appt in _appointments) {
      if (appt.status == AppointmentStatus.completed) {
        String slot = appt.timeSlot.toLowerCase();
        if (slot.contains('am')) {
          morning += appt.totalAmount;
        } else {
          int hour = int.tryParse(slot.split(':')[0]) ?? 0;
          if (slot.contains('pm') && hour != 12) hour += 12;
          if (hour < 16) {
            afternoon += appt.totalAmount;
          } else {
            evening += appt.totalAmount;
          }
        }
      }
    }
    return {l10n.morning: morning, l10n.afternoon: afternoon, l10n.evening: evening};
  }

  Map<String, dynamic> _getClientAnalytics() {
    Set<String> uniqueIds = {};
    Map<String, int> visitCounts = {};
    
    for (var appt in _appointments) {
      uniqueIds.add(appt.customerId);
      visitCounts[appt.customerId] = (visitCounts[appt.customerId] ?? 0) + 1;
    }

    int repeats = visitCounts.values.where((v) => v > 1).length;
    double repeatRate = uniqueIds.isEmpty ? 0 : (repeats / uniqueIds.length);
    int newClients = visitCounts.values.where((v) => v == 1).length;

    return {
      'unique': uniqueIds.length,
      'repeatRate': repeatRate,
      'new': newClients
    };
  }

  Map<String, dynamic> _getComparisonStats() {
    DateTime now = DateTime.now();
    DateTime lastWeekStart = now.subtract(const Duration(days: 14));
    DateTime lastWeekEnd = now.subtract(const Duration(days: 7));
    DateTime currentWeekStart = lastWeekEnd;

    double currentTotal = 0, lastTotal = 0;

    for (var appt in _appointments) {
      if (appt.status == AppointmentStatus.completed) {
        try {
          DateTime apptDate = DateTime.parse(appt.date);
          if (apptDate.isAfter(currentWeekStart)) {
            currentTotal += appt.totalAmount;
          } else if (apptDate.isAfter(lastWeekStart) && apptDate.isBefore(lastWeekEnd)) {
            lastTotal += appt.totalAmount;
          }
        } catch (_) {}
      }
    }

    double diff = currentTotal - lastTotal;
    double percent = lastTotal == 0 ? 0 : (diff / lastTotal);

    return {'diff': diff, 'percent': percent, 'isPositive': diff >= 0};
  }

  String _getClientLoyalty(String customerId) {
    int visits = _appointments.where((a) => a.customerId == customerId && a.status == AppointmentStatus.completed).length;
    if (visits >= 3) return "Loyal";
    if (visits >= 1) return "Returning";
    return "First-time";
  }

  Map<String, double> _getCommissionSplit(double total) {
    // Get commission rate from staff profile if available, default to 70%
    final staffCommission = (_staffProfile?['commissionRate']?.toDouble() ?? 70.0) / 100;
    double staffCut = total * staffCommission;
    double ownerCut = total * (1 - staffCommission);
    return {'staff': staffCut, 'owner': ownerCut, 'staffPercent': staffCommission * 100};
  }

  String _getShiftHealth(AppLocalizations l10n) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int todayCount = _appointments.where((a) => a.date == today).length;
    if (todayCount > 8) return l10n.busyDay;
    if (todayCount > 4) return l10n.productiveDay;
    return l10n.lightDay;
  }

  String _getPerformanceStreak(AppLocalizations l10n) {
    final user = ref.read(userProvider);
    if (user == null || user.role != AppRole.barber) {
      return l10n.keepUpWork;
    }

    // Get staff ID
    final staffId = _staffProfile?['id'] as String?;
    if (staffId == null) {
      return l10n.startStreak;
    }

    // Get all completed appointments for this staff member
    final completedAppointments = _appointments.where((appt) => 
      appt.staffId == staffId && 
      appt.status == AppointmentStatus.completed
    ).toList();

    if (completedAppointments.isEmpty) {
      return l10n.startStreak;
    }

    // Get unique dates with completed appointments, sorted descending
    final completedDates = completedAppointments
        .map((appt) => appt.date)
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a)); // Sort descending (newest first)

    if (completedDates.isEmpty) {
      return l10n.startStreak;
    }

    // Calculate consecutive days streak starting from today
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int streak = 0;
    
    // Check if today has completed appointments
    if (completedDates.contains(today)) {
      streak = 1;
      
      // Count backwards for consecutive days
      DateTime currentDate = DateTime.now();
      for (int i = 1; i <= 365; i++) { // Max 365 days
        currentDate = currentDate.subtract(const Duration(days: 1));
        final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
        
        if (completedDates.contains(dateStr)) {
          streak++;
        } else {
          break; // Streak broken
        }
      }
    } else {
      // Check if yesterday has completed appointments (streak might be ongoing)
      final yesterday = DateFormat('yyyy-MM-dd').format(
        DateTime.now().subtract(const Duration(days: 1))
      );
      
      if (completedDates.contains(yesterday)) {
        streak = 1;
        
        // Count backwards from yesterday
        DateTime currentDate = DateTime.now().subtract(const Duration(days: 1));
        for (int i = 1; i <= 365; i++) {
          currentDate = currentDate.subtract(const Duration(days: 1));
          final dateStr = DateFormat('yyyy-MM-dd').format(currentDate);
          
          if (completedDates.contains(dateStr)) {
            streak++;
          } else {
            break;
          }
        }
      }
    }

    // Return appropriate message based on streak
    if (streak == 0) {
      return l10n.startStreak;
    } else if (streak == 1) {
      return l10n.oneDayStreak;
    } else if (streak < 7) {
      return l10n.dayStreak(streak);
    } else if (streak < 30) {
      return l10n.dayStreakAmazing(streak);
    } else {
      return l10n.dayStreakUnstoppable(streak);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to locale changes and force rebuild
    ref.listen(localeProvider, (previous, next) {
      if (mounted && previous != next) {
        setState(() {});
      }
    });
    final isDark = ref.watch(themeProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    // Auto-refresh when notification service triggers
    ref.listen(refreshTriggerProvider, (prev, next) {
      if (next > (prev ?? 0)) {
        _loadData();
      }
    });

    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: Column(
          children: [
            Expanded(
              child: _isLoading && _appointments.isEmpty
                ? const Center(child: CircularProgressIndicator()) 
                : _buildBody(isDark, unreadCount),
            ),
            _buildBottomNav(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenHeader(bool isDark, {required String title, String? subtitle, Widget? trailing, bool showAura = false, bool isOnline = true}) {
    final auraColor = isOnline ? AppTheme.emerald : Colors.red;
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                if (showAura)
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: auraColor.withOpacity(0.2), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: auraColor.withOpacity(0.15),
                          blurRadius: 15,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: auraColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitle != null)
                        Text(
                          subtitle.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                            letterSpacing: 2,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, int unreadCount) {
    final l10n = AppLocalizations.of(context)!;

    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab(isDark, unreadCount, l10n);
      case 1:
        return _buildTasksTab(isDark, l10n);
      case 2:
        return _buildEarningsTab(isDark, l10n);
      case 3:
        return _buildProfileTab(isDark, l10n);
      default:
        return const SizedBox();
    }
  }

  Widget _buildDashboardTab(bool isDark, int unreadCount, AppLocalizations l10n) {
    final user = ref.watch(userProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());
    final isStaff = user.role == AppRole.barber;
    
    // Find Next Appointment for "Today Focus"
    Appointment? nextAppt;
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final upcomingToday = _appointments.where((a) => 
      a.date == todayStr && 
      a.status == AppointmentStatus.confirmed
    ).toList();
    
    if (upcomingToday.isNotEmpty) {
      upcomingToday.sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
      nextAppt = upcomingToday.first;
    }

    int pendingRequests = _appointments.where((a) => a.status == AppointmentStatus.pending).length;
    bool allDone = _appointments.any((a) => a.date == todayStr) && 
                   _appointments.where((a) => a.date == todayStr).every((a) => a.status == AppointmentStatus.completed || a.status == AppointmentStatus.noShow);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScreenHeader(
          isDark,
          title: user.name,
          subtitle: _getShiftHealth(l10n),
          trailing: _buildHeaderNotificationItem(isDark, unreadCount),
          showAura: isStaff,
          isOnline: (_staffProfile != null) ? (_staffProfile!['isAvailable'] ?? true) : true,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isStaff) ...[
                  Builder(
                    builder: (context) {
                      // Calculate today's stats
                      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
                      final todayAppointments = _appointments.where((a) => a.date == todayStr).toList();
                      final todayCompleted = todayAppointments.where((a) => a.status == AppointmentStatus.completed).toList();
                      final todayAppointmentCount = todayAppointments.length;
                      final todayEarnings = todayCompleted.fold(0.0, (sum, a) => sum + a.totalAmount);
                      
                      return _buildTodayFocusCard(
                        isDark,
                        nextAppt,
                        pendingRequests,
                        allDone,
                        todayAppointmentCount: todayAppointmentCount,
                        todayEarnings: todayEarnings,
                        onTap: () {
                          setState(() {
                            _currentIndex = 1; // Navigate to Appointments tab
                            // Set appropriate task tab based on state
                            if (pendingRequests > 0) {
                              _activeTaskTab = 'Requests';
                            } else if (nextAppt != null) {
                              _activeTaskTab = 'Upcoming';
                            } else {
                              _activeTaskTab = 'Requests'; // Default
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                ],
                _buildStatsGrid(isDark),
                if (isStaff) ...[
                  const SizedBox(height: 6),
                  _buildPerformanceStreakCard(isDark),
                ],
                if (!isStaff) ...[
                  const SizedBox(height: 24),
                  _buildRecentRequests(isDark),
                ],
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildPerformanceStreakCard(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
     return Container(
       padding: const EdgeInsets.all(20),
       decoration: BoxDecoration(
         gradient: LinearGradient(colors: [AppTheme.emerald, AppTheme.emerald.withOpacity(0.7)]),
         borderRadius: BorderRadius.circular(24),
       ),
       child: Row(
         children: [
           const Text("🔥", style: TextStyle(fontSize: 24)),
           const SizedBox(width: 16),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(l10n.onFire, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2)),
                 Text(_getPerformanceStreak(l10n), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
               ],
             ),
           ),
         ],
       ),
     );
  }

  Widget _buildHeaderNotificationItem(bool isDark, int unreadCount) {
    return InkWell(
      onTap: () => _showNotificationsPopup(isDark),
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.bell, size: 20),
          ),
          if (unreadCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  unreadCount > 9 ? '9+' : unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showNotificationsPopup(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBGMiddle : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: _NotificationsPopupContent(
              scrollController: scrollController,
              isDark: isDark,
              onNotificationRead: () {
                // Refresh unread count when a notification is marked as read
                ref.read(unreadNotificationCountProvider.notifier).state--;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTodayFocusCard(
    bool isDark, 
    Appointment? next, 
    int pending, 
    bool allDone, {
    int todayAppointmentCount = 0,
    double todayEarnings = 0.0,
    VoidCallback? onTap,
  }) {
    final l10n = AppLocalizations.of(context)!;
    String focusTitle = l10n.todayFocus;
    String currentSubtitle = "Check your schedule to start";
    IconData focusIcon = LucideIcons.calendar;
    Color focusColor = Colors.blue;

    if (pending > 0) {
      focusTitle = "$pending ${l10n.pendingRequests}";
      currentSubtitle = "Action required soon";
      focusIcon = LucideIcons.bellRing;
      focusColor = Colors.amber;
    } else if (next != null) {
      focusTitle = "${l10n.nextClient}: ${next.timeSlot}";
      currentSubtitle = next.services.isNotEmpty ? next.services.first : "";
      focusIcon = LucideIcons.clock;
      focusColor = AppTheme.emerald;
    } else if (allDone) {
      focusTitle = l10n.allSystemsRunning;
      currentSubtitle = l10n.noActionRequired;
      focusIcon = LucideIcons.partyPopper;
      focusColor = AppTheme.emerald;
    }

    // Calculate time until next appointment
    String? nextApptTimeDescription;
    if (next != null) {
      try {
        final now = DateTime.now();
        final timeParts = next.timeSlot.split(':');
        if (timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]);
          final minute = int.tryParse(timeParts[1].split(' ')[0]);
          if (hour != null && minute != null) {
            final apptTime = DateTime(now.year, now.month, now.day, hour, minute);
            if (apptTime.isAfter(now)) {
              final difference = apptTime.difference(now);
              if (difference.inHours > 0) {
                nextApptTimeDescription = "${difference.inHours}h ${difference.inMinutes % 60}m";
              } else {
                nextApptTimeDescription = "${difference.inMinutes}m";
              }
            }
          }
        }
      } catch (e) {
        // If parsing fails, just show the time slot
        nextApptTimeDescription = next.timeSlot;
      }
    }
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [focusColor.withOpacity(0.9), focusColor]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
              boxShadow: [BoxShadow(color: focusColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: Icon(focusIcon, color: Colors.white, size: 24),
                    ),
                    if (nextApptTimeDescription != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                        child: Text("in $nextApptTimeDescription", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(focusTitle, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(currentSubtitle, style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14, fontWeight: FontWeight.w500)),
                
                const SizedBox(height: 24),
                // Stats row
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        isDark,
                        LucideIcons.calendar,
                        todayAppointmentCount.toString(),
                        l10n.today,
                        Colors.blue,
                      ),
                      _buildStatItem(
                        isDark,
                        LucideIcons.dollarSign,
                        NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString(), decimalDigits: 0).format(todayEarnings),
                        l10n.earnings,
                        AppTheme.emerald,
                      ),
                      _buildStatItem(
                        isDark,
                        LucideIcons.clock,
                        nextApptTimeDescription ?? "N/A",
                        l10n.upcoming,
                        Colors.orange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(bool isDark, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher({
    required bool isDark,
    required List<String> items,
    required String activeItem,
    required Function(String) onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: items.map((item) => Expanded(
          child: GestureDetector(
            onTap: () => onTap(item),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: activeItem == item ? (isDark ? AppTheme.darkCardBG : Colors.white) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: activeItem == item && !isDark ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))] : null,
              ),
              alignment: Alignment.center,
              child: Text(
                item.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: activeItem == item ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox.shrink();
    // Calculate stats locally from cached appointments for real-time accuracy
    int pendingCount = _appointments.where((a) => a.status == AppointmentStatus.pending).length;
    int acceptedCount = _appointments.where((a) => 
      a.status == AppointmentStatus.confirmed || 
      a.status == AppointmentStatus.awaitingCustomerConfirmation).length;
    int completedCount = _appointments.where((a) => a.status == AppointmentStatus.completed).length;
    int missedCount = _appointments.where((a) => a.status == AppointmentStatus.noShow).length;
    
    double completedEarnings = _appointments
        .where((a) => a.status == AppointmentStatus.completed)
        .fold(0.0, (sum, a) => sum + a.totalAmount);
    
    String earningsLabel = completedEarnings.toStringAsFixed(0);

    if (user.role == AppRole.barber) {
      final ranked = _getServiceRankedList();
      final topService = ranked.isNotEmpty ? ranked.first['name'] : "No services yet";

      return Column(
        children: [
          if (ranked.isNotEmpty)
            Container(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  const Icon(LucideIcons.award, color: Colors.amber, size: 16),
                  const SizedBox(width: 12),
                  const Text("Top Service:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text(topService, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.emerald)),
                ],
              ),
            ),
          Transform.translate(
            offset: const Offset(0, -8),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.4,
              children: [
                _buildCompactStatCard(isDark, "Requests", pendingCount.toString(), LucideIcons.bell, Colors.blue, helper: "Waiting for action"),
                _buildCompactStatCard(isDark, "Upcoming", acceptedCount.toString(), LucideIcons.scissors, Colors.orange, helper: "Your next appointments"),
                _buildCompactStatCard(isDark, "Completed", completedCount.toString(), LucideIcons.checkCircle, AppTheme.emerald, helper: "Great progress!"),
                _buildCompactStatCard(isDark, "Missed", missedCount.toString(), LucideIcons.userX, Colors.red, helper: "Affects rating"),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(isDark, "Requests", pendingCount.toString(), LucideIcons.bell, Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(isDark, "Upcoming", acceptedCount.toString(), LucideIcons.scissors, Colors.orange)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard(isDark, "Completed", completedCount.toString(), LucideIcons.checkCircle, AppTheme.emerald)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(isDark, l10n.missed, missedCount.toString(), LucideIcons.userX, Colors.red)),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(isDark, l10n.totalEarnings, NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString(), decimalDigits: 0).format(double.tryParse(earningsLabel) ?? 0), LucideIcons.dollarSign, Colors.amber),
      ],
    );
  }

  Widget _buildCompactStatCard(bool isDark, String label, String value, IconData icon, Color color, {String? helper}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(helper, style: TextStyle(fontSize: 9, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          ],
        ],
      ),
    ).animate().fadeIn().scale(delay: const Duration(milliseconds: 100));
  }

  Widget _buildStatCard(bool isDark, String label, String value, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 28, 
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentRequests(bool isDark) {
    List<Appointment> pendingAppts = _appointments.where((a) => a.status == AppointmentStatus.pending).toList();

    // 1. Filter by services if any selected
    if (_selectedServiceFilters.isNotEmpty) {
      pendingAppts = pendingAppts.where((appt) {
         return appt.services.any((sId) => _selectedServiceFilters.contains(sId));
      }).toList();
    }

    // 2. Sort the list based on selection
    if (_sortBy == 'Recently Booked') {
      pendingAppts.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
    } else if (_sortBy == 'Highest Amount') {
      pendingAppts.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    } else if (_sortBy == 'Longest Duration') {
      pendingAppts.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
    } else {
      pendingAppts.sort((a, b) {
        final startA = _calculateStartDateTime(a);
        final startB = _calculateStartDateTime(b);
        return startA.compareTo(startB);
      });
    }

    if (pendingAppts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Icon(LucideIcons.checkCircle2, size: 40, color: AppTheme.emerald.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              l10n.allCaughtUp,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
            ),
            Text(
              l10n.noNewRequests,
              style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(l10n.pendingRequests, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pendingAppts.length.toString(),
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                _buildServiceFilterDropdown(isDark),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    setState(() => _sortBy = value);
                  },
                  tooltip: l10n.sortRequests,
                  icon: Icon(LucideIcons.listFilter, size: 20, color: AppTheme.darkAccent),
                  itemBuilder: (context) => [
                    PopupMenuItem(value: 'Recently Booked', child: Text(l10n.recentlyBooked)),
                    PopupMenuItem(value: 'Appointment Date', child: Text(l10n.appointmentDate)),
                    PopupMenuItem(value: 'Highest Amount', child: Text(l10n.highestAmount)),
                    PopupMenuItem(value: 'Longest Duration', child: Text(l10n.longestDuration)),
                  ],
                ),
              ],
            ),
          ],
        ),
        if (_selectedServiceFilters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, bottom: 12),
            child: Row(
              children: [
                Text(
                  l10n.servicesSelected(_selectedServiceFilters.length),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _selectedServiceFilters.clear()),
                  child: Text(
                    l10n.clear,
                    style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ...pendingAppts.take(5).map((appt) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildRequestCard(isDark, appt),
        )).toList(),
      ],
    );
  }

  Widget _buildServiceFilterDropdown(bool isDark) {
    final services = (_shopProfile?['services'] as List?) ?? 
                    (_staffProfile?['shop']?['services'] as List?) ?? [];
    
    if (services.isEmpty) return const SizedBox.shrink();

    return PopupMenuButton<String>(
      onSelected: (String sId) {
        setState(() {
          if (_selectedServiceFilters.contains(sId)) {
            _selectedServiceFilters.remove(sId);
          } else {
            _selectedServiceFilters.add(sId);
          }
        });
      },
      tooltip: "Filter by Service",
      icon: Stack(
        children: [
          Icon(LucideIcons.search, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
          if (_selectedServiceFilters.isNotEmpty)
             Positioned(
               right: 0,
               top: 0,
               child: Container(
                 width: 8,
                 height: 8,
                 decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
               ),
             ),
        ],
      ),
      itemBuilder: (context) => services.map((service) {
        final String sId = service['id'];
        final String sName = service['name'];
        final bool isSelected = _selectedServiceFilters.contains(sId);

        return PopupMenuItem<String>(
          value: sId,
          child: Row(
            children: [
              Icon(
                isSelected ? LucideIcons.checkSquare : LucideIcons.square,
                size: 18,
                color: isSelected ? AppTheme.darkAccent : null,
              ),
              const SizedBox(width: 12),
              Text(sName),
            ],
          ),
        );
      }).toList(),
    );
  }

  DateTime _calculateStartDateTime(Appointment appt) {
    DateTime appointmentDate;
    final String dateStr = appt.date;
    final now = DateTime.now();
    
    if (dateStr.toLowerCase() == 'today') {
      appointmentDate = now;
    } else if (dateStr.toLowerCase() == 'tomorrow') {
      appointmentDate = now.add(const Duration(days: 1));
    } else if (dateStr.contains(',')) {
      final parts = dateStr.split(' ');
      final day = int.tryParse(parts.last) ?? now.day;
      if (day >= now.day) {
        appointmentDate = DateTime(now.year, now.month, day);
      } else {
        int nextMonth = now.month + 1;
        int nextYear = now.year;
        if (nextMonth > 12) {
          nextMonth = 1;
          nextYear++;
        }
        appointmentDate = DateTime(nextYear, nextMonth, day);
      }
    } else {
      appointmentDate = DateFormat("yyyy-MM-dd").parse(dateStr);
    }
    
    final timeParts = DateFormat("h:mm a").parse(appt.timeSlot);
    return DateTime(
      appointmentDate.year,
      appointmentDate.month,
      appointmentDate.day,
      timeParts.hour,
      timeParts.minute,
    );
  }

  DateTime _calculateEndDateTime(Appointment appt) {
    final start = _calculateStartDateTime(appt);
    return start.add(Duration(minutes: appt.totalDuration));
  }

  Future<void> _markAsCompleted(Appointment appt) async {
    // Check if end time has passed
    try {
      final endTime = _calculateEndDateTime(appt);
      final now = DateTime.now();
      
      if (now.isBefore(endTime)) {
        final waitMins = endTime.difference(now).inMinutes;
        final waitText = waitMins > 60 
            ? "${(waitMins / 60).floor()}h ${waitMins % 60}m" 
            : "$waitMins minutes";
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.orange.shade900,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(LucideIcons.alertTriangle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Service Ongoing. Please wait $waitText to complete.",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }
    } catch (e) {
      print("Warning: Could not strictly verify end time: $e");
    }

    final success = await ref.read(apiServiceProvider).updateBookingStatus(appt.id, "COMPLETED");
    if (success) {
      if (mounted) {
        // Refresh data to move it out of active tasks
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Appointment marked as completed! ✨"))
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status. Please try again."))
        );
      }
    }
  }

  Future<void> _markAsNoShow(Appointment appt) async {
    final success = await ref.read(apiServiceProvider).updateBookingStatus(appt.id, "NO_SHOW");
    if (success) {
      if (mounted) {
        await _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Marked as No-Show. Customer notified. 📝"))
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update status."))
        );
      }
    }
  }

  void _showTimeRemaining(Appointment appt) {
    try {
      final fullDateTime = _calculateStartDateTime(appt);
      final now = DateTime.now();
      final difference = fullDateTime.difference(now);

      String message;
      if (difference.isNegative) {
        if (difference.inMinutes.abs() < 60) {
           message = "Started ${difference.inMinutes.abs()} mins ago";
        } else {
           message = "Started ${difference.inHours.abs()} hours ago";
        }
      } else {
        if (difference.inHours > 0) {
          message = "Starts in ${difference.inHours} hours and ${difference.inMinutes % 60} mins";
        } else {
          message = "Starts in ${difference.inMinutes} mins";
        }
      }

      showDialog(
        context: context,
        builder: (context) {
          final isDark = ref.read(themeProvider);
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: isDark ? AppTheme.darkCardBG : Colors.white,
            title: Text(l10n.timeStatus, style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.clock, size: 48, color: AppTheme.darkAccent),
                const SizedBox(height: 16),
                Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text("Scheduled for: ${appt.timeSlot}", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE", style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          );
        },
      );
    } catch (e) {
      print("Error calculating time: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not calculate time: ${appt.date} ${appt.timeSlot}"))
      );
    }
  }

  Widget _buildRequestCard(bool isDark, Appointment appt) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBG.withOpacity(0.4) : AppTheme.lightCardBG.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: isDark ? Border.all(color: Colors.white.withOpacity(0.05)) : Border.all(color: Colors.black.withOpacity(0.05)),
          ),
          child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                UserAvatar(
                  radius: 26,
                  photoUrl: appt.customerPhoto,
                  name: appt.customerName ?? l10n.customer,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(appt.customerName ?? l10n.customer, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          Text("\$${appt.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.w900, color: AppTheme.emerald, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getServiceNames(appt.services), 
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.03),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 12, color: AppTheme.darkAccent),
                    const SizedBox(width: 6),
                    Text(appt.date, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.clock, size: 12, color: AppTheme.darkAccent),
                    const SizedBox(width: 6),
                    Text(appt.timeSlot, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text(
                  "NEEDS APPROVAL",
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.darkAccent.withOpacity(0.8), letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                       final success = await ref.read(apiServiceProvider).updateBookingStatus(appt.id, "AWAITING_CUSTOMER_CONFIRMATION");
                       if (success) _loadData();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.emerald.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: const Text("ACCEPT", style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () async {
                      final success = await ref.read(apiServiceProvider).updateBookingStatus(appt.id, "CANCELLED_BY_BARBER");
                     if (success) _loadData();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(LucideIcons.x, color: Colors.red, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

  Widget _buildIconButton(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }

  Widget _buildTasksTab(bool isDark, AppLocalizations l10n) {
    final pendingAppts = _appointments.where((a) => a.status == AppointmentStatus.pending).toList();
    final upcomingAppts = _appointments.where((a) => 
      a.status == AppointmentStatus.confirmed || 
      a.status == AppointmentStatus.awaitingCustomerConfirmation).toList();
    final completedAppts = _appointments.where((a) => a.status == AppointmentStatus.completed).toList();
    final noShowAppts = _appointments.where((a) => 
      a.status == AppointmentStatus.noShow || 
      a.status == AppointmentStatus.expired ||
      a.status == AppointmentStatus.cancelledByCustomer ||
      a.status == AppointmentStatus.cancelledByBarber
    ).toList();
    
    List<Appointment> currentList;
    if (_activeTaskTab == 'Requests') {
      currentList = pendingAppts;
      // Apply filters for Requests
      if (_selectedServiceFilters.isNotEmpty) {
        currentList = currentList.where((appt) => appt.services.any((sId) => _selectedServiceFilters.contains(sId))).toList();
      }
      // Apply sorting for Requests
      if (_sortBy == 'Recently Booked') {
        currentList.sort((a, b) => b.bookedAt.compareTo(a.bookedAt));
      } else if (_sortBy == 'Highest Amount') {
        currentList.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
      } else if (_sortBy == 'Longest Duration') {
        currentList.sort((a, b) => b.totalDuration.compareTo(a.totalDuration));
      } else {
        currentList.sort((a, b) {
          final startA = _calculateStartDateTime(a);
          final startB = _calculateStartDateTime(b);
          return startA.compareTo(startB);
        });
      }
    } else if (_activeTaskTab == 'Upcoming') {
      currentList = upcomingAppts;
      currentList.sort((a, b) {
        final startA = _calculateStartDateTime(a);
        final startB = _calculateStartDateTime(b);
        return startA.compareTo(startB);
      });
    } else if (_activeTaskTab == 'Completed') {
      currentList = completedAppts;
      currentList.sort((a, b) => b.date.compareTo(a.date)); // Most recent first
    } else {
      currentList = noShowAppts;
      currentList.sort((a, b) => b.date.compareTo(a.date));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScreenHeader(
          isDark, 
          title: l10n.appointments,
          subtitle: l10n.manageYourDay,
          trailing: _activeTaskTab == 'Requests' ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildServiceFilterDropdown(isDark),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() => _sortBy = value);
                },
                tooltip: l10n.sortRequests,
                icon: Icon(LucideIcons.listFilter, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'Recently Booked', child: Text(l10n.recentlyBooked)),
                  PopupMenuItem(value: 'Appointment Date', child: Text(l10n.appointmentDate)),
                  PopupMenuItem(value: 'Highest Amount', child: Text(l10n.highestAmount)),
                  PopupMenuItem(value: 'Longest Duration', child: Text(l10n.longestDuration)),
                ],
              ),
            ],
          ) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: _buildTabSwitcher(
            isDark: isDark, 
            items: [l10n.requests, l10n.upcoming, l10n.completed, l10n.missed],
            activeItem: _activeTaskTab == 'Requests' ? l10n.requests :
                       _activeTaskTab == 'Upcoming' ? l10n.upcoming :
                       _activeTaskTab == 'Completed' ? l10n.completed :
                       l10n.missed,
            onTap: (val) {
              setState(() {
                if (val == l10n.requests) _activeTaskTab = 'Requests';
                if (val == l10n.upcoming) _activeTaskTab = 'Upcoming';
                if (val == l10n.completed) _activeTaskTab = 'Completed';
                if (val == l10n.missed) _activeTaskTab = 'Missed';
              });
            },
          ),
        ),
        
        if (_activeTaskTab == 'Requests' && _selectedServiceFilters.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                  Text(l10n.servicesSelected(_selectedServiceFilters.length), style: TextStyle(fontSize: 12, color: AppTheme.darkAccent, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _selectedServiceFilters.clear()),
                    child: Text(l10n.clear, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), decoration: TextDecoration.underline)),
                  ),
              ],
            ),
          ),

        const SizedBox(height: 24),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: currentList.isEmpty 
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.6,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _activeTaskTab == 'Requests' ? LucideIcons.bellPlus : 
                            _activeTaskTab == 'Upcoming' ? LucideIcons.calendar :
                            LucideIcons.hardDrive, 
                            size: 64, 
                            color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)
                          ),
                          const SizedBox(height: 16),
                          Text(_activeTaskTab == 'Requests' ? l10n.noNewRequests : l10n.noAppointments, style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: currentList.length,
                    itemBuilder: (context, index) {
                      final appt = currentList[index];
                      if (_activeTaskTab == 'Requests') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildRequestCard(isDark, appt),
                        );
                      }
                      
                      // Add swipe gestures for Appointments and Upcoming
                      if (_activeTaskTab == 'Upcoming') {
                        return _buildSwipeableTaskCard(isDark, appt, index);
                      }
                      
                      return _buildTaskCard(isDark, appt, index);
                    },
                  ),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildSwipeableTaskCard(bool isDark, Appointment appt, int index) {
    return Dismissible(
      key: Key(appt.id),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          _markAsCompleted(appt);
        } else {
          _markAsNoShow(appt);
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(32)),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 32),
        child: const Icon(LucideIcons.check, color: Colors.white, size: 32),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(32)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 32),
        child: const Icon(LucideIcons.x, color: Colors.white, size: 32),
      ),
      child: _buildTaskCard(isDark, appt, index),
    );
  }

  Widget _buildTaskCard(bool isDark, Appointment appt, int index) {
    final l10n = AppLocalizations.of(context)!;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool isToday = appt.date == today;
    bool isCurrent = isToday && index == 0 && _activeTaskTab == 'Upcoming';
    final loyalty = _getClientLoyalty(appt.customerId);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
        border: isCurrent ? Border.all(color: Colors.amber, width: 2) : null,
        boxShadow: isCurrent ? [BoxShadow(color: Colors.amber.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)] : null,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: isCurrent ? Colors.amber : Colors.blue, shape: BoxShape.circle),
                  ).animate(onPlay: (c) => c.repeat()).scale(duration: 1000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)).then().scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
                  const SizedBox(width: 8),
                  Text(appt.timeSlot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  _loyaltyBadge(loyalty),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isCurrent ? Colors.amber : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _activeTaskTab == 'Completed' ? l10n.completedStatus : 
                  _activeTaskTab == 'Missed' ? l10n.noShowStatus :
                  appt.status == AppointmentStatus.awaitingCustomerConfirmation ? l10n.pendingPaymentStatus :
                  isCurrent ? l10n.currentStatus : l10n.upcomingStatus,
                  style: TextStyle(
                    fontSize: 9, 
                    fontWeight: FontWeight.bold, 
                    color: _activeTaskTab == 'Missed' ? Colors.red : (appt.status == AppointmentStatus.awaitingCustomerConfirmation ? Colors.orange : (isCurrent ? Colors.amber : Colors.blue))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              UserAvatar(radius: 28, photoUrl: appt.customerPhoto, name: appt.customerName ?? l10n.customer),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appt.customerName ?? l10n.customer, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.scissors, size: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Expanded(child: Text(_getServiceNames(appt.services), style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(LucideIcons.clock, size: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                        const SizedBox(width: 4),
                        Text("${appt.totalDuration} min", style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                        const SizedBox(width: 12),
                        Icon(LucideIcons.dollarSign, size: 12, color: AppTheme.emerald),
                        const SizedBox(width: 2),
                        Text("\$${appt.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (appt.privateNotes != null) ...[
             const SizedBox(height: 16),
             Container(
               width: double.infinity,
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.amber.withOpacity(0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.withOpacity(0.1))),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       const Icon(LucideIcons.stickyNote, size: 12, color: Colors.amber),
                       const SizedBox(width: 4),
                       Text(l10n.privateNote.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber, letterSpacing: 0.5)),
                     ],
                   ),
                   const SizedBox(height: 4),
                   Text(appt.privateNotes!, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7), fontStyle: FontStyle.italic)),
                 ],
               ),
             ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              if (_activeTaskTab == 'Upcoming' || isCurrent)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddNoteDialog(appt),
                    icon: const Icon(LucideIcons.plus, size: 14),
                    label: Text(l10n.addNoteBtn, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                    ),
                  ),
                ),
              if (_activeTaskTab == 'Upcoming' || isCurrent) const SizedBox(width: 12),
              if (_activeTaskTab == 'Upcoming' || isCurrent)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(LucideIcons.flag, size: 14),
                    label: Text(l10n.reportIssue, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: Colors.red.withOpacity(0.1)),
                    ),
                  ),
                ),
            ],
          ),
          if (_activeTaskTab == 'Missed') ...[
             const SizedBox(height: 16),
             Container(
               padding: const EdgeInsets.all(12),
               decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(16)),
               child: Row(
                 children: [
                   const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Text(l10n.lostPotential(appt.totalAmount.toStringAsFixed(0)), style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
                   ),
                 ],
               ),
             ),
          ],
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _loyaltyBadge(String status) {
    // Note: status from DB might still be English ("Returning", "First-time")
    // We map it to localized string for display
    final l10n = AppLocalizations.of(context)!;
    
    Color color = Colors.grey;
    String label = status;

    if (status == "Loyal") {
      color = AppTheme.emerald;
      label = l10n.loyal;
    }
    if (status == "Returning") {
      color = Colors.blue;
      label = l10n.returning;
    }
    if (status == "First-time") {
      color = Colors.amber;
      label = l10n.firstTime;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }

  void _showAddNoteDialog(Appointment appt) {
     final l10n = AppLocalizations.of(context)!;
     final controller = TextEditingController(text: appt.privateNotes);
     showDialog(
       context: context,
       builder: (context) => AlertDialog(
         title: Text(l10n.addSessionNote),
         content: TextField(
           controller: controller,
           maxLines: 3,
           decoration: InputDecoration(hintText: l10n.noteHint),
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
           TextButton(onPressed: () {
             // Mock update locally
             setState(() {
               int idx = _appointments.indexWhere((a) => a.id == appt.id);
               if (idx != -1) {
                 final old = _appointments[idx];
                 _appointments[idx] = Appointment(
                   id: old.id, shopId: old.shopId, staffId: old.staffId,
                   customerId: old.customerId, customerName: old.customerName,
                   customerPhoto: old.customerPhoto, services: old.services,
                   date: old.date, timeSlot: old.timeSlot, status: old.status,
                   totalAmount: old.totalAmount, totalDuration: old.totalDuration,
                   bookedAt: old.bookedAt, privateNotes: controller.text
                 );
               }
             });
             Navigator.pop(context);
           }, child: Text(l10n.save)),
         ],
       ),
     );
  }

  Widget _buildEarningsTab(bool isDark, AppLocalizations l10n) {
    final completed = _appointments.where((a) => a.status == AppointmentStatus.completed).toList();
    final totalEarnings = completed.fold(0.0, (sum, a) => sum + a.totalAmount);
    final avgPerAppt = completed.isEmpty ? 0.0 : (totalEarnings / completed.length);
    final clientStats = _getClientAnalytics();
    final comparison = _getComparisonStats();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildScreenHeader(
          isDark, 
          title: l10n.earnings, 
          subtitle: l10n.performanceAnalytics,
          trailing: InkWell(
            onTap: () => _showEarningsActions(context, isDark),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(LucideIcons.moreHorizontal, size: 20),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Summary Carousel
                _buildSummaryCarousel(isDark, totalEarnings, completed.length, avgPerAppt, l10n)
                  .animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 2. Period Selector
                _buildPeriodChips(isDark, l10n)
                  .animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 3. Line Chart
                _buildPrimaryChart(isDark, l10n)
                  .animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 4. Service Breakdown
                _buildServiceBreakdown(isDark, l10n)
                  .animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 5 & 6. Combined Comparison & Productivity
                Row(
                   children: [
                     Expanded(child: _buildComparisonCard(isDark, comparison, l10n)),
                     const SizedBox(width: 16),
                     Expanded(child: _buildGoalMiniCard(isDark, totalEarnings, l10n)),
                   ],
                ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 7. Productivity Heatmap
                _buildProductivitySection(isDark, l10n)
                  .animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 8. Performance Rings
                _buildPerformanceRings(isDark, l10n)
                  .animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 9. Client Analytics
                _buildClientStats(isDark, clientStats, l10n)
                  .animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 24),
                
                // 10. Expandable Calculation
                _buildExpandableEarningsDetail(isDark, totalEarnings, l10n)
                  .animate().fadeIn(delay: 800.ms, duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutQuad),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      ],
    );
  }

  Widget _buildSummaryCarousel(bool isDark, double total, int count, double avg, AppLocalizations l10n) {
    final cards = [
      _carouselItem(isDark, l10n.totalEarnings, NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString()).format(total), LucideIcons.wallet, Colors.amber),
      _carouselItem(isDark, l10n.appointments, count.toString(), LucideIcons.checkCircle2, AppTheme.emerald),
      _carouselItem(isDark, l10n.avgPerSession, NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString()).format(avg), LucideIcons.arrowUpRight, Colors.blue),
    ];

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: PageView.builder(
            controller: _earningsSummaryController,
            onPageChanged: (i) => setState(() => _earningsSummaryIndex = i),
            itemCount: cards.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: cards[index],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(cards.length, (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            height: 6,
            width: _earningsSummaryIndex == i ? 20 : 6,
            decoration: BoxDecoration(
              color: _earningsSummaryIndex == i ? AppTheme.darkAccent : (isDark ? Colors.white : Colors.black).withOpacity(0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          )),
        ),
      ],
    );
  }

  Widget _carouselItem(bool isDark, String label, String val, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChips(bool isDark, AppLocalizations l10n) {
    final periods = [l10n.today, l10n.week, l10n.month, l10n.allTime];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((p) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(p),
            selected: _earningsPeriod == p,
            onSelected: (val) { if(val) setState(() => _earningsPeriod = p); },
            backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            selectedColor: AppTheme.darkAccent,
            labelStyle: TextStyle(
              color: _earningsPeriod == p ? Colors.white : (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              fontWeight: FontWeight.bold,
              fontSize: 12
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide.none,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildPrimaryChart(bool isDark, AppLocalizations l10n) {
    final data = _getLineChartData();
    final spots = data.values.toList().asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList();

    return Container(
      height: 260,
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.earningsTrend, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.darkAccent,
                    barWidth: 4,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.darkAccent.withOpacity(0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceBreakdown(bool isDark, AppLocalizations l10n) {
    final ranked = _getServiceRankedList();
    if (ranked.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.serviceBreakdown, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 24),
          Row(
            children: [
              SizedBox(
                height: 100,
                width: 100,
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 0,
                    centerSpaceRadius: 30,
                    sections: ranked.asMap().entries.map((e) => PieChartSectionData(
                      color: [Colors.blue, Colors.amber, Colors.teal, Colors.purple][e.key % 4],
                      value: e.value['revenue'],
                      showTitle: false,
                      radius: 8,
                    )).toList(),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  children: ranked.take(3).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s['name'], style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                        Text(NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString(), decimalDigits: 0).format(s['revenue'] as double), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceRings(bool isDark, AppLocalizations l10n) {
    final completed = _appointments.where((a) => a.status == AppointmentStatus.completed).length;
    final noShow = _appointments.where((a) => a.status == AppointmentStatus.noShow).length;
    final total = completed + noShow;
    double compRate = total == 0 ? 0 : completed / total;
    double noShowRate = total == 0 ? 0 : noShow / total;

    return Row(
      children: [
        Expanded(child: _perfRing(isDark, l10n.completionRate, compRate, AppTheme.emerald)),
        const SizedBox(width: 16),
        Expanded(child: _perfRing(isDark, l10n.noShowRate, noShowRate, Colors.red)),
      ],
    );
  }

  Widget _perfRing(bool isDark, String label, double val, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 60, width: 60,
                child: CircularProgressIndicator(
                  value: val,
                  strokeWidth: 6,
                  backgroundColor: color.withOpacity(0.1),
                  color: color,
                ),
              ),
              Text("${(val * 100).toStringAsFixed(0)}%", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildProductivitySection(bool isDark, AppLocalizations l10n) {
    final data = _getProductivityData();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.productivityHeatmap, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          ...data.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                SizedBox(width: 80, child: Text(e.key, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)))),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppTheme.darkAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: (e.value / 1000).clamp(0.01, 1.0),
                      child: Container(
                        decoration: BoxDecoration(color: AppTheme.darkAccent, borderRadius: BorderRadius.circular(5)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildClientStats(bool isDark, Map<String, dynamic> stats, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _clientMiniStat(l10n.uniqueClients, stats['unique'].toString()),
          _clientMiniStat(l10n.repeatClients, "${(stats['repeatRate'] * 100).toStringAsFixed(0)}%"),
          _clientMiniStat(l10n.newClients, stats['new'].toString()),
        ],
      ),
    );
  }

  Widget _clientMiniStat(String label, String val) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
      ],
    );
  }

  Widget _buildComparisonCard(bool isDark, Map<String, dynamic> stats, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.vsLastWeek, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(stats['isPositive'] ? LucideIcons.trendingUp : LucideIcons.trendingDown, color: stats['isPositive'] ? AppTheme.emerald : Colors.red, size: 14),
                      const SizedBox(width: 4),
                      Text("${(stats['percent'] * 100).abs().toStringAsFixed(1)}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: stats['isPositive'] ? AppTheme.emerald : Colors.red)),
                    ],
                  ),
                ],
              ),
              const Spacer(),
              _miniBar(AppTheme.emerald, 0.4),
              const SizedBox(width: 4),
              _miniBar(AppTheme.darkAccent, 0.8),
              const SizedBox(width: 4),
              _miniBar(Colors.blue, 0.6),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniBar(Color color, double heightFactor) {
    return Container(
      height: 30 * heightFactor,
      width: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildGoalMiniCard(bool isDark, double total, AppLocalizations l10n) {
    double goal = 2000;
    double progress = (total / goal).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.goalProgress, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: progress, backgroundColor: Colors.amber.withOpacity(0.1), color: Colors.amber, minHeight: 4),
        ],
      ),
    );
  }

  Widget _buildExpandableEarningsDetail(bool isDark, double total, AppLocalizations l10n) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      title: Text(l10n.earningsBreakdown, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString()).format(total), style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            children: [
              _detailRow(l10n.serviceRevenue, NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString()).format(total)),
              _detailRow(l10n.deductions, "\$0.00"),
              const Divider(height: 32),
              _detailRow(l10n.netPayout, NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString()).format(total), isBold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String val, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(val, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showEarningsActions(BuildContext context, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkBGMiddle : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _actionItem(LucideIcons.history, l10n.fullHistory),
            _actionItem(LucideIcons.download, l10n.exportPdf),
            _actionItem(LucideIcons.helpCircle, l10n.helpSupport),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionItem(IconData icon, String label) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      onTap: () => Navigator.pop(context),
    );
  }

  Widget _buildProfileTab(bool isDark, AppLocalizations l10n) {
    final user = ref.watch(userProvider);
    if (user == null) return const Center(child: CircularProgressIndicator());
    final isStaff = user.role == AppRole.barber;
    
    return Column(
      children: [
        _buildScreenHeader(
          isDark,
          title: l10n.profile,
          subtitle: l10n.myAccount,
          trailing: InkWell(
            onTap: () => ref.read(themeProvider.notifier).state = !isDark,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG, shape: BoxShape.circle),
              child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 20),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadData,
            color: AppTheme.emerald,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _buildShopHeader(isDark, l10n),
                const SizedBox(height: 24),

                if (isStaff) ...[
                  _buildProfileCompletionMeter(isDark, l10n),
                  const SizedBox(height: 24),
                  _buildPerformanceSnapshot(isDark, l10n),
                  const SizedBox(height: 24),
                  _buildSkillsSection(isDark, l10n),
                  const SizedBox(height: 24),
                  _buildAvailabilityToggle(isDark, l10n),
                  const SizedBox(height: 24),
                  
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.user, 
                    l10n.personalProfile, 
                    Colors.blue,
                    onTap: () async {
                        if (_staffProfile != null) {
                          await context.push('/staff-profile-edit', extra: _staffProfile);
                          _loadData();
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileLoading)));
                        }
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.scissors, 
                    l10n.myServices, 
                    AppTheme.emerald,
                    onTap: () async {
                       if (_staffProfile != null) {
                         await context.push('/staff-services', extra: _staffProfile);
                         _loadData();
                       }
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.store, 
                    l10n.previewShopProfile, 
                    Colors.teal,
                    onTap: () {
                       if (_staffProfile != null && _staffProfile!['shop'] != null) {
                          context.push('/shop-preview', extra: _staffProfile!['shop']); 
                       } else {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shopDataUnavailable)));
                       }
                    }
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    isDark,
                    LucideIcons.languages,
                    l10n.language,
                    Colors.indigo,
                    subtitle: _getCurrentLanguageName(ref.watch(localeProvider)),
                    onTap: () => context.push('/language-selection'),
                  ),
                ] else ...[
                  _buildShopPhotos(isDark),
                  const SizedBox(height: 24),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.store, 
                    l10n.shopSettings, 
                    Colors.blue,
                    onTap: () async {
                      if (_shopProfile != null) {
                        await context.push('/shop-settings', extra: _shopProfile); 
                        _loadData();
                      }
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.scissors, 
                    l10n.manageServices, 
                    Colors.red,
                    onTap: () {
                       if (_shopProfile != null) context.push('/manage-services', extra: _shopProfile);
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.users, 
                    l10n.staffManagement, 
                    AppTheme.emerald,
                    onTap: () {
                      if (_shopProfile != null) context.push('/staff-management', extra: _shopProfile);
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.barChart3, 
                    l10n.businessAnalytics, 
                    Colors.deepPurple,
                    onTap: () {
                       if (_shopProfile != null) context.push('/business-analytics', extra: _shopProfile);
                    }
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.fileText, 
                    l10n.auditTrail, 
                    Colors.orange,
                    onTap: () => context.push('/audit-trail')
                  ),
                  _buildProfileItem(
                    isDark, 
                    LucideIcons.eye, 
                    l10n.previewShopProfile, 
                    Colors.teal,
                    onTap: () {
                       if (_shopProfile != null) {
                          context.push('/shop-preview', extra: _shopProfile); 
                       } else {
                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.shopDataUnavailable)));
                       }
                    }
                  ),
                  const SizedBox(height: 16),
                  _buildProfileItem(
                    isDark,
                    LucideIcons.languages,
                    l10n.language,
                    Colors.indigo,
                    subtitle: _getCurrentLanguageName(ref.watch(localeProvider)),
                    onTap: () => context.push('/language-selection'),
                  ),
                  _buildProfileItem(isDark, LucideIcons.fileText, l10n.privacyPolicy, Colors.grey, onTap: () {
                    showAboutDialog(context: context, applicationName: 'BarberBook24', children: [Text(l10n.privacyPolicy + ' details...')]);
                  }),
                  _buildProfileItem(isDark, LucideIcons.scale, l10n.termsOfService, Colors.grey, onTap: () {
                    showAboutDialog(context: context, applicationName: 'BarberBook24', children: [Text(l10n.termsOfService + ' details...')]);
                  }),
                  _buildProfileItem(isDark, LucideIcons.trash2, l10n.deleteAccount, Colors.red, onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(l10n.deleteAccountConfirm),
                        content: Text(l10n.deleteAccountWarning),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
                          TextButton(
                            onPressed: () async {
                              await ref.read(userProvider.notifier).logout();
                              Navigator.pop(context);
                              context.go('/login');
                            },
                            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                
                const SizedBox(height: 40),
                InkWell(
                  onTap: () async {
                    await ref.read(userProvider.notifier).logout();
                    if (mounted) context.go('/login');
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(25),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.logOut, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.logoutSession, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 100), // Bottom padding
              ]),
            ),
          ),
        ],
      ),
    ),
  ),
],
);
}

  Widget _buildProfileCompletionMeter(bool isDark, AppLocalizations l10n) {
    // Calculate profile completion dynamically
    int completedItems = 0;
    int totalItems = 5;
    List<String> missingItems = [];
    
    // DEBUG: Print staff profile data
    print('[PROFILE_STRENGTH] Staff Profile Data: ${_staffProfile?.keys.toList()}');
    print('[PROFILE_STRENGTH] Photo: ${_staffProfile?['photo']}');
    print('[PROFILE_STRENGTH] ImageUrl: ${_staffProfile?['imageUrl']}');
    print('[PROFILE_STRENGTH] WorkPhotos: ${_staffProfile?['workPhotos']}');
    print('[PROFILE_STRENGTH] Description: ${_staffProfile?['description']}');
    print('[PROFILE_STRENGTH] Experience: ${_staffProfile?['experience']}');
    
    // Check profile photo
    final photoUrl = _staffProfile?['photo']?.toString() ?? '';
    final imageUrl = _staffProfile?['imageUrl']?.toString() ?? '';
    if ((photoUrl.isNotEmpty && photoUrl != 'null') || (imageUrl.isNotEmpty && imageUrl != 'null')) {
      completedItems++;
      print('[PROFILE_STRENGTH] ✅ Has profile photo');
    } else {
      missingItems.add(l10n.profilePhoto);
      print('[PROFILE_STRENGTH] ❌ Missing profile photo');
    }
    
    // Check bio/description
    if (_staffProfile?['description'] != null && _staffProfile!['description'].toString().isNotEmpty) {
      completedItems++;
      print('[PROFILE_STRENGTH] ✅ Has description');
    } else {
      missingItems.add(l10n.bio);
      print('[PROFILE_STRENGTH] ❌ Missing description');
    }
    
    // Check experience
    if (_staffProfile?['experience'] != null && (_staffProfile!['experience'] as int) > 0) {
      completedItems++;
      print('[PROFILE_STRENGTH] ✅ Has experience');
    } else {
      missingItems.add(l10n.experience);
      print('[PROFILE_STRENGTH] ❌ Missing experience');
    }
    
    // Check for work photos
    final workPhotos = _staffProfile?['workPhotos'] as List?;
    if (workPhotos != null && workPhotos.isNotEmpty) {
      completedItems++;
      print('[PROFILE_STRENGTH] ✅ Has work photos: ${workPhotos.length}');
    } else {
      missingItems.add(l10n.portfolioPhotos);
      print('[PROFILE_STRENGTH] ❌ Missing work photos');
    }
    
    // Check skills
    final skillsString = _staffProfile?['skills']?.toString() ?? '';
    if (skillsString.isNotEmpty) {
      completedItems++;
      print('[PROFILE_STRENGTH] ✅ Has skills: $skillsString');
    } else {
      missingItems.add(l10n.skills);
      print('[PROFILE_STRENGTH] ❌ Missing skills');
    }
    
    print('[PROFILE_STRENGTH] Total: $completedItems/$totalItems = ${(completedItems / totalItems * 100).round()}%');
    
    final completionPercent = (completedItems / totalItems * 100).round();
    final completionValue = completedItems / totalItems;
    
    // Generate helpful suggestion
    String suggestion = missingItems.isEmpty 
        ? l10n.profileCompleteSug 
        : l10n.profileIncompleteSug(missingItems.take(2).join(' & '));
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.profileCompletion, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("$completionPercent%", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.emerald, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(value: completionValue, backgroundColor: AppTheme.emerald.withOpacity(0.1), color: AppTheme.emerald, minHeight: 8),
          ),
          const SizedBox(height: 12),
          Text(suggestion, style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPerformanceSnapshot(bool isDark, AppLocalizations l10n) {
    // Get rating from staff profile, default to 0.0 if not available
    final rating = _staffProfile?['rating']?.toDouble() ?? 0.0;
    final reviewsCount = _staffProfile?['reviewsCount'] ?? 0;
    
    // Calculate on-time rate from appointments
    final completedCount = _appointments.where((a) => a.status == AppointmentStatus.completed).length;
    final missedCount = _appointments.where((a) => 
      a.status == AppointmentStatus.cancelledByCustomer || 
      a.status == AppointmentStatus.cancelledByBarber).length;
    final totalHandled = completedCount + missedCount;
    final onTimePercent = totalHandled > 0 ? ((completedCount / totalHandled) * 100).round() : 100;
    
    return Row(
      children: [
        _snapshotItem(isDark, rating.toStringAsFixed(1), l10n.avgRating, LucideIcons.star, Colors.amber),
        const SizedBox(width: 12),
        _snapshotItemTappable(
          isDark, 
          reviewsCount.toString(), 
          l10n.reviews, 
          LucideIcons.messageSquare, 
          Colors.blue,
          onTap: () {
            if (_staffProfile != null) {
              context.push('/staff-reviews', extra: _staffProfile!['id']);
            }
          },
        ),
        const SizedBox(width: 12),
        _snapshotItem(isDark, "$onTimePercent%", l10n.completed, LucideIcons.checkCircle, AppTheme.emerald),
      ],
    );
  }

  Widget _snapshotItem(bool isDark, String val, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 12),
            Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _snapshotItemTappable(bool isDark, String val, String label, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 12),
              Text(val, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildSkillsSection(bool isDark, AppLocalizations l10n) {
    // Get skills from profile, split by comma
    final skillsString = _staffProfile?['skills']?.toString() ?? '';
    final skills = skillsString.isNotEmpty 
        ? skillsString.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.skillsExpertise, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 16),
          skills.isEmpty
              ? Text(
                  l10n.noSkillsAdded,
                  style: TextStyle(
                    fontSize: 11,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: skills.map((s) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                    child: Text(s, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  )).toList(),
                ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityToggle(bool isDark, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(LucideIcons.calendarCheck, color: AppTheme.emerald, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.availableToday, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(l10n.instantlyAcceptBookings, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          Switch.adaptive(
            value: (_staffProfile != null) ? (_staffProfile!['isAvailable'] ?? true) : true, 
            activeColor: AppTheme.emerald, 
            onChanged: (v) async {
              if (_staffProfile == null) return;
              setState(() {
                _staffProfile!['isAvailable'] = v;
              });
              try {
                await ref.read(apiServiceProvider).updateStaffProfile(_staffProfile!['id'], {
                  'isAvailable': v,
                });
                _loadData(); // Refresh to ensure everything is in sync
              } catch (e) {
                print("Error updating availability: $e");
                // Rollback on error
                setState(() {
                  _staffProfile!['isAvailable'] = !v;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("${l10n.failedToUpdateAvailability}: $e"))
                );
              }
            },
          ),
        ],
      ),
    );
  }


  Widget _buildShopHeader(bool isDark, AppLocalizations l10n) {
    final user = ref.watch(userProvider);
    if (user == null) return const SizedBox.shrink();
    
    // Determine Display Info based on Role
    String mainTitle = user.role == AppRole.owner 
        ? (_shopProfile?['name'] ?? l10n.myShop) 
        : (user.name); // Staff Name for Barbers
        
    String subTitle = user.role == AppRole.owner 
        ? (_shopProfile?['address'] ?? l10n.noAddressSaved) 
        : (_staffProfile?['shop']?['name'] ?? l10n.noShopAssigned); // Shop Name for Barbers

    String? avatarPhotoUrl = user.profilePhoto;
    final shopPhotos = (_shopProfile?['photos'] as List?)?.cast<String>() ?? 
                       (_staffProfile?['shop']?['photos'] as List?)?.cast<String>() ?? [];
                       
    if (avatarPhotoUrl == null && user.role == AppRole.owner && shopPhotos.isNotEmpty) {
      avatarPhotoUrl = shopPhotos.first;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(40),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              UserAvatar(
                photoUrl: avatarPhotoUrl,
                name: user.name,
                radius: 60,
                fontSize: 40,
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: user.role == AppRole.owner ? Colors.blue : AppTheme.emerald, 
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF18181B) : Colors.white, width: 4),
                  ),
                  child: Icon(
                    user.role == AppRole.owner ? LucideIcons.shieldCheck : LucideIcons.scissors, 
                    color: Colors.white, 
                    size: 16
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(mainTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Opacity(opacity: 0.4, child: Text(subTitle.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2))),

          if (user.role == AppRole.barber) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _trustBadge(LucideIcons.checkCircle, l10n.verifiedByShop, Colors.blue),
                const SizedBox(width: 8),
                _trustBadge(LucideIcons.award, l10n.topRated, Colors.amber),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _trustBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(100), border: Border.all(color: color.withOpacity(0.1))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _buildProfileItem(bool isDark, IconData icon, String label, Color color, {String? subtitle, VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
            ],
          ),
        ),
      ),
    );
  }

  String _getCurrentLanguageName(Locale locale) {
    switch (locale.languageCode) {
      case 'en':
        return 'English';
      case 'hi':
        return 'हिंदी';
      case 'es':
        return 'Español';
      case 'ar':
        return 'العربية';
      default:
        return 'English';
    }
  }

  Widget _buildBottomNav(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withOpacity(0.95),
        border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(isDark, 0, LucideIcons.layoutDashboard, l10n.dashboard.toUpperCase()),
              _buildNavItem(isDark, 1, LucideIcons.checkSquare, l10n.appointments.toUpperCase()),
              _buildNavItem(isDark, 2, LucideIcons.wallet, l10n.earnings.toUpperCase()),
              _buildNavItem(isDark, 3, LucideIcons.store, l10n.profile.toUpperCase()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(bool isDark, int index, IconData icon, String label) {
    bool isActive = _currentIndex == index;
    Color color = isActive 
        ? (isDark ? AppTheme.darkAccent : AppTheme.lightAccent) 
        : (isDark ? Colors.white : Colors.black).withOpacity(0.4);

    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
  Widget _buildShopPhotos(bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    // ... existing implementation ...
     final shopPhotos = (_shopProfile?['photos'] as List?)?.cast<String>() ?? 
                       (_staffProfile?['shop']?['photos'] as List?)?.cast<String>() ?? [];

    if (shopPhotos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(l10n.shopGallery, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            padding: const EdgeInsets.only(right: 16),
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: shopPhotos.length,
            itemBuilder: (context, index) {
              final photo = shopPhotos[index];
              final resolvedPhoto = ref.read(apiServiceProvider).resolveUrl(photo);
              
              if (resolvedPhoto == null) return const SizedBox.shrink();

              return InkWell(
                  onTap: () => _showPhotoDialog(context, photo, isDark),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: resolvedPhoto.startsWith('http') 
                            ? NetworkImage(resolvedPhoto) as ImageProvider
                            : FileImage(File(resolvedPhoto)),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _showPhotoDialog(BuildContext context, String photoPath, bool isDark) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(20),
               child: () {
                 final resolvedDialogPhoto = ref.read(apiServiceProvider).resolveUrl(photoPath);
                 if (resolvedDialogPhoto == null) return const Icon(LucideIcons.imageOff, size: 50);
                 
                 return resolvedDialogPhoto.startsWith('http') 
                  ? Image.network(resolvedDialogPhoto) 
                  : Image.file(File(resolvedDialogPhoto));
               }(),
             ),
             const SizedBox(height: 16),
             // Only Owner can set Shop Photo as their profile photo from here
             if (ref.read(userProvider)?.role == AppRole.owner)
               ElevatedButton.icon(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppTheme.emerald,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                 ),
                 onPressed: () async {
                   try {
                       final user = ref.read(userProvider);
                       if (user == null) return;
                       final apiService = ref.read(apiServiceProvider);
                       
                       final updatedUser = await apiService.updateProfile(user.id, {
                           'profilePhoto': photoPath
                       });
  
                       if (updatedUser != null) {
                           await ref.read(userProvider.notifier).setUser(updatedUser);
                           if (mounted) {
                               Navigator.pop(context);
                               ScaffoldMessenger.of(context).showSnackBar(
                                   SnackBar(content: Text(l10n.profilePhotoUpdated))
                               );
                           }
                       }
                   } catch (e) {
                       print("Error updating profile photo: $e");
                   }
                 },
                 icon: const Icon(LucideIcons.userCheck),
                 label: Text(l10n.setAsProfilePhoto),
               ),
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: Text(l10n.close, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             )
          ],
        ),
      ),
    );
  }
}

class _NotificationsPopupContent extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final bool isDark;
  final VoidCallback onNotificationRead;

  const _NotificationsPopupContent({
    required this.scrollController,
    required this.isDark,
    required this.onNotificationRead,
  });

  @override
  ConsumerState<_NotificationsPopupContent> createState() => _NotificationsPopupContentState();
}

class _NotificationsPopupContentState extends ConsumerState<_NotificationsPopupContent> {
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
    if (user == null) return;
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

  bool _isNotificationRead(Map<String, dynamic> notif) {
    final isReadValue = notif['isRead'];
    return isReadValue == true || isReadValue == 'true' || isReadValue == 1;
  }

  Future<void> _markRead(String id) async {
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.markNotificationAsRead(id);
      // Optimistic update
      if (mounted) {
        setState(() {
          final index = _notifications.indexWhere((n) => n['id'] == id);
          if (index != -1 && !_isNotificationRead(_notifications[index])) {
            _notifications[index]['isRead'] = true;
            // Recalculate unread count
            final unreadCount = _notifications.where((n) => !_isNotificationRead(n)).length;
            ref.read(unreadNotificationCountProvider.notifier).state = unreadCount;
            widget.onNotificationRead();
          }
        });
      }
    } catch (e) {
      // Error handling - could show snackbar
    }
  }

  Future<void> _markAllNotificationsRead() async {
    final unreadNotifications = _notifications.where((n) => !_isNotificationRead(n)).toList();
    if (unreadNotifications.isEmpty) return;

    final apiService = ref.read(apiServiceProvider);
    
    // Optimistic update - mark all as read immediately
    if (mounted) {
      setState(() {
        for (var notif in _notifications) {
          if (!_isNotificationRead(notif)) {
            notif['isRead'] = true;
          }
        }
        ref.read(unreadNotificationCountProvider.notifier).state = 0;
      });
    }

    // Mark all as read in the background
    try {
      for (var notif in unreadNotifications) {
        await apiService.markNotificationAsRead(notif['id']);
      }
    } catch (e) {
      // If error occurs, reload notifications to sync state
      if (mounted) {
        _loadNotifications();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l10n.notifications,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Read All button - show if there are unread notifications
                  if (!_isLoading && _notifications.isNotEmpty)
                    Builder(
                      builder: (context) {
                        final hasUnread = _notifications.any((n) => !_isNotificationRead(n));
                        if (hasUnread) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: TextButton(
                              onPressed: () => _markAllNotificationsRead(), 
                              child: Text(l10n.readAll, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold))
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  IconButton(
                    icon: const Icon(LucideIcons.x),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
                  ? Center(
                      child: Text(
                        "No notifications",
                        style: TextStyle(
                          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4),
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        controller: widget.scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) => _buildNotificationCard(_notifications[index]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final isRead = _isNotificationRead(notif);

    return InkWell(
      onTap: () => !isRead ? _markRead(notif['id']) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: widget.isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(24),
          border: !isRead ? Border.all(color: AppTheme.emerald, width: 1) : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isRead
                        ? (widget.isDark ? Colors.white : Colors.black)
                        : AppTheme.emerald)
                    .withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.bell,
                size: 20,
                color: isRead
                    ? (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4)
                    : AppTheme.emerald,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notif['title'],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isRead ? null : AppTheme.emerald,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notif['body'],
                    style: TextStyle(
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    notif['createdAt'].toString().substring(0, 10),
                    style: TextStyle(
                      fontSize: 10,
                      color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.3),
                    ),
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
