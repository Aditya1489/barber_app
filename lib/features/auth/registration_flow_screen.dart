import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/models/models.dart';

class RegistrationFlowScreen extends ConsumerStatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  ConsumerState<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends ConsumerState<RegistrationFlowScreen> {
  // Flow control
  String _step = 'credentials'; // credentials, role, owner_details, staff_details
  String _selectedRole = '';
  bool _isLoading = false;
  late bool isDark;

  // Owner states
  final TextEditingController _shopNameController = TextEditingController();
  final TextEditingController _pinCodeController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  Map<String, double>? _detectedCoordinates;
  bool _locationDetected = false;
  final List<File> _shopPhotos = [];
  File? _profilePhoto;
  final List<File> _portfolioPhotos = [];
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _services = [];
  final List<Map<String, dynamic>> _staff = [];

  // Service form states
  final TextEditingController _serviceNameController = TextEditingController();
  final TextEditingController _servicePriceController = TextEditingController();
  final TextEditingController _serviceDurationController = TextEditingController();

  // Staff form states
  final TextEditingController _staffNameController = TextEditingController();
  final TextEditingController _staffPhoneController = TextEditingController();

  // Credentials form states
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Staff states
  final TextEditingController _expController = TextEditingController();
  final TextEditingController _aboutController = TextEditingController();

