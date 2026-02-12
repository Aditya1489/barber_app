import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'shop_preview_screen.dart';
class ShopSettingsScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> shopData;

  const ShopSettingsScreen({super.key, required this.shopData});

  @override
  ConsumerState<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends ConsumerState<ShopSettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;

  final ImagePicker _picker = ImagePicker();
  List<String> _currentPhotos = [];
  List<File> _newPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shopData['name']);
    _phoneController = TextEditingController(text: widget.shopData['phone']);
    _addressController = TextEditingController(text: widget.shopData['address']);
    _descriptionController = TextEditingController(text: widget.shopData['description']);
    _currentPhotos = (widget.shopData['photos'] as List?)?.cast<String>() ?? [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotos() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _newPhotos.addAll(images.map((img) => File(img.path)));
      });
    }
  }

  Future<void> _saveChanges() async {
    final newPhone = _phoneController.text.trim();
    final originalPhone = widget.shopData['phone'] as String?;

    if (newPhone.isNotEmpty && newPhone != originalPhone) {
       // Phone number changed, verify it first
       bool verified = await _verifyNewPhoneNumber(newPhone);
       if (!verified) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone verification failed or cancelled. Changes not saved.')),
            );
         }
         return;
       }
    }

    await _updateShopDetails();
  }

  Future<bool> _verifyNewPhoneNumber(String phone) async {
      setState(() => _isLoading = true);
      final apiService = ref.read(apiServiceProvider);
      
      // 1. Request OTP for UPDATE
      final success = await apiService.requestUpdateOtp(phone);
      setState(() => _isLoading = false);

      if (!success) {
         if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Failed to send OTP. Phone might be in use.')),
             );
         }
         return false;
      }

      if (!mounted) return false;

      // 2. Show Premium OTP Dialog
      final verified = await showGeneralDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierLabel: "Dismiss",
        barrierColor: Colors.black.withOpacity(0.8), // Darker overlay
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (ctx, anim1, anim2) => const SizedBox(),
        transitionBuilder: (ctx, anim1, anim2, child) {
          return Transform.scale(
            scale: Curves.easeOutBack.transform(anim1.value),
            child: FadeTransition(
              opacity: anim1,
              child: PremiumOTPDialog(phone: phone),
            ),
          );
        },
      );

      if (verified != true) return false;

      // The dialog now handles the verification API call internally and returns true ONLY if successful.
      // So we don't need step 3 here.
      return true;

 
  }

  Future<void> _updateShopDetails() async {
    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // 1. Upload new photos first
      List<String> uploadedNewPhotos = [];
      if (_newPhotos.isNotEmpty) {
        for (var photo in _newPhotos) {
          final url = await apiService.uploadFile(photo);
          if (url != null) {
            uploadedNewPhotos.add(url);
          }
        }
      }

      // 2. Merge current photos and uploaded new ones
      final allPhotos = [..._currentPhotos, ...uploadedNewPhotos];

      final updateData = {
        'name': _nameController.text,
        'phone': _phoneController.text,
        'address': _addressController.text,
        'description': _descriptionController.text,
        'photos': allPhotos,
      };

      final result = await apiService.updateShop(widget.shopData['id'], updateData);

      if (mounted) {
        setState(() => _isLoading = false);
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Shop settings updated')),
          );
          context.pop(true); // Return true to indicate update
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update shop')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _previewShop() {
    // Current photos
    List<String> combinedPhotos = List.from(_currentPhotos);
    
    // Add new photos (as file paths)
    // The shop preview screen handles file paths as well
    for (var file in _newPhotos) {
      combinedPhotos.add(file.path);
    }
    
    final previewData = {
      ...widget.shopData,
      'name': _nameController.text,
      'phone': _phoneController.text,
      'address': _addressController.text,
      'description': _descriptionController.text,
      'photos': combinedPhotos,
    };
    
    Navigator.push(
      context, 
      MaterialPageRoute(builder: (_) => ShopPreviewScreen(shopData: previewData))
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: true,
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isDark),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildInput(isDark, 'Shop Name', _nameController, LucideIcons.store),
                      const SizedBox(height: 16),
                      _buildInput(isDark, 'Phone Number', _phoneController, LucideIcons.phone),
                      const SizedBox(height: 16),
                      _buildInput(isDark, 'Address', _addressController, LucideIcons.mapPin, maxLines: 2),
                      const SizedBox(height: 16),
                      _buildInput(isDark, 'Description', _descriptionController, LucideIcons.fileText, maxLines: 3),
                      const SizedBox(height: 24),
                      _buildPhotosSection(isDark),
                      const SizedBox(height: 100), // Spacing
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: _buildSaveButton(),
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
          const Text(
            'Shop Settings',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          IconButton(
             onPressed: _previewShop,
             icon: const Icon(LucideIcons.eye, size: 24),
             tooltip: 'Preview Shop',
             style: IconButton.styleFrom(
               backgroundColor: (ref.watch(themeProvider) ? Colors.white : Colors.black).withOpacity(0.05),
               padding: const EdgeInsets.all(12),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildInput(bool isDark, String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(), 
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), 
            letterSpacing: 1.5
          )
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center, 
            children: [
              Padding(
                padding: maxLines > 1 ? const EdgeInsets.only(top: 12.0) : EdgeInsets.zero,
                child: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  maxLines: maxLines,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      fontSize: 14, 
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), 
                      fontWeight: FontWeight.normal
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Shop Photos'.toUpperCase(), 
          style: TextStyle(
            fontSize: 10, 
            fontWeight: FontWeight.bold, 
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.4), 
            letterSpacing: 1.5
          )
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              // Current Photos
              ..._currentPhotos.map((photo) => _buildPhotoItem(isDark, photo, isLocal: false)),
              
              // New Photos
              ..._newPhotos.map((file) => _buildPhotoItem(isDark, file.path, isLocal: true)),
              
              // Add Button
              InkWell(
                onTap: _pickPhotos,
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
                      Text(
                        'Add'.toUpperCase(), 
                        style: TextStyle(
                          fontSize: 10, 
                          fontWeight: FontWeight.bold, 
                          color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)
                        )
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

  Widget _buildPhotoItem(bool isDark, String path, {required bool isLocal}) {
    // If isLocal is false, it might still be a local path string from DB mock data or a http url
    // So we check startsWith('http')
    
    ImageProvider imageProvider;
    if (isLocal) {
        imageProvider = FileImage(File(path));
    } else {
        final resolved = ref.read(apiServiceProvider).resolveUrl(path);
        if (resolved != null && resolved.startsWith('http')) {
            imageProvider = NetworkImage(resolved);
        } else {
            // Fallback
             imageProvider = FileImage(File(path));
        }
    }

    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
            Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                    onTap: () {
                        setState(() {
                            if (isLocal) {
                                _newPhotos.removeWhere((f) => f.path == path);
                            } else {
                                _currentPhotos.remove(path);
                            }
                        });
                    },
                    child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle
                        ),
                        child: const Icon(LucideIcons.x, size: 12, color: Colors.white),
                    ),
                ),
            )
        ],
      )
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.emerald,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _isLoading ? null : _saveChanges,
        child: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }
}

