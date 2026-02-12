import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/widgets/user_avatar.dart';

enum AppointmentCardMode { execution, supervision }

class AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final bool isDark;
  final AppointmentCardMode mode;
  final int? index;
  final String? activeTab;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onComplete;
  final VoidCallback? onNoShow;
  final VoidCallback? onAddNote;
  final VoidCallback? onReportIssue;
  final Function(String)? onOverride;
  final String? exceptionReason;
  final String Function(List<String>) getServiceNames;
  final String Function(String) getClientLoyalty;

  const AppointmentCard({
    super.key,
    required this.appointment,
    required this.isDark,
    this.mode = AppointmentCardMode.execution,
    this.index,
    this.activeTab,
    this.onAccept,
    this.onReject,
    this.onComplete,
    this.onNoShow,
    this.onAddNote,
    this.onReportIssue,
    this.onOverride,
    this.exceptionReason,
    required this.getServiceNames,
    required this.getClientLoyalty,
  });

  @override
  Widget build(BuildContext context) {
    if (activeTab == 'Requests') {
      return _buildRequestCard();
    }
    return _buildTaskCard();
  }

  Widget _buildRequestCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                UserAvatar(
                  radius: 28,
                  photoUrl: appointment.customerPhoto,
                  name: appointment.customerName ?? "Customer",
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(appointment.customerName ?? "Customer",
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          Text("\$${appointment.totalAmount.toStringAsFixed(0)}",
                              style: const TextStyle(
                                  fontWeight: FontWeight.w900, color: AppTheme.emerald, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        getServiceNames(appointment.services),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
              border: Border.symmetric(horizontal: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 14, color: AppTheme.darkAccent),
                    const SizedBox(width: 8),
                    Text(appointment.date, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 16),
                    Icon(LucideIcons.clock, size: 14, color: AppTheme.darkAccent),
                    const SizedBox(width: 8),
                    Text(appointment.timeSlot, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
                _statusBadge("NEW REQUEST", Colors.amber),
              ],
            ),
          ),
          if (mode == AppointmentCardMode.execution)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: onAccept,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppTheme.emerald,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: AppTheme.emerald.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: const Text("ACCEPT",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                letterSpacing: 1.2)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: onReject,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.x, color: Colors.red, size: 20),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildTaskCard() {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    bool isToday = appointment.date == today;
    bool isCurrent = isToday && index == 0 && activeTab == 'Upcoming';
    final loyalty = getClientLoyalty(appointment.customerId);

    Color statusColor = Colors.blue;
    String statusText = "UPCOMING";

    if (activeTab == 'Completed') {
      statusColor = AppTheme.emerald;
      statusText = "COMPLETED";
    } else if (activeTab == 'Missed') {
      statusColor = Colors.red;
      statusText = "NO SHOW";
    } else if (appointment.status == AppointmentStatus.awaitingCustomerConfirmation) {
      statusColor = Colors.amber;
      statusText = "PENDING PAYMENT";
    } else if (isCurrent) {
      statusColor = Colors.orange;
      statusText = "CURRENT";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: isCurrent ? Border.all(color: Colors.orange.withOpacity(0.5), width: 2) : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isCurrent) 
                          Container(
                            width: 8, height: 8,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                          ).animate(onPlay: (c) => c.repeat()).scale(duration: 1000.ms, begin: const Offset(0.8, 0.8), end: const Offset(1.2, 1.2)).then().scale(begin: const Offset(1.2, 1.2), end: const Offset(0.8, 0.8)),
                        Text(appointment.timeSlot,
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: -0.5)),
                        const SizedBox(width: 12),
                        _loyaltyBadge(loyalty),
                      ],
                    ),
                    _statusBadge(statusText, statusColor),
                  ],
                ),
                if (mode == AppointmentCardMode.supervision && exceptionReason != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 14, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            exceptionReason!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    UserAvatar(
                        radius: 30, photoUrl: appointment.customerPhoto, name: appointment.customerName ?? "Customer"),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(appointment.customerName ?? "Customer",
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(LucideIcons.scissors,
                                  size: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                              const SizedBox(width: 6),
                              Expanded(
                                  child: Text(getServiceNames(appointment.services),
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(LucideIcons.clock,
                                  size: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                              const SizedBox(width: 6),
                              Text("${appointment.totalDuration} min",
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                              const SizedBox(width: 16),
                              Icon(LucideIcons.dollarSign, size: 14, color: AppTheme.emerald),
                              const SizedBox(width: 2),
                              Text("\$${appointment.totalAmount.toStringAsFixed(0)}",
                                  style: const TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w900, color: AppTheme.emerald)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (appointment.privateNotes != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amber.withOpacity(0.1))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(LucideIcons.stickyNote, size: 12, color: Colors.amber),
                            const SizedBox(width: 6),
                            Text("PRIVATE NOTE",
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.amber.withOpacity(0.8),
                                    letterSpacing: 1)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(appointment.privateNotes!,
                            style: TextStyle(
                                fontSize: 13,
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (mode == AppointmentCardMode.execution && (activeTab == 'Upcoming' || isCurrent))
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionBtn(
                      isDark, 
                      onAddNote, 
                      LucideIcons.plus, 
                      "ADD NOTE", 
                      Colors.blue
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionBtn(
                      isDark, 
                      onReportIssue, 
                      LucideIcons.flag, 
                      "REPORT", 
                      Colors.red
                    ),
                  ),
                ],
              ),
            ),
          if (activeTab == 'Missed')
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        "No-show affects your visibility rating · Potential loss: \$${appointment.totalAmount.toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          if (mode == AppointmentCardMode.supervision)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                border: Border(top: BorderSide(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05))),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (onOverride != null) onOverride!(appointment.id);
                  },
                  icon: const Icon(LucideIcons.shieldAlert, size: 14),
                  label: const Text("OWNER OVERRIDE", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.darkAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05);
  }

  Widget _buildActionBtn(bool isDark, VoidCallback? onTap, IconData icon, String label, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _loyaltyBadge(String status) {
    Color color = Colors.grey;
    if (status == "Loyal") color = AppTheme.emerald;
    if (status == "Returning") color = Colors.blue;
    if (status == "First-time") color = Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(status.toUpperCase(),
          style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
