import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';

class ManageServicesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const ManageServicesScreen({super.key, required this.shopData});

  @override
  ConsumerState<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends ConsumerState<ManageServicesScreen> {
  List<dynamic> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    try {
      final services = await apiService.getShopServices(widget.shopData['id']);
      if (mounted) {
        setState(() {
          _services = services;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading services: $e')),
        );
      }
    }
  }

  void _showServiceSheet({Map<String, dynamic>? service}) {
    final nameController = TextEditingController(text: service?['name']);
    final priceController = TextEditingController(text: service?['price']?.toString());
    final durationController = TextEditingController(text: service?['duration']?.toString());
    
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
            Text(
              service == null ? "Add Service" : "Edit Service",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Service Name",
                filled: true,
                fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Price (\$)",
                      filled: true,
                      fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: durationController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Duration (min)",
                      filled: true,
                      fillColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
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
                  if (nameController.text.isNotEmpty && priceController.text.isNotEmpty) {
                    Navigator.pop(context);
                    await _saveService(
                      serviceId: service?['id'],
                      name: nameController.text,
                      price: double.parse(priceController.text),
                      duration: int.parse(durationController.text),
                    );
                  }
                },
                child: const Text("Save Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveService({String? serviceId, required String name, required double price, required int duration}) async {
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    try {
      if (serviceId != null) {
        await apiService.updateService(widget.shopData['id'], serviceId, {
          'name': name,
          'price': price,
          'duration': duration,
        });
      } else {
        await apiService.addService(widget.shopData['id'], {
          'name': name,
          'price': price,
          'duration': duration,
          'imageUrl': 'https://picsum.photos/400/300' // Mock for now
        });
      }
      _loadServices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteService(String serviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Service?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      final success = await apiService.deleteService(widget.shopData['id'], serviceId);
      if (mounted) {
        if (success) {
          _loadServices();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete service. Please try again.'))
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
        onPressed: () => _showServiceSheet(),
        backgroundColor: AppTheme.emerald,
        icon: const Icon(LucideIcons.plus, color: Colors.white),
        label: const Text("Add Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
                  : _services.isEmpty 
                    ? Center(child: Text("No services found", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))))
                    : ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: _services.length,
                        itemBuilder: (context, index) => _buildServiceCard(isDark, _services[index]),
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
            "Manage Services",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(bool isDark, Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: const Icon(LucideIcons.scissors, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text("${service['duration']} mins • \$${service['price']}", style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showServiceSheet(service: service),
            icon: Icon(LucideIcons.edit3, size: 20, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
          ),
          IconButton(
            onPressed: () => _deleteService(service['id']),
            icon: const Icon(LucideIcons.trash2, size: 20, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
