import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/features/auth/login_screen.dart';
import 'package:barber_sync/features/barber/barber_dashboard.dart';
import 'package:barber_sync/features/auth/registration_flow_screen.dart';
import 'package:barber_sync/features/barber/shop_settings_screen.dart';
import 'package:barber_sync/features/barber/manage_services_screen.dart';
import 'package:barber_sync/features/barber/staff_management_screen.dart';
import 'package:barber_sync/features/common/notifications_screen.dart';
import 'package:barber_sync/features/barber/business_analytics_screen.dart';
import 'package:barber_sync/features/barber/shop_preview_screen.dart';
import 'package:barber_sync/features/barber/staff_preview_screen.dart';
import 'package:barber_sync/features/barber/edit_barber_profile_screen.dart';
import 'package:barber_sync/features/barber/staff_services_screen.dart';
import 'package:barber_sync/features/barber/staff_reviews_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final user = ref.watch(userProvider);
  
  return GoRouter(
    initialLocation: user == null ? '/login' : '/barber',
    redirect: (context, state) {
      final loggedIn = ref.read(userProvider) != null;
      final isLoggingIn = state.matchedLocation == '/login';
      final isRegistering = state.matchedLocation == '/register';

      if (!loggedIn && !isLoggingIn && !isRegistering) {
        return '/login';
      }
      if (loggedIn && (isLoggingIn || isRegistering)) {
        return '/barber';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationFlowScreen(),
      ),
      GoRoute(
        path: '/barber',
        builder: (context, state) => const BarberDashboardScreen(),
      ),
      GoRoute(
        path: '/shop-settings',
        builder: (context, state) {
          final shopData = (state.extra as Map<String, dynamic>?) ?? {};
          return ShopSettingsScreen(shopData: shopData);
        },
      ),
      GoRoute(
        path: '/manage-services',
        builder: (context, state) {
          final shopData = (state.extra as Map<String, dynamic>?) ?? {};
          return ManageServicesScreen(shopData: shopData);
        },
      ),
      GoRoute(
        path: '/staff-management',
        builder: (context, state) {
          final shopData = (state.extra as Map<String, dynamic>?) ?? {};
          return StaffManagementScreen(shopData: shopData);
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/business-analytics',
        builder: (context, state) {
          final shopData = (state.extra as Map<String, dynamic>?) ?? {};
          return BusinessAnalyticsScreen(shopData: shopData);
        },
      ),
      GoRoute(
        path: '/shop-preview',
        builder: (context, state) {
          final shopData = (state.extra as Map<String, dynamic>?) ?? {};
          return ShopPreviewScreen(shopData: shopData);
        },
      ),
      GoRoute(
        path: '/staff-preview',
        builder: (context, state) {
          final staffData = (state.extra as Map<String, dynamic>?) ?? {};
          return StaffPreviewScreen(staffData: staffData);
        },
      ),
      GoRoute(
        path: '/staff-profile-edit',
        builder: (context, state) {
           final staffData = (state.extra as Map<String, dynamic>?) ?? {};
           return EditBarberProfileScreen(staffBasicInfo: staffData);
        },
      ),
       GoRoute(
        path: '/staff-services',
        builder: (context, state) {
           final staffData = (state.extra as Map<String, dynamic>?) ?? {};
           return StaffServicesScreen(staffData: staffData);
        },
      ),
      GoRoute(
        path: '/staff-reviews',
        builder: (context, state) {
           final staffId = state.extra as String? ?? '';
           return StaffReviewsScreen(staffId: staffId);
        },
      ),
    ],
  );
});
