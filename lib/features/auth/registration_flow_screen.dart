import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/core/providers/user_provider.dart';
import 'package:barber_sync/models/models.dart';
import 'package:barber_sync/widgets/premium_dialog_helper.dart';

class RegistrationFlowScreen extends ConsumerStatefulWidget {
  const RegistrationFlowScreen({super.key});

  @override
  ConsumerState<RegistrationFlowScreen> createState() => _RegistrationFlowScreenState();
}

class _RegistrationFlowScreenState extends ConsumerState<RegistrationFlowScreen> {
  // Flow control
  final PageController _pageController = PageController();
  
  String _selectedRole = '';
  bool _isLoading = false;
  late bool isDark;
  bool _agreedToPrivacy = false;
  bool _agreedToTerms = false;

  // ... (keep generic vars)

  // NOTE: Keeping other controllers...

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ... (keep _detectLocation, _addService, _handleFinish, _pick... methods)

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
          child: PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(), 
            children: [
              _buildCredentialsStep(),
              _buildRoleStep(),
              _buildDetailsPage(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPage() {
     if (_selectedRole == 'owner') {
        return _buildOwnerDetailsStep();
     } else if (_selectedRole == 'staff') {
        return _buildStaffDetailsStep();
     }
     
     // Fallback if user swipes without selecting role
     return Center(
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(LucideIcons.alertTriangle, size: 48, color: Colors.grey),
           SizedBox(height: 16),
           Text("Please select a role first", style: TextStyle(color: Colors.grey)),
         ],
       ),
     );
  }
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
  late final TextEditingController _nameController;
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final currentUser = ref.read(userProvider);
    _nameController = TextEditingController(text: currentUser?.name ?? "");
  }

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
          bool openSettings = await PremiumDialog.showConfirmation(
            context: context,
            title: "Location Services Disabled",
            content: "Please enable location services to detect your shop's location.",
            confirmText: "Open Settings",
            icon: LucideIcons.mapPin,
            iconColor: Colors.amber,
          );
          
          if (openSettings) {
             await Geolocator.openLocationSettings();
             // Optional: recursively try again or let user click button again?
             // For now, let user click button again after enabling.
          }
          if (mounted) setState(() => _isLoading = false);
        }
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
            setState(() => _isLoading = false);
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
           bool openSettings = await PremiumDialog.showConfirmation(
            context: context,
            title: "Permission Denied",
            content: "Location permissions are permanently denied. Please enable them in app settings.",
            confirmText: "Open Settings",
            icon: LucideIcons.lock,
            iconColor: Colors.red,
          );

          if (openSettings) {
            await Geolocator.openAppSettings();
          }
          setState(() => _isLoading = false);
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      
      List<Placemark> placemarks = [];
      try {
        placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      } catch (e) {
        debugPrint("Geocoding failed manually: $e");
        // Continue without address
      }
      
      if (mounted) {
        setState(() {
          _detectedCoordinates = {
            'lat': position.latitude,
            'lng': position.longitude,
          };
          _locationDetected = true;
          
          if (placemarks.isNotEmpty) {
            try {
              Placemark place = placemarks.first;
              _addressController.text = "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
              _pinCodeController.text = place.postalCode ?? "";
            } catch (e) {
              debugPrint("Error parsing placemark: $e");
            }
          }
           
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(placemarks.isNotEmpty ? 'Location & Address captured!' : 'Location captured!')),
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
    final currentUser = ref.read(userProvider);
    
    if (currentUser == null) {
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User session not found. Please login again.")),
      );
       setState(() => _isLoading = false);
       return;
    }

    try {
      User? effectiveUser = currentUser;
      
      // 1. Check if New Registration (Temp User)
      if (currentUser.id == 'temp') {
          print("[REG_FLOW] Registering new user...");
          final registerData = {
             'name': _nameController.text,
             'role': _selectedRole == 'owner' ? 'OWNER' : 'BARBER', // 'staff' -> 'BARBER'
             'email': null, // Optional, can add email field to UI later
             'agreedToPrivacy': _agreedToPrivacy,
             'agreedToTerms': _agreedToTerms,
             'legalConsentName': _nameController.text,
             'legalConsentPlace': _addressController.text.isNotEmpty ? _addressController.text : "Detected Location",
             'legalConsentTimestamp': DateTime.now().toIso8601String(),
          };
          
          final regResponse = await apiService.registerUser(currentUser.token!, registerData);
          if (regResponse == null) throw Exception("Registration failed. Please try again.");
          
          final newUser = User.fromJson(regResponse['user']);
          final newToken = regResponse['access_token'];
          effectiveUser = newUser.copyWith(token: newToken);
          
          // Save real user session immediately
          await userProviderNotifier.setUser(effectiveUser);
          print("[REG_FLOW] User registered: ${effectiveUser.id}");
      } else {
          // Existing User Update (e.g. Customer -> Owner)
          final profileData = {
            'name': _nameController.text,
            'agreedToPrivacy': _agreedToPrivacy,
            'agreedToTerms': _agreedToTerms,
            'legalConsentName': _nameController.text,
            'legalConsentPlace': _addressController.text.isNotEmpty ? _addressController.text : "Detected Location",
            'legalConsentTimestamp': DateTime.now().toIso8601String(),
          };
          final updatedUser = await apiService.updateProfile(currentUser.id, profileData);
          if (updatedUser == null) throw Exception("Failed to update profile");
          effectiveUser = updatedUser;
          // Note: If upgrading role, backend permission/role update might be needed separately 
          // but we continue with Shop Creation/Profile Update logic which should enforce role eventually.
      }

      // 2. Proceed with Role-Specific Setup using effectiveUser (Real ID)
      if (_selectedRole == 'owner') {
        if (_staffNameController.text.isNotEmpty && _staffPhoneController.text.isNotEmpty) {
          _staff.add({
            'name': _staffNameController.text,
            'phone': _staffPhoneController.text,
          });
        }
        if (_serviceNameController.text.isNotEmpty && _servicePriceController.text.isNotEmpty) {
          _services.add({
            'name': _serviceNameController.text,
            'price': double.tryParse(_servicePriceController.text) ?? 50.0,
            'duration': int.tryParse(_serviceDurationController.text) ?? 30,
          });
        }

        print("[REG_FLOW] Starting shop creation for owner: ${effectiveUser.id}");
        
        // Upload shop photos
        List<String> photoUrls = [];
        if (_shopPhotos.isNotEmpty) {
          for (var photo in _shopPhotos) {
            final url = await apiService.uploadFile(photo);
            if (url != null) photoUrls.add(url);
          }
        }
    
        final createData = {
          'name': _shopNameController.text,
          'address': _addressController.text,
          'description': "Professional Barber Shop",
          'coordinates': _detectedCoordinates ?? {'lat': 40.7128, 'lng': -74.0060},
          'ownerId': effectiveUser.id,
          'phone': effectiveUser.phone.isNotEmpty ? effectiveUser.phone : _phoneController.text,
          'email': effectiveUser.email,
          'services': _services,
          'staff': _staff,
          'photos': photoUrls,
        };
        
        final shopResult = await apiService.createShop(createData);
        if (shopResult == null) {
          throw Exception("Shop creation failed.");
        }
        
        // Refetch/Update User Role to OWNER if not already
        if (effectiveUser.role != AppRole.owner) {
             final updatedOwner = effectiveUser.copyWith(role: AppRole.owner);
             await userProviderNotifier.setUser(updatedOwner);
        }

      } else {
        // Staff/Barber Flow
        print("[REG_FLOW] Updating profile for staff: ${effectiveUser.id}");
        
        String? profilePhotoUrl;
        if (_profilePhoto != null) {
          profilePhotoUrl = await apiService.uploadFile(_profilePhoto!);
        }

        List<String> portfolioUrls = [];
        if (_portfolioPhotos.isNotEmpty) {
          for (var photo in _portfolioPhotos) {
            final url = await apiService.uploadFile(photo);
            if (url != null) portfolioUrls.add(url);
          }
        }

        final updateData = {
          'experience': int.tryParse(_expController.text) ?? 0,
          'about': _aboutController.text,
          'location': _detectedCoordinates,
          'profilePhoto': profilePhotoUrl,
          'portfolio': portfolioUrls,
        };
        
        final finalStaffUser = await apiService.updateProfile(effectiveUser.id, updateData);
        if (finalStaffUser != null) {
           User userToPersist = finalStaffUser;
           // If role is still customer, optimistic update to BARBER
           if (finalStaffUser.role == AppRole.customer) {
              userToPersist = finalStaffUser.copyWith(role: AppRole.barber);
           }
           await userProviderNotifier.setUser(userToPersist);
        }
      }
      
      if (mounted) {
         setState(() => _isLoading = false);
         // Navigate to Home
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



  Widget _buildCredentialsStep() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Complete Profile", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const Text("Tell us about yourself to continue", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            _buildInput("Full Name", "John Doe", _nameController),
            const SizedBox(height: 48),
            _buildPrimaryButton("NEXT STEP", () {
              if (_nameController.text.isNotEmpty) {
                 _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter your name"))
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
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Select Your Role", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const Text(
              "Are you a shop owner or a barber working in a shop?",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            _buildRoleCard(
              "Shop Owner",
              "Create and manage your own shop",
              LucideIcons.store,
              Colors.red,
              () => setState(() {
                _selectedRole = 'owner';
                _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
                _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              }),
            ),
          ],
        ),
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
            const Text("Setup Your Shop", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
            const Text("Tell us about your business", style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 32),
            _buildInput("Shop Name", "Enter business name", _shopNameController),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SHOP LOCATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      InkWell(
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
                    ],
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
            const SizedBox(height: 32),
            _buildLegalConsent(),
            const SizedBox(height: 48),
            _buildPrimaryButton(
              "CREATE SHOP & START", 
              _handleFinish,
              enabled: _agreedToPrivacy && _agreedToTerms,
            ),
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
          const Text("Build Your Profile", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
          const Text("Link yourself to a nearby shop to start.", style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 32),
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
          const SizedBox(height: 32),
          _buildLegalConsent(),
          const SizedBox(height: 48),
          _buildPrimaryButton(
            "JOIN SHOP & START", 
            _handleFinish,
            enabled: _agreedToPrivacy && _agreedToTerms,
          ),
          const SizedBox(height: 40),
        ],
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

  Widget _buildLegalConsent() {
    final textColor = isDark ? Colors.white : Colors.black;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _agreedToPrivacy = !_agreedToPrivacy),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _agreedToPrivacy,
                  onChanged: (v) => setState(() => _agreedToPrivacy = v ?? false),
                  activeColor: AppTheme.emerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.6), height: 1.4),
                    children: [
                      const TextSpan(text: "I agree to the "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () {
                             PremiumDialog.showLegal(
                               context: context, 
                               title: 'Privacy Policy', 
                               icon: LucideIcons.shield,
                               content: 'At BarberBook24, we take your privacy seriously. By using this app, you consent to our data practices...'
                             );
                          },
                          child: const Text(
                            "Privacy Policy",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: Checkbox(
                  value: _agreedToTerms,
                  onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                  activeColor: AppTheme.emerald,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, color: textColor.withOpacity(0.6), height: 1.4),
                    children: [
                      const TextSpan(text: "I agree to the "),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () {
                             PremiumDialog.showLegal(
                               context: context, 
                               title: 'Terms of Service', 
                               icon: LucideIcons.scale,
                               content: 'Welcome to BarberBook24. By using our services, you agree to follow our code of conduct and service terms...'
                             );
                          },
                          child: const Text(
                            "Terms of Service",
                            style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.emerald, decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onTap, {bool enabled = true}) {
    final bool isActuallyEnabled = enabled && !_isLoading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isActuallyEnabled 
              ? (isDark ? AppTheme.darkButton : AppTheme.lightButton)
              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
          foregroundColor: isActuallyEnabled ? Colors.white : (isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3)),
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: isActuallyEnabled ? 4 : 0,
        ),
        onPressed: isActuallyEnabled ? onTap : null,
        child: _isLoading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
      ),
    );
  }
}
