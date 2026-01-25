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
    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      
      // Merge current photos and new photos (upload logic assumed handled by backend or paths sent)
      // For now, sending new local paths as "photos" along with old ones
      final allPhotos = [..._currentPhotos, ..._newPhotos.map((f) => f.path)];

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
            const SnackBar(content: Text('Shop settings updated successfully')),
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
                      _buildInput(isDark, "Shop Name", _nameController, LucideIcons.store),
                      const SizedBox(height: 16),
                      _buildInput(isDark, "Phone Number", _phoneController, LucideIcons.phone),
                      const SizedBox(height: 16),
                      _buildInput(isDark, "Address", _addressController, LucideIcons.mapPin, maxLines: 2),
                      const SizedBox(height: 16),
                      _buildInput(isDark, "Description", _descriptionController, LucideIcons.fileText, maxLines: 3),
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
            "Shop Settings",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
            children: [
              Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), size: 18),
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
          "SHOP PHOTOS", 
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
                        "ADD", 
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
        if (path.startsWith('http')) {
            imageProvider = NetworkImage(path);
        } else {
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
          : const Text("SAVE CHANGES", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
      ),
    );
  }
}