class PremiumOTPDialog extends ConsumerStatefulWidget {
  final String phone;
  const PremiumOTPDialog({super.key, required this.phone});

  @override
  ConsumerState<PremiumOTPDialog> createState() => _PremiumOTPDialogState();
}

class _PremiumOTPDialogState extends ConsumerState<PremiumOTPDialog> with SingleTickerProviderStateMixin {
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _shakeController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _otpController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      _shakeController.forward(from: 0.0);
      setState(() => _errorText = "Enter full 6-digit code");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final apiService = ref.read(apiServiceProvider);
      // Determine if we are verifying update (shop settings) or login/register
      // For this specific file usage, we know it's verifyUpdateOtp
      final success = await apiService.verifyUpdateOtp(widget.phone, otp);
      
      if (success) {
        if (mounted) Navigator.pop(context, true);
      } else {
        if (mounted) {
           _shakeController.forward(from: 0.0);
           setState(() {
             _errorText = "Invalid Code";
             _isLoading = false;
           });
        }
      }
    } catch (e) {
      if (mounted) {
         setState(() {
           _errorText = "Error: $e";
           _isLoading = false;
         });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85, 
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ],
            border: Border.all(
              color: AppTheme.emerald.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.emerald.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.shieldCheck, color: AppTheme.emerald, size: 32),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                "Verify It's You",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Subtitle
              Text(
                "Enter the 6-digit code sent to\n${widget.phone}",
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              
              // Input
              Transform.translate(
                offset: Offset(_shakeAnimation.value * ( (_shakeController.value * 10).toInt() % 2 == 0 ? 1 : -1), 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _errorText != null ? Colors.red : Colors.transparent,
                    ),
                  ),
                  child: TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8, // Spaced out look
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: "",
                      hintText: "******",
                      hintStyle: TextStyle(
                        color: textColor.withOpacity(0.2),
                        letterSpacing: 8,
                      ),
                    ),
                    onChanged: (val) {
                      if (_errorText != null) setState(() => _errorText = null);
                      if (val.length == 6) _verify();
                    },
                  ),
                ),
              ),
              
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorText!,
                    style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ),

              const SizedBox(height: 32),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _verify,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.emerald,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text("VERIFY", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
