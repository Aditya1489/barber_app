import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';

class StaffManagementScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const StaffManagementScreen({super.key, required this.shopData});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  List<dynamic> _staffList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStaff();
  }

  Future<void> _loadStaff() async {
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    try {
      final staff = await apiService.getShopStaff(widget.shopData['id']);
      if (mounted) {
        setState(() {
          _staffList = staff;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading staff: $e')),
        );
      }
    }
  }

  void _showAddStaffSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
         decoration: BoxDecoration(
          color: ref.watch(themeProvider) ? AppTheme.darkCardBG : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add Staff Member', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                filled: true,
                fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Phone Number',
                filled: true,
                fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email (Optional)',
                filled: true,
                fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _createStaff(nameController.text, phoneController.text, emailController.text);
                  }
                },
                child: const Text('Create User', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createStaff(String name, String phone, String email) async {
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    try {
      await apiService.createStaffForShop(widget.shopData['id'], {
        'name': name,
        'phone': phone,
        'email': email.isEmpty ? null : email,
      });
      _loadStaff();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeStaff(String staffId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Staff Member?'),
        content: const Text('This action cannot be undone. The staff member will be removed from your shop.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final success = await apiService.removeStaffFromShop(widget.shopData['id'], staffId);
      if (mounted) {
        if (success) {
          _loadStaff();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove staff. Please try again.'))
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      extendBody: true,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddStaffSheet,
        backgroundColor: AppTheme.emerald,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text('Add Staff', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _staffList.isEmpty 
                    ? Center(child: Text('No staff members found', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _staffList.length,
                        itemBuilder: (context, index) => _buildStaffCard(isDark, _staffList[index]),
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
            'Staff Management',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffCard(bool isDark, Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(
              staff['imageUrl'] != null && staff['imageUrl'].toString().isNotEmpty
                  ? (staff['imageUrl'].toString().startsWith('http')
                      ? staff['imageUrl']
                      : 'http://192.168.0.100:8000${staff['imageUrl']}')
                  : "https://picsum.photos/200/200"
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(staff['role'] ?? 'Staff', style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
               // Owner viewing staff profile
               context.push('/staff-preview', extra: staff);
            },
            icon: Icon(LucideIcons.eye, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
          ),
          IconButton(
            onPressed: () => _removeStaff(staff['id']),
            icon: const Icon(LucideIcons.userMinus, size: 20, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
