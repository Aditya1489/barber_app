import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/models/models.dart';

class BarberDashboardScreen extends ConsumerStatefulWidget {
  const BarberDashboardScreen({super.key});

  @override
  ConsumerState<BarberDashboardScreen> createState() => _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends ConsumerState<BarberDashboardScreen> {
  int _currentIndex = 0;
  String _filterPeriod = 'Daily';
  
  Map<String, dynamic>? _analytics;
  List<Appointment> _appointments = [];
  Map<String, dynamic>? _staffProfile;
  Map<String, dynamic>? _shopProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    final apiService = ref.read(apiServiceProvider);

    try {
      if (user.role == AppRole.owner) {
        final results = await Future.wait([
          apiService.getOwnerAnalytics(user.id, period: _filterPeriod),
          apiService.getAppointments(user.id), // Fetching all appointments for now
          apiService.getShopsByOwner(user.id),
        ]);
        _analytics = results[0] as Map<String, dynamic>?;
        _appointments = results[1] as List<Appointment>;
        final shops = results[2] as List<dynamic>;
        if (shops.isNotEmpty) {
          _shopProfile = Map<String, dynamic>.from(shops.first as Map);
        }
      } else {
        // Barber role
        final results = await Future.wait([
          apiService.getStaffEarnings(user.id, period: _filterPeriod),
          apiService.getAppointments(user.id),
          apiService.getStaffProfile(user.id),
        ]);
        _analytics = results[0] as Map<String, dynamic>?;
        _appointments = results[1] as List<Appointment>;
        _staffProfile = results[2] as Map<String, dynamic>?;
        
        // Sync Profile Photo to UserProvider to ensure Header updates immediately
        if (_staffProfile != null) {
          final photo = _staffProfile!['photo'] ?? _staffProfile!['imageUrl'];
          if (photo != null && photo != user.profilePhoto) {
             // Defer update to avoid build conflicts
             Future.microtask(() {
                ref.read(userProvider.notifier).state = user.copyWith(profilePhoto: photo);
             });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading dashboard: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    
    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: Column(
          children: [
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator()) 
                : RefreshIndicator(
                    onRefresh: _loadData,
                    child: _buildBody(isDark),
                  ),
            ),
            _buildBottomNav(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    switch (_currentIndex) {
      case 0:
        return _buildDashboardTab(isDark);
      case 1:
        return _buildTasksTab(isDark);
      case 2:
        return _buildEarningsTab(isDark);
      case 3:
        return _buildProfileTab(isDark);
      default:
        return const SizedBox();
    }
  }

  Widget _buildDashboardTab(bool isDark) {
    final user = ref.watch(userProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 60, 16, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Welcome back,",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                      letterSpacing: 2,
                    ),
                  ),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.bell, size: 20),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPeriodFilter(isDark),
                const SizedBox(height: 24),
                _buildStatsGrid(isDark),
                const SizedBox(height: 32),
                _buildRecentRequests(isDark),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodFilter(bool isDark) {
    final periods = ['Daily', 'Weekly', 'Monthly', 'Yearly'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: periods.map((p) => Expanded(
          child: InkWell(
            onTap: () {
              setState(() => _filterPeriod = p);
              _loadData();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: _filterPeriod == p ? (isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  p.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _filterPeriod == p ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(bool isDark) {
    String totalAppts = _analytics?['totalAppointments']?.toString() ?? "0";
    String completedAppts = _analytics?['completedCount']?.toString() ?? 
                            _analytics?['tasksCompleted']?.toString() ?? "0";
    String earnings = "\$${_analytics?['totalRevenue'] ?? _analytics?['totalEarnings'] ?? "0"}";

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(isDark, "Appointments", totalAppts, LucideIcons.scissors, Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(isDark, "Completed", completedAppts, LucideIcons.layout, AppTheme.emerald)),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(isDark, "Total Earnings", earnings, LucideIcons.dollarSign, Colors.amber),
      ],
    );
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
    final pendingAppts = _appointments.where((a) => a.status == AppointmentStatus.pending).toList();

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Recent Requests", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text("View All", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.darkAccent)),
          ],
        ),
        const SizedBox(height: 16),
        if (pendingAppts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text("No pending requests", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          )
        else
          ...pendingAppts.map((appt) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildRequestCard(isDark, "Customer", "${appt.services.length} Services • ${appt.timeSlot}", "https://picsum.photos/100/100?random=${appt.id.hashCode}"),
          )).toList(),
      ],
    );
  }

  Widget _buildRequestCard(bool isDark, String name, String detail, String image) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(image, width: 48, height: 48, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(detail, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          Row(
            children: [
              _buildIconButton(LucideIcons.plus, AppTheme.emerald),
              const SizedBox(width: 8),
              _buildIconButton(LucideIcons.trash2, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }

  Widget _buildTasksTab(bool isDark) {
    final activeAppts = _appointments.where((a) => a.status == AppointmentStatus.accepted).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Text("Tasks & Schedule", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Expanded(
            child: activeAppts.isEmpty 
              ? Center(child: Text("No tasks for today", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
              : ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: activeAppts.length,
                  itemBuilder: (context, index) => _buildTaskCard(isDark, activeAppts[index], index),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(bool isDark, Appointment appt, int index) {
    bool isCurrent = index == 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.amber : Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text("${appt.timeSlot}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isCurrent ? Colors.amber : Colors.blue).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCurrent ? "CURRENT" : "UPCOMING",
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.amber : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network("https://picsum.photos/100/100?random=${appt.id.hashCode}", width: 56, height: 56, fit: BoxFit.cover),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Customer", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text("${appt.services.length} Services", style: TextStyle(fontSize: 13, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Text("MARK COMPLETED", style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.clock, size: 18, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTab(bool isDark) {
    String earnings = "\$${_analytics?['totalRevenue'] ?? _analytics?['totalEarnings'] ?? "0"}";

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 60),
          const Text("Earnings Insight", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceCard(isDark, earnings),
                  const SizedBox(height: 48),
                  const Text("Performance Analytics", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  _buildAnalyticsItem(isDark, "Completion Rate", 0.92, "92%", Colors.blue),
                  const SizedBox(height: 16),
                  _buildAnalyticsItem(isDark, "New Clients", 0.65, "24", AppTheme.emerald),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(bool isDark, String earnings) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Text(
            "Available Leverage".toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 8),
          Text(earnings, style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900)),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkButton,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            onPressed: () {},
            child: const Text("WITHDRAW FUNDS", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsItem(bool isDark, String label, double value, String trailing, Color color) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        children: [
          Icon(label.contains("Rate") ? LucideIcons.barChart3 : LucideIcons.users, color: color, size: 24),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: value,
                    backgroundColor: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                    color: color,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Text(trailing, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildProfileTab(bool isDark) {
    final user = ref.watch(userProvider);
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 60),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(user.role == AppRole.owner ? "Owner Profile" : "Barber Profile", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
              InkWell(
                onTap: () => ref.read(themeProvider.notifier).state = !isDark,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(isDark ? LucideIcons.sun : LucideIcons.moon, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildShopHeader(isDark),
          const SizedBox(height: 24),
          if (user.role == AppRole.owner) _buildShopPhotos(isDark),
          if (user.role == AppRole.owner) 
          _buildProfileItem(
            isDark, 
            LucideIcons.store, 
            "Shop Settings", 
            Colors.blue,
            onTap: () async {
              if (_shopProfile != null) {
                await context.push('/shop-settings', extra: _shopProfile); 
                _loadData();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("No shop profile found. Please create a shop first."))
                );
              }
            }
          )
          else 
            _buildProfileItem(
            isDark, 
            LucideIcons.user, 
            "Personal Profile", 
            Colors.blue,
            onTap: () async {
                // Navigate to a profile edit screen 
                if (_staffProfile != null) {
                  await context.push('/staff-profile-edit', extra: _staffProfile);
                  // Reload data to get updated profile photo
                  _loadData();
                }
            }
          ),
          if (user.role == AppRole.owner) ...[
            _buildProfileItem(
              isDark, 
              LucideIcons.scissors, 
              "Manage Services", 
              Colors.red,
              onTap: () {
                 if (_shopProfile != null) {
                  context.push('/manage-services', extra: _shopProfile);
                } else {
                   ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No shop profile found."))
                  );
                }
              }
            ),
            _buildProfileItem(
              isDark, 
              LucideIcons.users, 
              "Staff Management", 
              AppTheme.emerald,
              onTap: () {
                if (_shopProfile != null) {
                  context.push('/staff-management', extra: _shopProfile); 
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No shop profile found.")));
                }
              }
            ),
             _buildProfileItem(
              isDark, 
              LucideIcons.barChart3, 
              "Business Analytics", 
              Colors.deepPurple,
              onTap: () {
                 if (_shopProfile != null) {
                  context.push('/business-analytics', extra: _shopProfile); 
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No shop profile found.")));
                }
              }
            ),
          ],
          _buildProfileItem(
            isDark, 
            LucideIcons.bell, 
            "Notifications", 
            Colors.amber,
            onTap: () => context.push('/notifications')
          ),

          // Preview Options based on Role
          if (user.role == AppRole.barber) ...[
             _buildProfileItem(
              isDark, 
              LucideIcons.store, 
              "Preview Shop Profile", 
              Colors.teal,
              onTap: () {
                 if (_staffProfile != null && _staffProfile!['shop'] != null) {
                    context.push('/shop-preview', extra: _staffProfile!['shop']); 
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shop data not available.")));
                 }
              }
            ),
             _buildProfileItem(
              isDark, 
              LucideIcons.eye, 
              "Preview My Profile", 
              Colors.teal,
              onTap: () {
                 if (_staffProfile != null) {
                    context.push('/staff-preview', extra: _staffProfile);
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile data not ready.")));
                 }
              }
            ),
          ] else ...[
             _buildProfileItem(
              isDark, 
              LucideIcons.eye, 
              "Preview Shop Profile", 
              Colors.teal,
              onTap: () {
                 if (_shopProfile != null) {
                    context.push('/shop-preview', extra: _shopProfile); 
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shop data not available.")));
                 }
              }
            ),
          ],
          const SizedBox(height: 40),
          InkWell(
            onTap: () => context.go('/login'),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.logOut, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Text("LOGOUT SESSION", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 120), // Extra space for bottom nav since it's extended
        ],
      ),
    );
  }

  Widget _buildShopHeader(bool isDark) {
    final user = ref.watch(userProvider);
    
    // Determine Display Info based on Role
    String mainTitle = user.role == AppRole.owner 
        ? (_shopProfile?['name'] ?? "My Shop") 
        : (user.name); // Staff Name for Barbers
        
    String subTitle = user.role == AppRole.owner 
        ? (_shopProfile?['address'] ?? "No Address Saved") 
        : (_staffProfile?['shop']?['name'] ?? "No Shop Assigned"); // Shop Name for Barbers

    final shopPhotos = (_shopProfile?['photos'] as List?)?.cast<String>() ?? 
                       (_staffProfile?['shop']?['photos'] as List?)?.cast<String>() ?? [];
    
    ImageProvider imageProvider;
    
    // 1. Always Prioritize User's Personal Profile Photo (Owner OR Staff)
    if (user.profilePhoto != null && user.profilePhoto!.isNotEmpty) {
       if (user.profilePhoto!.startsWith('http')) {
         imageProvider = NetworkImage(user.profilePhoto!);
       } else {
         imageProvider = FileImage(File(user.profilePhoto!));
       }
    } 
    // 2. Fallback for Owner: Use First Shop Photo if no specific profile photo set
    else if (user.role == AppRole.owner && shopPhotos.isNotEmpty) {
       final firstPhoto = shopPhotos.first;
       imageProvider = firstPhoto.startsWith('http') 
          ? NetworkImage(firstPhoto) 
          : FileImage(File(firstPhoto)) as ImageProvider;
    } 
    // 3. Last Result: Use Default Avatar
    else {
       imageProvider = const NetworkImage("https://picsum.photos/400/400?random=20");
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
              ClipRRect(
                borderRadius: BorderRadius.circular(60),
                child: Image(image: imageProvider, width: 120, height: 120, fit: BoxFit.cover),
              ),
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: user.role == AppRole.owner ? Colors.blue : AppTheme.emerald, 
                    shape: BoxShape.circle
                  ),
                  child: Icon(
                    user.role == AppRole.owner ? LucideIcons.store : LucideIcons.user, 
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
        ],
      ),
    );
  }

  Widget _buildProfileItem(bool isDark, IconData icon, String label, Color color, {VoidCallback? onTap}) {
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
              Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
              Icon(LucideIcons.chevronRight, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
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
              _buildNavItem(isDark, 0, LucideIcons.layoutDashboard, "DASHBOARD"),
              _buildNavItem(isDark, 1, LucideIcons.checkSquare, "TASKS"),
              _buildNavItem(isDark, 2, LucideIcons.wallet, "EARNINGS"),
              _buildNavItem(isDark, 3, LucideIcons.store, "PROFILE"),
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
    // ... existing implementation ...
     final shopPhotos = (_shopProfile?['photos'] as List?)?.cast<String>() ?? 
                       (_staffProfile?['shop']?['photos'] as List?)?.cast<String>() ?? [];

    if (shopPhotos.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text("Shop Gallery", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
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
              return InkWell(
                  onTap: () => _showPhotoDialog(context, photo, isDark),
                  child: Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      image: DecorationImage(
                        image: photo.startsWith('http') 
                            ? NetworkImage(photo) as ImageProvider
                            : FileImage(File(photo)),
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             ClipRRect(
               borderRadius: BorderRadius.circular(20),
               child: photoPath.startsWith('http') 
                ? Image.network(photoPath) 
                : Image.file(File(photoPath)),
             ),
             const SizedBox(height: 16),
             // Only Owner can set Shop Photo as their profile photo from here
             if (ref.read(userProvider).role == AppRole.owner)
               ElevatedButton.icon(
                 style: ElevatedButton.styleFrom(
                   backgroundColor: AppTheme.emerald,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                 ),
                 onPressed: () async {
                   try {
                      final user = ref.read(userProvider);
                      final apiService = ref.read(apiServiceProvider);
                      
                      final updatedUser = await apiService.updateProfile(user.id, {
                          'profilePhoto': photoPath
                      });
  
                      if (updatedUser != null) {
                          ref.read(userProvider.notifier).state = updatedUser;
                          if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Profile photo updated!"))
                              );
                          }
                      }
                   } catch (e) {
                       print("Error updating profile photo: $e");
                   }
                 },
                 icon: const Icon(LucideIcons.userCheck),
                 label: const Text("Set as Profile Photo"),
               ),
             TextButton(
               onPressed: () => Navigator.pop(context),
               child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
             )
          ],
        ),
      ),
    );
  }
}
