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
  String? selectedRole = "BARBER"; 
  late bool isDark;
  bool _isLoading = false;
  bool _isOtpSent = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  Future<void> _handlePhoneSubmit() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your full name")),
      );
      return;
    }
    
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid phone number")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    // Request OTP
    final success = await apiService.requestOtp(phone);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        setState(() => _isOtpSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("OTP sent successfully")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to send OTP. Please try again.")),
        );
      }
    }
  }

  Future<void> _handleOtpSubmit() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter valid 6-digit OTP")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      final response = await apiService.verifyOtp(_phoneController.text.trim(), otp);
      print("DEBUG: OTP Response: $response");
      
      if (response != null) {
        if (response['access_token'] != null && response['action'] != 'REGISTER') {
           await _finalizeLogin(response);
        } else if (response['action'] == 'SELECT_ROLE') {
           _handleRoleSelection(response['user']['id'], response['roles']);
        } else if (response['action'] == 'REGISTER') {
           // Create temporary user for registration with name captured at login
           final tempUser = User(
             id: 'temp',
             name: _nameController.text.trim(),
             email: '',
             phone: _phoneController.text.trim(),
             role: AppRole.customer,
             permissions: {},
             token: response['access_token'],
           );
           ref.read(userProvider.notifier).setTemporaryUser(tempUser);
           context.push('/register');
        }
      } else {
        _showError("Invalid OTP");
      }
    } catch (e) {
      _showError("Login error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _handleRoleSelection(String userId, List<dynamic> roles) {
      // Filter for relevant roles
      final validRoles = roles.where((r) => ['OWNER', 'BARBER'].contains(r['role'])).toList();

      if (validRoles.isEmpty) {
          _showError("No Barber or Owner account found associated with this number.");
          return;
      }
      
      if (validRoles.length == 1) {
          final r = validRoles.first;
          _selectRole(userId, r['role'], r['shop_id']);
          return;
      }

      // Show Dialog
      showDialog(context: context, builder: (ctx) => AlertDialog(
          title: const Text("Select Account"),
          content: Column(
             mainAxisSize: MainAxisSize.min,
             children: validRoles.map((r) => ListTile(
                leading: Icon(r['role'] == 'OWNER' ? LucideIcons.crown : LucideIcons.scissors),
                title: Text("${r['shop_name'] ?? 'Shop'}"),
                subtitle: Text(r['role']),
                onTap: () {
                    Navigator.pop(ctx);
                    _selectRole(userId, r['role'], r['shop_id']);
                }
             )).toList()
          )
      ));
  }

  Future<void> _selectRole(String userId, String role, String? shopId) async {
       setState(() => _isLoading = true);
       final apiService = ref.read(apiServiceProvider);
       print("DEBUG: Selecting role: $role, shopId: $shopId");
       
       final response = await apiService.selectRole(userId, role, shopId);
       print("DEBUG: SelectRole Response: $response");
       
       if (mounted) setState(() => _isLoading = false);
       
       if (response != null) { 
           await _finalizeLogin(response);
       } else {
           _showError("Failed to select role");
       }
  }

  Future<void> _finalizeLogin(Map<String, dynamic> response) async {
    print("DEBUG: _finalizeLogin called with response keys: ${response.keys}");
    if (response['user'] != null) {
        var userData = User.fromJson(response['user']);
        
        // Attach token if available
        if (response['access_token'] != null) {
            print("DEBUG: Found access_token in response: ${response['access_token'].substring(0, 10)}...");
            userData = userData.copyWith(token: response['access_token']);
            print("DEBUG: userData.token after copyWith: ${userData.token != null ? 'SET' : 'NULL'}");
        } else {
            print("DEBUG: NO access_token in response!");
        }

        if (mounted) {
          if (userData.role != AppRole.customer) {
            // Initialize Notifications
            print("DEBUG: Calling setUser...");
            await ref.read(userProvider.notifier).setUser(userData);
            print("DEBUG: setUser finished.");
            ref.read(notificationServiceProvider).startPolling(userData.id);
            context.go('/barber');
          } else {
             // New user or Customer trying to become Barber/Owner
             // Navigate to profile completion/registration flow
             ref.read(userProvider.notifier).setTemporaryUser(userData);
             context.push('/register');
          }
        }
    }
  }

  void _showError(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
            Align(
              alignment: Alignment.center,
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
          const SizedBox(height: 40),
          _buildLogo(),
          const SizedBox(height: 60),
            _buildRoleButton(
              'Barber / Owner',
              'Manage shop & clients',
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
            borderRadius: BorderRadius.circular(24),
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
          'BarberSync',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 40,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          'Professional Grooming Management',
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
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
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
                borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 32),
            Text(
              _isOtpSent ? 'Verify OTP' : 'Welcome Back',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            Text(
              _isOtpSent 
                 ? 'Enter the code sent to ${_phoneController.text}' 
                 : 'Login via OTP',
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            
            if (!_isOtpSent) ...[
               _buildInput(LucideIcons.user, 'Full Name', _nameController),
               const SizedBox(height: 16),
               _buildInput(LucideIcons.phone, 'Phone Number', _phoneController),
            ],

            if (_isOtpSent)
               _buildInput(LucideIcons.key, '6-Digit OTP', _otpController),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading 
                   ? null 
                   : (_isOtpSent ? _handleOtpSubmit : _handlePhoneSubmit),
                child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_isOtpSent ? 'Verify & Login' : 'Get OTP'),
              ),
            ),
            
            Visibility(
              visible: _isOtpSent,
              maintainSize: true, 
              maintainAnimation: true,
              maintainState: true,
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() {
                    _isOtpSent = false;
                    _otpController.clear();
                  }),
                  child: Text(
                    'Change Phone Number',
                    style: TextStyle(color: isDark ? AppTheme.darkAccent : Colors.black, fontWeight: FontWeight.bold),
                  ),
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
        keyboardType: hint.contains("Phone") || hint.contains("OTP") 
            ? TextInputType.number 
            : TextInputType.text,
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
