import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/services/notification_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  bool isLogin = true;
  String? selectedRole = "BARBER"; // Default to BARBER to skip selection
  late bool isDark;
  bool _isLoading = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter email and password")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      final response = await apiService.login(_emailController.text, _passwordController.text);
      if (response != null && response['user'] != null) {
        final userData = User.fromJson(response['user']);
        ref.read(userProvider.notifier).state = userData;

        if (mounted) {
          if (userData.role != AppRole.customer) {
            ref.read(notificationServiceProvider).startPolling(userData.id);
            context.go('/barber');
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("This app is for Barbers & Owners only. Please use the Customer App.")),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Invalid email or password")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Scaffold(
      extendBody: true,
      body: GradientBackground(
        isDark: isDark,
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: selectedRole == null ? _buildRoleSelection() : _buildAuthForm(),
                ),
              ),
            ),
            // Theme Toggle
            Positioned(
              top: 0,
              right: 20,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: () => ref.read(themeProvider.notifier).state = !isDark,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isDark ? LucideIcons.sun : LucideIcons.moon,
                        size: 20,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 140), // Increased to shift downward
          _buildLogo(),
          const SizedBox(height: 60),
            _buildRoleButton(
              "Continue as Barber / Owner",
              "Manage your shop & clients",
              LucideIcons.scissors,
              AppTheme.emerald,
              () => setState(() => selectedRole = "BARBER"),
            ),
            const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.darkButton,
            borderRadius: BorderRadius.circular(24), // Match React rounded-3xl
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: const Icon(LucideIcons.scissors, color: Colors.white, size: 48),
        ),
        const SizedBox(height: 16),
        Text(
          "BarberSync",
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          "Professional Grooming Marketplace",
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildRoleButton(String title, String sub, IconData icon, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24), // Match React
      child: Container(
        padding: const EdgeInsets.all(20), // Standardized p-5
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(12), // rounded-lg
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  Text(sub, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6))),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          IconButton(
            onPressed: () => setState(() => selectedRole = null),
            icon: const Icon(LucideIcons.arrowLeft),
            style: IconButton.styleFrom(
              backgroundColor: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isLogin ? "Welcome Back" : "Join BarberSync",
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          Text(
            selectedRole == "CUSTOMER" ? "Customer Account" : "Barber & Shop Management",
            style: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
          ),
          const SizedBox(height: 40),
          _buildInput(LucideIcons.mail, "Email Address", _emailController),
          const SizedBox(height: 16),
          _buildInput(LucideIcons.lock, "Password", _passwordController, isPassword: true),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(isLogin ? "Login" : "Create Account"),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () => context.push('/register'),
              child: Text(
                isLogin ? "Don't have an account? Sign Up" : "Already have an account? Log In",
                style: const TextStyle(color: AppTheme.darkAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildInput(IconData icon, String hint, TextEditingController controller, {bool isPassword = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        decoration: InputDecoration(
          icon: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
          hintText: hint,
          border: InputBorder.none,
          hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
        ),
      ),
    );
  }
}
