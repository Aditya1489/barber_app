import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:intl/intl.dart';

class BusinessAnalyticsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const BusinessAnalyticsScreen({super.key, required this.shopData});

  @override
  ConsumerState<BusinessAnalyticsScreen> createState() => _BusinessAnalyticsScreenState();
}

class _BusinessAnalyticsScreenState extends ConsumerState<BusinessAnalyticsScreen> {
  Map<String, dynamic>? _analytics;
  bool _isLoading = true;
  String _period = 'daily';

  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    final apiService = ref.read(apiServiceProvider);
    try {
      final analytics = await apiService.getOwnerAnalytics(user.id, period: _period, shopId: widget.shopData['id']);
      if (mounted) {
        setState(() {
          _analytics = analytics;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          _buildPeriodSelector(isDark),
                          const SizedBox(height: 24),
                          _buildOverviewGrid(isDark),
                          const SizedBox(height: 32),
                          _buildStaffPerformance(isDark),
                        ],
                      ),
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
          Text(
            'Business Analytics',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: ['Daily', 'Weekly', 'Monthly'].map((p) => Expanded(
          child: InkWell(
            onTap: () {
                setState(() => _period = p.toLowerCase());
                _loadAnalytics();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _period == p.toLowerCase() ? (isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  p.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: _period == p.toLowerCase() ? (isDark ? Colors.white : Colors.black) : (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                  ),
                ),
              ),
            ),
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildOverviewGrid(bool isDark) {
    if (_analytics == null) return const SizedBox.shrink();

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildStatCard(isDark, 'Total Appointments', _analytics!['totalAppointments'].toString(), Colors.blue)),
            const SizedBox(width: 16),
            Expanded(child: _buildStatCard(isDark, 'Completed', _analytics!['completedCount'].toString(), AppTheme.emerald)),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatCard(isDark, 'Total Revenue', NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString(), decimalDigits: 0).format(double.tryParse(_analytics!['totalRevenue'].toString()) ?? 0), Colors.amber, isFullWidth: true),
      ],
    );
  }

  Widget _buildStatCard(bool isDark, String label, String value, Color color, {bool isFullWidth = false}) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }

  Widget _buildStaffPerformance(bool isDark) {
    if (_analytics == null) return const SizedBox.shrink();
    final staffStats = (_analytics!['staffPerformance'] as List?);

    if (staffStats == null || staffStats.isEmpty) return const SizedBox.shrink();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            const Text('Staff Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            ...staffStats.map((s) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                    borderRadius: BorderRadius.circular(20)
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        Text(s['staffName'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(NumberFormat.simpleCurrency(locale: Localizations.localeOf(context).toString(), decimalDigits: 0).format(double.tryParse(s['totalEarnings'].toString()) ?? 0), style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald)),
                    ],
                )
            )).toList()
        ],
    );
  }
}