  Future<void> _detectLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => _isLoading = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location services are disabled.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permissions are denied.')),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permissions are permanently denied.')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      if (mounted) {
        setState(() {
          _detectedCoordinates = {
            'lat': position.latitude,
            'lng': position.longitude,
          };
          _locationDetected = true;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location captured! You can now enter your address.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error detecting location: $e')),
        );
      }
    }
  }

  void _addService() {
    if (_serviceNameController.text.isNotEmpty &&
        _servicePriceController.text.isNotEmpty &&
        _serviceDurationController.text.isNotEmpty) {
      setState(() {
        _services.add({
          'name': _serviceNameController.text,
          'price': double.parse(_servicePriceController.text),
          'duration': int.parse(_serviceDurationController.text),
        });
        _serviceNameController.clear();
        _servicePriceController.clear();
        _serviceDurationController.clear();
      });
    }
  }

  Future<void> _handleFinish() async {
    if (_selectedRole == 'owner' && _services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one service.")),
      );
      return;
    }

    if (_selectedRole.isEmpty) return;

    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    final userProviderNotifier = ref.read(userProvider.notifier);

    try {
      // AUTO-COLLECT: If user typed staff/service info but forgot to click "Add", do it for them
      if (_selectedRole == 'owner') {
        if (_staffNameController.text.isNotEmpty && _staffPhoneController.text.isNotEmpty) {
          print("[REG_FLOW] Auto-collecting leftover staff: ${_staffNameController.text}");
          _staff.add({
            'name': _staffNameController.text,
            'phone': _staffPhoneController.text,
          });
        }
        if (_serviceNameController.text.isNotEmpty && _servicePriceController.text.isNotEmpty) {
           print("[REG_FLOW] Auto-collecting leftover service: ${_serviceNameController.text}");
          _services.add({
            'name': _serviceNameController.text,
            'price': double.tryParse(_servicePriceController.text) ?? 50.0,
            'duration': int.tryParse(_serviceDurationController.text) ?? 30,
          });
        }
      }

      final registerData = {
        'name': _nameController.text,
        'email': _emailController.text,
        'phone': _phoneController.text,
        'password': _passwordController.text,
        'role': _selectedRole == 'owner' ? 'OWNER' : 'BARBER',
      };

      final authResponse = await apiService.register(registerData);
      if (authResponse == null || authResponse['user'] == null) {
        throw Exception("Registration failed");
      }

      final newUser = User.fromJson(authResponse['user']);
      userProviderNotifier.state = newUser;

      // 2. Create Shop or Update Profile
      if (_selectedRole == 'owner') {
        print("[REG_FLOW] Starting shop creation for owner...");
        
        // Upload shop photos
        List<String> photoUrls = [];
        if (_shopPhotos.isNotEmpty) {
          print("[REG_FLOW] Uploading ${_shopPhotos.length} photos...");
          for (var photo in _shopPhotos) {
            final url = await apiService.uploadFile(photo);
            if (url != null) {
              photoUrls.add(url);
            }
          }
        }
        
        print("[REG_FLOW] Services to send: $_services");
        print("[REG_FLOW] Staff to send: $_staff");
        
        final createData = {
          'name': _shopNameController.text,
          'address': _addressController.text,
          'description': "Professional Barber Shop",
          'coordinates': _detectedCoordinates ?? {'lat': 40.7128, 'lng': -74.0060},
          'ownerId': newUser.id,
          'phone': newUser.phone ?? _phoneController.text,
          'email': newUser.email,
          'services': _services,
          'staff': _staff,
          'photos': photoUrls,
        };
        
        print("[REG_FLOW] Creating shop with data: $createData");
        final shopResult = await apiService.createShop(createData);
        if (shopResult == null) {
          throw Exception("Registration successful, but shop creation failed. Please try again from settings.");
        }
      } else {
        // Handle staff profile completion
        print("[REG_FLOW] Updating profile for staff...");
        // Upload profile photo if exists
        String? profilePhotoUrl;
        if (_profilePhoto != null) {
          print("[REG_FLOW] Uploading profile photo...");
          profilePhotoUrl = await apiService.uploadFile(_profilePhoto!);
        }

        // Upload portfolio photos
        List<String> portfolioUrls = [];
        if (_portfolioPhotos.isNotEmpty) {
          print("[REG_FLOW] Uploading ${_portfolioPhotos.length} portfolio photos...");
          for (var photo in _portfolioPhotos) {
            final url = await apiService.uploadFile(photo);
            if (url != null) {
              portfolioUrls.add(url);
            }
          }
        }

        final updateData = {
          'experience': int.tryParse(_expController.text) ?? 0,
          'about': _aboutController.text,
          'location': _detectedCoordinates,
          'profilePhoto': profilePhotoUrl,
          'portfolio': portfolioUrls,
        };
        await apiService.updateProfile(newUser.id, updateData);
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
        context.go('/barber');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  Future<void> _pickShopPhotos() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      if (mounted) {
        setState(() {
          _shopPhotos.addAll(images.map((img) => File(img.path)));
        });
      }
    }
  }

  Future<void> _pickProfilePhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (mounted) setState(() => _profilePhoto = File(image.path));
    }
  }

  Future<void> _pickPortfolioPhotos() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      if (mounted) {
        setState(() {
          _portfolioPhotos.addAll(images.map((img) => File(img.path)));
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    isDark = ref.watch(themeProvider);
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: _buildCurrentStep(),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_step == 'credentials') return _buildCredentialsStep();
    if (_step == 'role') return _buildRoleStep();
    if (_step == 'owner_details') return _buildOwnerDetailsStep();
    if (_step == 'staff_details') return _buildStaffDetailsStep();
    return const SizedBox();
  }

  Widget _buildCredentialsStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 48),
            const Text("Get Started", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const Text("Create your account to continue", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            _buildInput("Full Name", "John Doe", _nameController),
            const SizedBox(height: 16),
            _buildInput("Email Address", "john@example.com", _emailController, keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildInput("Phone Number", "+1 234...", _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 16),
            _buildInput("Password", "********", _passwordController, keyboardType: TextInputType.visiblePassword),
            const SizedBox(height: 48),
            _buildPrimaryButton("NEXT STEP", () {
              if (_nameController.text.isNotEmpty && 
                  _emailController.text.isNotEmpty && 
                  _passwordController.text.isNotEmpty) {
                setState(() => _step = 'role');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please fill all fields"))
                );
              }
            }),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildBackButton(() => setState(() => _step = 'credentials')),
            const SizedBox(height: 24),
            const Text(
              "Select Your Role",
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: 0.6,
              child: const Text(
                "Are you a shop owner or a barber working in a shop?",
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 48),
            _buildRoleCard(
              "Shop Owner",
              "Create and manage your own shop",
              LucideIcons.store,
              Colors.red,
              () => setState(() {
                _selectedRole = 'owner';
                _step = 'owner_details';
              }),
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              "Staff / Barber",
              "Join an existing shop as a barber",
              LucideIcons.users,
              AppTheme.emerald,
              () => setState(() {
                _selectedRole = 'staff';
                _step = 'staff_details';
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusL),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(AppTheme.radiusL),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppTheme.radiusM)),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  Text(sub, style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerDetailsStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBackButton(() => setState(() => _step = 'role')),
            const SizedBox(height: 24),
            const Text("Setup Your Shop", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            const Opacity(opacity: 0.4, child: Text("Tell us about your business")),
            const SizedBox(height: 32),
            _buildInput("Shop Name", "Enter business name", _shopNameController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _detectLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _locationDetected 
                            ? AppTheme.emerald.withOpacity(0.12)
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: _locationDetected 
                            ? Border.all(color: AppTheme.emerald.withOpacity(0.4), width: 1.5)
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _locationDetected ? LucideIcons.checkCircle2 : LucideIcons.mapPin, 
                            size: 18, 
                            color: _locationDetected ? AppTheme.emerald : (isDark ? Colors.white : Colors.black)
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _locationDetected ? "Location Ready" : "Detect Location", 
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 13,
                              color: _locationDetected ? AppTheme.emerald : (isDark ? Colors.white : Colors.black)
                            )
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildInput("PIN Code", "123456", _pinCodeController)),
              ],
            ),
            const SizedBox(height: 16),
            _buildInput("Address", "Shop full address...", _addressController, maxLines: 2),
            const SizedBox(height: 32),
            const Text("Shop Photos", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  ..._shopPhotos.map((file) => Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                    ),
                  )).toList(),
                  InkWell(
                    onTap: _pickShopPhotos,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                        borderRadius: BorderRadius.circular(24),
                        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.camera, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                          const SizedBox(height: 4),
                          Text("UPLOAD", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text("Services Offered", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._services.map((s) => _buildServiceTile(s)).toList(),
            if (_services.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                ),
                child: const Center(child: Opacity(opacity: 0.4, child: Text("No services added yet"))),
              ),
            const SizedBox(height: 16),
            _buildAddServiceForm(),
            const SizedBox(height: 40),
            const Text("Staff Members", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._staff.map((s) => _buildStaffTile(s)).toList(),
            if (_staff.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.02),
                ),
                child: const Center(child: Opacity(opacity: 0.4, child: Text("No staff added yet"))),
              ),
            const SizedBox(height: 24),
            _buildAddStaffForm(),
            const SizedBox(height: 48),
            _buildPrimaryButton("CREATE SHOP & START", _handleFinish),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffDetailsStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBackButton(() => setState(() => _step = 'role')),
          const SizedBox(height: 24),
          const Text("Build Your Profile", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const Opacity(opacity: 0.4, child: Text("Link yourself to a nearby shop to start.")),
          const SizedBox(height: 40),
          Center(
            child: InkWell(
              onTap: _pickProfilePhoto,
              customBorder: const CircleBorder(),
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), width: 4),
                          image: _profilePhoto != null 
                              ? DecorationImage(image: FileImage(_profilePhoto!), fit: BoxFit.cover)
                              : null,
                        ),
                        child: _profilePhoto == null 
                            ? Icon(LucideIcons.camera, color: (isDark ? Colors.white : Colors.black).withOpacity(0.2), size: 32)
                            : null,
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(color: AppTheme.darkAccent, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.plus, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text("Upload Profile Photo", style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),
          _buildInput("Years of Experience", "e.g. 5", _expController, keyboardType: TextInputType.number),
          const SizedBox(height: 16),
          _buildInput("About You", "Describe your expertise...", _aboutController, maxLines: 3),
          const SizedBox(height: 32),
          const Text("Portfolio (Previous Work)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(
              children: [
                ..._portfolioPhotos.map((file) => Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(image: FileImage(file), fit: BoxFit.cover),
                  ),
                )).toList(),
                InkWell(
                  onTap: _pickPortfolioPhotos,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
                    ),
                    child: Icon(LucideIcons.camera, color: (isDark ? Colors.white : Colors.black).withOpacity(0.1), size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildPrimaryButton("JOIN SHOP & START", _handleFinish),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBackButton(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(LucideIcons.arrowLeft, size: 20),
      ),
    );
  }

  Widget _buildStaffTile(Map<String, dynamic> staff) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.emerald.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.user, size: 20, color: AppTheme.emerald),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(staff['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(staff['phone'], style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _staff.remove(staff)),
            icon: const Icon(LucideIcons.x, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildAddStaffForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.1)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildInput("Staff Name", "Full name", _staffNameController),
          const SizedBox(height: 12),
          _buildInput("Phone Number", "+1...", _staffPhoneController, keyboardType: TextInputType.phone),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                if (_staffNameController.text.isNotEmpty && _staffPhoneController.text.isNotEmpty) {
                  setState(() {
                    _staff.add({
                      'name': _staffNameController.text,
                      'phone': _staffPhoneController.text,
                    });
                    _staffNameController.clear();
                    _staffPhoneController.clear();
                  });
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: AppTheme.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text("Add Staff Member", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, String hint, TextEditingController controller, {int maxLines = 1, TextInputType? keyboardType = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(fontSize: 14, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), fontWeight: FontWeight.normal),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(LucideIcons.scissors, color: Colors.red, size: 16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text("${service['duration']} min • \$${service['price']}", style: TextStyle(fontSize: 10, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _services.remove(service)),
            icon: Icon(LucideIcons.trash2, size: 16, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddServiceForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _buildInput("Service Name", "e.g. Premium Fade", _serviceNameController),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInput("Price (\$)", "25", _servicePriceController, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildInput("Time (Min)", "30", _serviceDurationController, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _addService,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: AppTheme.emerald, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(LucideIcons.plus, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text("Add Service", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.darkButton,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : onTap,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
