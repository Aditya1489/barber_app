import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:barber_sync/core/routing/app_router.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/core/config/app_config.dart';
import 'package:barber_sync/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Diagnostic Log for Developer
  print("\n" + "="*50);
  print("🚀 BARBERSYNC STARTUP");
  print("🌍 CURRENT ENVIRONMENT: ${AppConfig.useProduction ? 'PRODUCTION 🟢' : 'LOCAL DEVELOPMENT 🏠'}");
  print("🔗 API BASE URL: ${Platform.isAndroid ? AppConfig.getBaseUrl() : AppConfig.getIosBaseUrl()}");
  print("="*50 + "\n");
  
  final container = ProviderContainer();
  
  // Initialize Notifications (non-blocking, with error handling)
  try {
    await container.read(notificationServiceProvider).initialize();
  } catch (e) {
    debugPrint("⚠️ Notification init failed (non-fatal): $e");
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );
  
  runApp(
     UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'BarberSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getLightTheme(),
      darkTheme: AppTheme.getDarkTheme(),
      themeMode: ref.watch(themeProvider) ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
    );
  }
}
