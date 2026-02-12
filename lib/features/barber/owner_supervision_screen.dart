import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/widgets/appointment_card.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/providers/user_provider.dart';

class OwnerSupervisionScreen extends ConsumerStatefulWidget {
  final List<Appointment> appointments;
  final List<Staff> staff;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final String Function(List<String>) getServiceNames;
  final String Function(String) getClientLoyalty;

  const OwnerSupervisionScreen({
    super.key,
    required this.appointments,
    required this.staff,
    required this.isDark,
    required this.onRefresh,
    required this.getServiceNames,
    required this.getClientLoyalty,
  });

  @override
  ConsumerState<OwnerSupervisionScreen> createState() => _OwnerSupervisionScreenState();
}

class _OwnerSupervisionScreenState extends ConsumerState<OwnerSupervisionScreen> {
  String? _selectedStaffId;
  String _activeExceptionTab = 'All Exceptions';
  @override
  Widget build(BuildContext context) {
    final filteredAppts = _getFilteredAppointments();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildExceptionFilterChips(),
        _buildFilterBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: widget.onRefresh,
            child: filteredAppts.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredAppts.length,
                    itemBuilder: (context, index) {
                      final appt = filteredAppts[index];
                      return AppointmentCard(
                        appointment: appt,
                        isDark: widget.isDark,
                        mode: AppointmentCardMode.supervision,
                        activeTab: 'Upcoming',
                        exceptionReason: _getExceptionReason(appt),
                        getServiceNames: widget.getServiceNames,
                        getClientLoyalty: widget.getClientLoyalty,
                        onOverride: (id) => _showOverrideDialog(appt),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  String? _getExceptionReason(Appointment appt) {
    if (appt.status == AppointmentStatus.awaitingCustomerConfirmation) {
      return "Awaiting Customer Confirmation";
    }
    if (appt.status == AppointmentStatus.inProgress) {
      return "Booking is Stuck in Progress";
    }
    if (appt.status == AppointmentStatus.noShow) {
      return "Customer Missed (No-Show)";
    }
    return null;
  }

  Widget _buildExceptionFilterChips() {
    final filters = [
      {'label': 'All', 'id': 'All Exceptions'},
      {'label': 'Awaiting ₹1', 'id': 'Pending Payment'},
      {'label': 'Late Starts', 'id': 'Late Starts'},
      {'label': 'Missed', 'id': 'Missed'},
      {'label': 'Stuck', 'id': 'Stuck'},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: filters.map((f) {
          final isSelected = _activeExceptionTab == f['id'];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _activeExceptionTab = f['id']!);
              },
              selectedColor: AppTheme.emerald.withOpacity(0.1),
              backgroundColor: widget.isDark ? AppTheme.darkCardBG : Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.emerald : (widget.isDark ? Colors.white : Colors.black).withOpacity(0.5),
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
              elevation: 0,
              pressElevation: 0,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 54,
              decoration: BoxDecoration(
                color: widget.isDark ? AppTheme.darkCardBG : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(widget.isDark ? 0.1 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: PopupMenuButton<String>(
                onSelected: (val) => setState(() => _selectedStaffId = val),
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                constraints: const BoxConstraints(minWidth: 200),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: widget.isDark ? AppTheme.darkBGMiddle : Colors.white,
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: null, 
                    child: Text("All Barbers", style: TextStyle(fontWeight: FontWeight.bold))
                  ),
                  ...widget.staff.map((s) => PopupMenuItem(
                    value: s.id, 
                    child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold))
                  )),
                ],
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _selectedStaffId == null 
                          ? "All Barbers" 
                          : widget.staff.firstWhere((s) => s.id == _selectedStaffId).name,
                        style: TextStyle(
                          fontSize: 14, 
                          fontWeight: FontWeight.w900, 
                          color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.8)
                        ),
                      ),
                    ),
                    Icon(LucideIcons.chevronDown, size: 16, color: AppTheme.darkAccent),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Appointment> _getFilteredAppointments() {
    List<Appointment> list = widget.appointments;

    if (_selectedStaffId != null) {
      list = list.where((a) => a.staffId == _selectedStaffId).toList();
    }

    if (_activeExceptionTab == 'Pending Payment') {
      list = list.where((a) => a.status == AppointmentStatus.awaitingCustomerConfirmation).toList();
    } else if (_activeExceptionTab == 'Late Starts') {
      list = []; // Placeholder for now
    } else if (_activeExceptionTab == 'Missed') {
      list = list.where((a) => a.status == AppointmentStatus.noShow).toList();
    } else if (_activeExceptionTab == 'Stuck') {
       list = list.where((a) => a.status == AppointmentStatus.inProgress).toList();
    } else {
       // All Problems
       list = list.where((a) => 
         a.status == AppointmentStatus.awaitingCustomerConfirmation || 
         a.status == AppointmentStatus.inProgress ||
         a.status == AppointmentStatus.noShow
       ).toList();
    }

    return list;
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.4,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.02),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.shieldCheck, size: 64, color: AppTheme.emerald.withOpacity(0.1)),
            ),
            const SizedBox(height: 24),
            const Text("No exceptions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text("Everything is running smoothly.", style: TextStyle(fontSize: 13, color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          ],
        ),
      ),
    );
  }

  void _showOverrideDialog(Appointment appt) {
    final user = ref.read(userProvider);
    if (user == null) return;

    final reasonController = TextEditingController();
    String newStatus = "CANCELLED_BY_BARBER";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: widget.isDark ? AppTheme.darkBGMiddle : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Safety Override", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(LucideIcons.x)),
                ],
              ),
              const SizedBox(height: 8),
              const Text("Forces a status change. Action is logged with your ID and reason for audit transparency.", 
                style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 24),
              const Text("NEW STATUS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: newStatus,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: "CANCELLED_BY_BARBER", child: Text("Cancel Appointment")),
                      DropdownMenuItem(value: "COMPLETED", child: Text("Mark as Completed")),
                      DropdownMenuItem(value: "NO_SHOW", child: Text("Mark as No-Show")),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => newStatus = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text("OVERRIDE REASON", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Why is this override necessary?",
                  filled: true,
                  fillColor: (widget.isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (reasonController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reason is mandatory")));
                      return;
                    }
                    
                    final success = await ref.read(apiServiceProvider).overrideBooking(
                      appt.id, 
                      user.id, 
                      reasonController.text, 
                      newStatus
                    );

                    if (success && mounted) {
                      Navigator.pop(context);
                      widget.onRefresh();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Override successful and logged.")));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("CONFIRM OVERRIDE", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
