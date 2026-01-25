import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:barber_sync/core/theme/app_theme.dart';
import 'package:barber_sync/core/providers/theme_provider.dart';
import 'package:barber_sync/services/api_service.dart';
import 'package:barber_sync/widgets/gradient_background.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class EditBarberProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> staffBasicInfo;

  const EditBarberProfileScreen({super.key, required this.staffBasicInfo});

  @override
  ConsumerState<EditBarberProfileScreen> createState() => _EditBarberProfileScreenState();
}

class _EditBarberProfileScreenState extends ConsumerState<EditBarberProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _descController;
  late TextEditingController _expController;
  
  bool _isLoading = true;
  String? _staffId;

  // Image Picking State
  File? _pickedProfileImage;
  List<File> _pickedPortfolioImages = [];
  List<String> _existingPortfolioImages = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _staffId = widget.staffBasicInfo['staffId'] ?? widget.staffBasicInfo['id'];
    
    _nameController = TextEditingController(text: widget.staffBasicInfo['name']);
    _phoneController = TextEditingController(); 
    _descController = TextEditingController();
    _expController = TextEditingController();
    
    _loadFullProfile();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _pickedProfileImage = File(image.path));
    }
  }

  Future<void> _pickPortfolioImages() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _pickedPortfolioImages.addAll(images.map((x) => File(x.path)));
      });
    }
  }
  
  Future<void> _loadFullProfile() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final profile = await apiService.getStaffProfile(_staffId!);
      if (mounted) {
        if (profile != null) {
          setState(() {
            _nameController.text = profile['name'] ?? "";
            _descController.text = profile['description'] ?? "";
            _expController.text = (profile['experience'] ?? 0).toString();
            
            // Populate existing portfolio
            if (profile['workPhotos'] != null) {
               _existingPortfolioImages = List<String>.from(profile['workPhotos']);
            }
            
            _isLoading = false;
          });
        } else {
             setState(() => _isLoading = false);
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to load profile details")));
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    final apiService = ref.read(apiServiceProvider);
    
    try {
      final data = {
        'name': _nameController.text,
        'description': _descController.text,
        'experience': int.tryParse(_expController.text) ?? 0,
        if (_pickedProfileImage != null) 'profilePhoto': _pickedProfileImage!.path,
        'portfolio': [
           ..._existingPortfolioImages,
           ..._pickedPortfolioImages.map((f) => f.path)
        ],
      };
      
      await apiService.updateStaffProfile(_staffId!, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile updated!")));
        context.pop();
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);

    return Scaffold(
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
               _buildHeader(isDark),
               Expanded(
                 child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Profile Photo Picker
                              Center(
                                child: Column(
                                  children: [
                                    Stack(
                                      children: [
                                        CircleAvatar(
                                          radius: 60,
                                          backgroundImage: _pickedProfileImage != null
                                              ? FileImage(_pickedProfileImage!)
                                              : (_getProfileImageProvider(widget.staffBasicInfo['photo'] ?? widget.staffBasicInfo['imageUrl'])),
                                        ),
                                        Positioned(
                                          bottom: 0,
                                          right: 0,
                                          child: InkWell(
                                            onTap: _pickImage,
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: const BoxDecoration(color: AppTheme.emerald, shape: BoxShape.circle),
                                              child: const Icon(LucideIcons.camera, color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      "Personal Profile Photo",
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                                    ),
                                    Text(
                                      "This photo represents YOU in the staff list.",
                                      style: TextStyle(fontSize: 12, color: (isDark ? Colors.white : Colors.black).withOpacity(0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              
                              _buildTextField(isDark, "My Full Name", _nameController, LucideIcons.user),
                              const SizedBox(height: 16),
                              _buildTextField(isDark, "About Me", _descController, LucideIcons.fileText, maxLines: 4),
                              const SizedBox(height: 16),
                              _buildTextField(isDark, "Experience (Years)", _expController, LucideIcons.calendar, isNumber: true),
                              const SizedBox(height: 24),
                              
                              // Portfolio Section
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Work Portfolio", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black)),
                                  TextButton.icon(
                                    onPressed: _pickPortfolioImages,
                                    icon: const Icon(LucideIcons.plus, size: 16),
                                    label: const Text("Add Photos"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 100,
                                child: ListView(
                                  scrollDirection: Axis.horizontal,
                                  children: [
                                    ..._existingPortfolioImages.map((url) => _buildThumb(url, isNetwork: true)),
                                    ..._pickedPortfolioImages.map((file) => _buildThumb(file, isNetwork: false)),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 40),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.emerald,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _saveProfile,
                                  child: const Text("Save Changes", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumb(dynamic imageSource, {required bool isNetwork}) {
    return Container(
      width: 100,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          isNetwork 
           ? (imageSource.toString().startsWith('http') 
              ? Image.network(imageSource, fit: BoxFit.cover)
              : Image.file(File(imageSource), fit: BoxFit.cover)) // Handle existing local paths
           : Image.file(imageSource, fit: BoxFit.cover),
          Positioned(
             top: 4, right: 4,
             child: InkWell(
               onTap: () {
                 setState(() {
                   if (isNetwork) {
                     _existingPortfolioImages.remove(imageSource);
                   } else {
                     _pickedPortfolioImages.remove(imageSource);
                   }
                 });
               },
               child: Container(
                 padding: const EdgeInsets.all(4),
                 decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), shape: BoxShape.circle),
                 child: const Icon(Icons.close, color: Colors.white, size: 14),
               ),
             ),
          ),
        ],
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
            "Edit Profile",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(bool isDark, String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
            filled: true,
            fillColor: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
          validator: (val) => val == null || val.isEmpty ? "Required" : null,
        ),
      ],
    );
  }
  ImageProvider _getProfileImageProvider(String? path) {
    if (path == null || path.isEmpty) {
      return const NetworkImage("https://picsum.photos/200");
    }
    if (path.startsWith('http')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
  }
}
