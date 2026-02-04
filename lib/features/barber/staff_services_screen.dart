import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:flutter/services.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StaffServicesScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> staffData;

  const StaffServicesScreen({super.key, required this.staffData});

  @override
  ConsumerState<StaffServicesScreen> createState() => _StaffServicesScreenState();
}

class _StaffServicesScreenState extends ConsumerState<StaffServicesScreen> {
  bool _isLoading = true;
  List<dynamic> _allShopServices = [];
  List<String> _selectedServiceIds = [];
  List<String> _initialSelectedServiceIds = [];
  late String _staffId;

  bool get _hasChanges {
    if (_selectedServiceIds.length != _initialSelectedServiceIds.length) return true;
    for (int i = 0; i < _selectedServiceIds.length; i++) {
      if (_selectedServiceIds[i] != _initialSelectedServiceIds[i]) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _staffId = widget.staffData['staffId'] ?? widget.staffData['id'];
    _loadData();
  }

  Future<void> _loadData() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final profile = await apiService.getStaffProfile(_staffId);
      
      if (profile != null) {
        if (profile['services'] != null) {
          _selectedServiceIds = List<String>.from(profile['services']);
          _initialSelectedServiceIds = List<String>.from(profile['services']);
        }
        
        final shopData = profile['shop'];
        if (shopData != null) {
          if (shopData['services'] != null && (shopData['services'] as List).isNotEmpty) {
            if (mounted) {
              setState(() {
                _allShopServices = shopData['services'];
                // Sort services so that selected ones are at the top or follow the saved order
                _sortServices();
                _isLoading = false;
              });
            }
          } 
          else if (shopData['id'] != null) {
            final services = await apiService.getShopServices(shopData['id']);
            if (mounted) {
              setState(() {
                _allShopServices = services;
                _sortServices();
                _isLoading = false;
              });
            }
          } else {
             if (mounted) setState(() => _isLoading = false);
          }
        } else {
          if (mounted) setState(() => _isLoading = false);
        }
      } else {
         if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _sortServices() {
    // Put selected services first in the order they were selected, then the rest
    final selected = <dynamic>[];
    final unselected = <dynamic>[];
    
    // First, maintain order of selected IDs if they exist in all services
    for (var id in _selectedServiceIds) {
      final s = _allShopServices.firstWhere((element) => element['id'] == id, orElse: () => null);
      if (s != null) selected.add(s);
    }
    
    // Then add everything else
    for (var s in _allShopServices) {
      if (!_selectedServiceIds.contains(s['id'])) unselected.add(s);
    }
    
    _allShopServices = [...selected, ...unselected];
  }

  Future<void> _saveServices() async {
    if (!_hasChanges) return;
    
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      await apiService.updateStaffProfile(_staffId, {
        'services': _selectedServiceIds,
      });
      
      if (mounted) {
        HapticFeedback.mediumImpact();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: const [
                Icon(LucideIcons.checkCircle2, color: Colors.white, size: 20),
                SizedBox(width: 12),
                Text("Services updated successfully!", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          )
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"))
        );
      }
    }
  }

  void _syncSelectedOrder() {
    final newSelected = <String>[];
    for (var s in _allShopServices) {
      if (_selectedServiceIds.contains(s['id'])) {
        newSelected.add(s['id']);
      }
    }
    _selectedServiceIds = newSelected;
  }

  Widget _getServiceIcon(String name, bool isDark) {
    IconData iconData = LucideIcons.scissors;
    Color color = AppTheme.emerald;
    
    final n = name.toLowerCase();
    if (n.contains('beard') || n.contains('shave')) {
      iconData = LucideIcons.user; // Closest to face grooming
      color = Colors.orange;
    } else if (n.contains('facial') || n.contains('mask')) {
      iconData = LucideIcons.sparkles;
      color = Colors.purple;
    } else if (n.contains('spa') || n.contains('massage')) {
      iconData = LucideIcons.flower;
      color = Colors.pink;
    } else if (n.contains('trim') && !n.contains('hair')) {
      iconData = LucideIcons.ruler;
      color = Colors.blue;
    }

    return Container(
      width: 52, height: 52,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : _allShopServices.isEmpty 
                        ? _buildEmptyState(isDark)
                        : ReorderableListView.builder(
                            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100),
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (newIndex > oldIndex) newIndex -= 1;
                                final item = _allShopServices.removeAt(oldIndex);
                                _allShopServices.insert(newIndex, item);
                                _syncSelectedOrder();
                                HapticFeedback.selectionClick();
                              });
                            },
                            itemCount: _allShopServices.length,
                            itemBuilder: (context, index) {
                              final service = _allShopServices[index];
                              final isSelected = _selectedServiceIds.contains(service['id']);
                              final apiService = ref.read(apiServiceProvider);
                              final imageUrl = apiService.resolveUrl(service['imageUrl']);

                              return Animate(
                                key: ValueKey(service['id'].toString()),
                                effects: [FadeEffect(delay: Duration(milliseconds: 50 * index))],
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.03), blurRadius: 10, offset: const Offset(0, 4))
                                    ],
                                    border: Border.all(
                                      color: isSelected ? AppTheme.emerald.withOpacity(0.5) : Colors.transparent,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Theme(
                                    data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          imageUrl != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(16),
                                                  child: Image.network(imageUrl, width: 52, height: 52, fit: BoxFit.cover)
                                                )
                                              : _getServiceIcon(service['name'], isDark),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  service['name'],
                                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  "${service['name'].toString().split(' ').first} · ${service['price'] > 50 ? 'Premium' : 'Standard'}",
                                                  style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    Icon(LucideIcons.clock, size: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3)),
                                                    const SizedBox(width: 4),
                                                    Text("${service['duration']}m", style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                                                    const SizedBox(width: 12),
                                                    Text("\$${service['price']}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.emerald)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Column(
                                                mainAxisSize: MainAxisSize.min,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Switch.adaptive(
                                                    value: isSelected,
                                                    activeColor: AppTheme.emerald,
                                                    onChanged: (val) {
                                                      setState(() {
                                                        if (val) {
                                                          _selectedServiceIds.add(service['id'] as String);
                                                        } else {
                                                          _selectedServiceIds.remove(service['id']);
                                                        }
                                                        HapticFeedback.selectionClick();
                                                      });
                                                    },
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    isSelected ? "AVAILABLE" : "DISABLED",
                                                    style: TextStyle(
                                                      fontSize: 8, 
                                                      fontWeight: FontWeight.w900, 
                                                      color: isSelected ? AppTheme.emerald : Colors.grey,
                                                      letterSpacing: 0.5
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(LucideIcons.gripVertical, size: 20, color: (isDark ? Colors.white54 : Colors.grey.withOpacity(0.3))),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
              if (!_isLoading && _allShopServices.isNotEmpty)
                _buildStickySave(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.05), shape: BoxShape.circle),
            child: const Icon(LucideIcons.scissors, size: 64, color: AppTheme.emerald),
          ),
          const SizedBox(height: 24),
          const Text("No services found", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(
            "Contact your shop owner to add\nmaster services to the list.",
            textAlign: TextAlign.center,
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), height: 1.5),
          ),
        ],
      ).animate().fadeIn(),
    );
  }

  Widget _buildStickySave(bool isDark) {
    final hasChanges = _hasChanges;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
             (isDark ? const Color(0xFF0C0C0E) : Colors.white).withOpacity(0.0),
             isDark ? const Color(0xFF0C0C0E) : Colors.white,
          ],
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 64,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: hasChanges ? AppTheme.emerald : (isDark ? Colors.white10 : Colors.black12),
            disabledBackgroundColor: isDark ? Colors.white10 : Colors.black12,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: hasChanges ? 8 : 0,
            shadowColor: AppTheme.emerald.withOpacity(0.4),
          ),
          onPressed: hasChanges ? _saveServices : null,
          child: Text(
            hasChanges ? "SAVE CHANGES" : "NOTHING TO SAVE",
            style: TextStyle(
              color: hasChanges ? Colors.white : Colors.grey, 
              fontWeight: FontWeight.w900, 
              letterSpacing: 1.5,
              fontSize: 14
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: 0.1);
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
            "My Services",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
