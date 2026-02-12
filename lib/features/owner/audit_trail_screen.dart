import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:intl/intl.dart';

class AuditTrailScreen extends ConsumerStatefulWidget {
  const AuditTrailScreen({super.key});

  @override
  ConsumerState<AuditTrailScreen> createState() => _AuditTrailScreenState();
}

class _AuditTrailScreenState extends ConsumerState<AuditTrailScreen> {
  List<Map<String, dynamic>> _auditLogs = [];
  bool _isLoading = true;
  String? _selectedActionType;
  String? _selectedShopId;
  
  final List<String> _actionTypes = [
    'All Actions',
    'booking_override',
    'price_change',
    'staff_disable',
    'settings_update',
    'service_delete',
  ];

  @override
  void initState() {
    super.initState();
    _loadAuditTrail();
  }

  Future<void> _loadAuditTrail() async {
    setState(() => _isLoading = true);
    final user = ref.read(userProvider);
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final logs = await apiService.getAuditTrail(
        ownerId: user.id,
        shopId: _selectedShopId,
        actionType: (_selectedActionType == null || _selectedActionType == 'All Actions') ? null : _selectedActionType,
      );
      
      if (mounted) {
        setState(() {
          _auditLogs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit trail: $e')),
        );
      }
    }
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
              _buildFilters(isDark),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _auditLogs.isEmpty
                        ? _buildEmptyState(isDark)
                        : _buildAuditList(isDark),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audit Trail',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                Text(
                  'Track changes and sensitive actions',
                  style: TextStyle(
                    fontSize: 12,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                borderRadius: BorderRadius.circular(16),
              ),
              child: PopupMenuButton<String>(
                initialValue: _selectedActionType ?? 'All Actions',
                onSelected: (value) {
                  setState(() => _selectedActionType = value);
                  _loadAuditTrail();
                },
                offset: const Offset(0, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
                itemBuilder: (context) => _actionTypes.map((type) {
                  final displayLabel = type == 'All Actions' ? 'All Actions' : _formatActionType(type);
                  return PopupMenuItem<String>(
                    value: type,
                    child: Text(
                      displayLabel,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  );
                }).toList(),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedActionType == null || _selectedActionType == 'All Actions' 
                          ? 'All Actions' 
                          : _formatActionType(_selectedActionType!),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(LucideIcons.chevronDown, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAuditTrail,
      color: isDark ? AppTheme.emerald : Colors.blue,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.6,
          alignment: Alignment.center,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                LucideIcons.fileSearch,
                size: 64,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No audit logs found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Actions performed by you or your staff will appear here.',
                style: TextStyle(
                  fontSize: 14,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuditList(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadAuditTrail,
      color: isDark ? AppTheme.emerald : Colors.blue,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: _auditLogs.length,
        itemBuilder: (context, index) => _buildAuditCard(isDark, _auditLogs[index]),
      ),
    );
  }

  Widget _buildAuditCard(bool isDark, Map<String, dynamic> log) {
    final timestamp = DateTime.parse(log['timestamp'] ?? log['createdAt']);
    final actorRole = log['actorRole'] ?? 'SYSTEM';
    final actionType = log['actionType'];
    final entityType = log['entityType'];
    final reason = log['reason'];
    
    // Determine icon and color based on action type
    IconData icon;
    Color color;
    
    switch (actionType) {
      case 'booking_override':
        icon = LucideIcons.userCheck;
        color = Colors.blue;
        break;
      case 'price_change':
        icon = LucideIcons.dollarSign;
        color = Colors.amber;
        break;
      case 'staff_disable':
        icon = LucideIcons.userX;
        color = Colors.red;
        break;
      case 'settings_update':
        icon = LucideIcons.settings;
        color = Colors.purple;
        break;
      case 'service_delete':
        icon = LucideIcons.trash2;
        color = Colors.red;
        break;
      default:
        icon = LucideIcons.fileText;
        color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatActionType(actionType),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTimestamp(timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              _buildRoleBadge(actorRole, isDark),
            ],
          ),
          
          // Action Details
          if (log['details'] != null && (log['details'] as Map).isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildActionDetails(isDark, actionType, Map<String, dynamic>.from(log['details'])),
          ],
          
          // Reason (if provided)
          if (reason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.messageSquare,
                    size: 14,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 12,
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Entity info
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                LucideIcons.tag,
                size: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
              const SizedBox(width: 6),
              Text(
                'Entity: ${_formatEntityType(entityType)}',
                style: TextStyle(
                  fontSize: 11,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                LucideIcons.hash,
                size: 12,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.4),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ID: ${log['entityId']?.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 11,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionDetails(bool isDark, String actionType, Map<String, dynamic> details) {
    if (actionType == 'price_change') {
      final serviceName = details['serviceName'] ?? 'Unknown Service';
      final oldPrice = details['oldPrice'];
      final newPrice = details['newPrice'];
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Service: $serviceName',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '₹$oldPrice',
                style: const TextStyle(
                  decoration: TextDecoration.lineThrough,
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(LucideIcons.arrowRight, size: 14, color: Colors.amber),
              ),
              Text(
                '₹$newPrice',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    // Default fallback for other details
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: details.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${e.key}: ${e.value}',
            style: TextStyle(
              fontSize: 11,
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRoleBadge(String role, bool isDark) {
    Color badgeColor;
    switch (role) {
      case 'OWNER':
        badgeColor = Colors.blue;
        break;
      case 'BARBER':
        badgeColor = AppTheme.emerald;
        break;
      case 'SYSTEM':
        badgeColor = Colors.purple;
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: badgeColor.withOpacity(0.3)),
      ),
      child: Text(
        role,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatActionType(String type) {
    return type
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatEntityType(String type) {
    return type[0].toUpperCase() + type.substring(1);
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y • h:mm a').format(timestamp);
    }
  }
}
