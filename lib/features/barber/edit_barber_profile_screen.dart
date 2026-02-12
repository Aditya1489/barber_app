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
import 'package:barber_sync/widgets/user_avatar.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EditBarberProfileScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> staffBasicInfo;

  const EditBarberProfileScreen({super.key, required this.staffBasicInfo});

  @override
  ConsumerState<EditBarberProfileScreen> createState() => _EditBarberProfileScreenState();
}

class _EditBarberProfileScreenState extends ConsumerState<EditBarberProfileScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  int _experience = 0;
  
  bool _isLoading = true;
  bool _hasChanges = false;
  String? _staffId;
  Map<String, dynamic>? _fullProfile;

  // Image Picking State
  File? _pickedProfileImage;
  bool _removeProfilePhoto = false;
  List<File> _pickedPortfolioImages = [];
  List<String> _existingPortfolioImages = [];
  
  // Skills
  List<String> _selectedSkills = [];
  List<String> _getAvailableSkills() {
    return [
      'Fade',
      'Beard Trim',
      'Kids Haircut',
      'Straight Razor',
      'Scissor Cut',
      'Hair Coloring',
      'Hot Towel Shave',
      'Buzz Cut',
    ];
  }
  
  // Tagging & Pinning (Local UI State for now)
  Map<String, String> _photoTags = {};
  String? _pinnedPhotoUrl;

  final ImagePicker _picker = ImagePicker();
  late AnimationController _successController;

  @override
  void initState() {
    super.initState();
    _staffId = widget.staffBasicInfo['staffId'] ?? widget.staffBasicInfo['id'];
    
    _nameController = TextEditingController(text: widget.staffBasicInfo['name']);
    _descController = TextEditingController();
    
    _nameController.addListener(_onFieldChanged);
    _descController.addListener(_onFieldChanged);

    _successController = AnimationController(vsync: this, duration: 600.ms);
    _loadFullProfile();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _successController.dispose();
    super.dispose();
  }

  void _showPhotoOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = ref.watch(themeProvider);
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBG : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.image, color: AppTheme.emerald),
                title: const Text('Choose Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              if (_pickedProfileImage != null || widget.staffBasicInfo['photo'] != null || widget.staffBasicInfo['imageUrl'] != null)
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                  title: const Text('Remove Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _removePhoto();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    try {
      HapticFeedback.mediumImpact();
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _pickedProfileImage = File(image.path);
          _removeProfilePhoto = false;
          _hasChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to pick image: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removePhoto() {
    HapticFeedback.mediumImpact();
    setState(() {
      _pickedProfileImage = null;
      _removeProfilePhoto = true;
      _hasChanges = true;
    });
  }

  Future<void> _pickPortfolioImages() async {
    final totalImages = _existingPortfolioImages.length + _pickedPortfolioImages.length;
    
    if (totalImages >= 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Maximum 10 images allowed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    HapticFeedback.lightImpact();
    final List<XFile> images = await _picker.pickMultiImage();
    
    if (images.isNotEmpty) {
      final remainingSlots = 10 - totalImages;
      final imagesToAdd = images.take(remainingSlots).toList();
      
      setState(() {
        _pickedPortfolioImages.addAll(imagesToAdd.map((x) => File(x.path)));
        _hasChanges = true;
      });
      
      if (images.length > remainingSlots && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Added $remainingSlots images. Maximum limit reached."),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }
  
  Future<void> _loadFullProfile() async {
    final apiService = ref.read(apiServiceProvider);
    try {
      final profile = await apiService.getStaffProfile(_staffId!);
      if (mounted) {
        if (profile != null) {
          setState(() {
            _fullProfile = profile;
            _nameController.text = profile['name'] ?? "";
            _descController.text = profile['description'] ?? "";
            _experience = (profile['experience'] ?? 0);
            
             if (profile['workPhotos'] != null) {
                _existingPortfolioImages = List<String>.from(profile['workPhotos']);
             }
             
             // Load skills
             if (profile['skills'] != null && profile['skills'].toString().isNotEmpty) {
               _selectedSkills = profile['skills'].toString().split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
             }
             
             _isLoading = false;
             _hasChanges = false;
           });
        } else {
             setState(() => _isLoading = false);
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
      String? profilePhotoUrl;
      if (_pickedProfileImage != null) {
        profilePhotoUrl = await apiService.uploadFile(_pickedProfileImage!);
      }

      List<String> allPortfolioUrls = [..._existingPortfolioImages];
      if (_pickedPortfolioImages.isNotEmpty) {
        final portfolioUrls = await Future.wait(
          _pickedPortfolioImages.map((img) => apiService.uploadFile(img))
        );
        allPortfolioUrls.addAll(portfolioUrls.whereType<String>()); // Filter out nulls
      }

      final Map<String, dynamic> data = {
        'name': _nameController.text,
        'description': _descController.text,
        'experience': _experience,
        if (_removeProfilePhoto) 'profilePhoto': '', // Explicitly set empty to remove
        if (profilePhotoUrl != null && !_removeProfilePhoto) 'profilePhoto': profilePhotoUrl,
        'workPhotos': allPortfolioUrls,
        'skills': _selectedSkills.join(','),  // Save skills as comma-separated string
      };
      
      print('[SAVE_PROFILE] Sending data to backend:');
      print('  - name: ${data['name']}');
      print('  - experience: ${data['experience']}');
      print('  - workPhotos count: ${(data['workPhotos'] as List).length}');
      print('  - workPhotos: ${data['workPhotos']}');
      
      await apiService.updateStaffProfile(_staffId!, data);
      
      if (mounted) {
        HapticFeedback.heavyImpact();
        await _successController.forward();
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.emerald,
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(LucideIcons.checkCircle2, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Profile updated successfully'),
              ],
            ),
          )
        );
        context.pop();
      }
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        setState(() => _isLoading = false);
      }
    }
  }

  void _showTagDialog(String path) {
    String currentTag = _photoTags[path] ?? "";
    final controller = TextEditingController(text: currentTag);
    
    showDialog(
      context: context,

      builder: (context) => AlertDialog(
        title: const Text('Tag This Work'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'e.g. Skin Fade'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _photoTags[path] = controller.text;
                _hasChanges = true;
              });
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _calculateProfileStrengthData() {
    bool hasPhoto = false;
    bool hasBio = false;
    bool hasExp = false;
    bool hasPortfolio = false;
    bool hasSkills = false;

    // Check for profile photo
    final photoUrl = widget.staffBasicInfo['photo']?.toString() ?? '';
    final imageUrl = widget.staffBasicInfo['imageUrl']?.toString() ?? '';
    hasPhoto = !_removeProfilePhoto && 
              (_pickedProfileImage != null || 
               (photoUrl.isNotEmpty && photoUrl != 'null') ||
               (imageUrl.isNotEmpty && imageUrl != 'null'));
    
    // Check for bio
    hasBio = _descController.text.length > 20;

    // Check for experience
    hasExp = _experience > 0;

    // Check for portfolio
    hasPortfolio = _existingPortfolioImages.isNotEmpty || _pickedPortfolioImages.isNotEmpty;

    // Check for skills
    hasSkills = _selectedSkills.isNotEmpty;

    double strength = 0;
    if (hasPhoto) strength += 0.2;
    if (hasBio) strength += 0.2;
    if (hasExp) strength += 0.2;
    if (hasPortfolio) strength += 0.2;
    if (hasSkills) strength += 0.2;
    
    return {
      'strength': strength,
      'hasPhoto': hasPhoto,
      'hasBio': hasBio,
      'hasExp': hasExp,
      'hasPortfolio': hasPortfolio,
      'hasSkills': hasSkills,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeProvider);
    final strengthData = _calculateProfileStrengthData();
    final strength = strengthData['strength'] as double;

    return Scaffold(
      floatingActionButton: _hasChanges ? FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveProfile,
        backgroundColor: AppTheme.emerald,
        icon: _isLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : const Icon(LucideIcons.save, color: Colors.white),
        label: const Text('SAVE CHANGES', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ).animate().scale(curve: Curves.elasticOut) : null,
      body: GradientBackground(
        isDark: isDark,
        child: SafeArea(
          child: Column(
            children: [
               _buildHeader(isDark),
               Expanded(
                 child: _isLoading && _fullProfile == null
                    ? const Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildProfileStrengthMeter(isDark, strengthData),
                              const SizedBox(height: 32),
                              
                              // Profile Photo Section
                              _buildPhotoSection(isDark),
                              const SizedBox(height: 40),
                              
                              _buildTextField(
                                isDark, 
                                'Full Name (Public)', 
                                _nameController, 
                                LucideIcons.user,
                                hint: 'Display Name',
                              ),
                              const SizedBox(height: 24),
                              
                              _buildAboutMeField(isDark),
                              const SizedBox(height: 24),
                              
                              _buildExperienceStepper(isDark),
                              const SizedBox(height: 40),
                              
                              _buildSkillsSection(isDark),
                              const SizedBox(height: 40),
                              
                              _buildPortfolioHeader(isDark),
                              const SizedBox(height: 16),
                              _buildPortfolioGrid(isDark),
                              const SizedBox(height: 100), // Space for FAB
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

  Widget _buildProfileStrengthMeter(bool isDark, Map<String, dynamic> data) {
    final strength = data['strength'] as double;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Profile Strength', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text("${(strength * 100).toInt()}%", style: TextStyle(fontWeight: FontWeight.w900, color: AppTheme.emerald, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: strength, 
              backgroundColor: AppTheme.emerald.withOpacity(0.1), 
              color: AppTheme.emerald, 
              minHeight: 8
            ),
          ),
          const SizedBox(height: 16),
          _buildChecklistItem(data['hasPhoto'], 'Profile Photo'),
          _buildChecklistItem(data['hasBio'], 'Quality Bio'),
          _buildChecklistItem(data['hasExp'], 'Experience Level'),
          _buildChecklistItem(data['hasPortfolio'], 'Professional Portfolio'),
          _buildChecklistItem(data['hasSkills'], 'Skills & Expertise'),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildChecklistItem(bool checked, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(checked ? LucideIcons.checkCircle2 : LucideIcons.circle, color: checked ? AppTheme.emerald : Colors.grey, size: 14),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 11, color: checked ? AppTheme.emerald : Colors.grey, fontWeight: checked ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildPhotoSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 130, height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.emerald.withOpacity(0.2), width: 4),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: UserAvatar(
                    photoUrl: _removeProfilePhoto ? null : (_pickedProfileImage?.path ?? widget.staffBasicInfo['photo'] ?? widget.staffBasicInfo['imageUrl']),
                    name: _nameController.text,
                    radius: 60,
                    fontSize: 40,
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _showPhotoOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.emerald, 
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppTheme.emerald.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                    child: const Icon(LucideIcons.camera, color: Colors.white, size: 20),
                  ),
                ),
              ),
              // Trust Badge
              Positioned(
                top: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                       const Icon(LucideIcons.star, color: Colors.white, size: 12),
                       const SizedBox(width: 4),
                       Text((_fullProfile?['rating']?.toDouble() ?? 0.0).toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Profiles with clear photos get 2× more bookings", style: TextStyle(fontSize: 12, color: AppTheme.emerald, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Opacity(opacity: 0.6, child: const Text("Tap the camera to update your professional look", style: TextStyle(fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildAboutMeField(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("About Me", style: TextStyle(fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
            Text("${_descController.text.length}/150", style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descController,
          maxLines: null,
          minLines: 4,
          maxLength: 150,
          textAlignVertical: TextAlignVertical.top,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 15),
          decoration: InputDecoration(
            hintText: "E.g. 10+ years experience in modern fades & beard styling. I specialize in precision scissor cuts.",
            hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.3), fontSize: 13),
            prefixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Icon(LucideIcons.fileText, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)),
                ),
              ],
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 50),
            filled: true,
            fillColor: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.fromLTRB(16, 20, 20, 20),
          ),
        ),
      ],
    );
  }

  Widget _buildExperienceStepper(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [

        Text("Experience Level (Years Active)", style: TextStyle(fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCardBG : AppTheme.lightCardBG,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_experience > 0) {
                    setState(() {
                      _experience--;
                      _hasChanges = true;
                    });
                    HapticFeedback.lightImpact();
                  }
                },
                icon: const Icon(LucideIcons.minusCircle, color: Colors.redAccent),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text("$_experience", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                    const Text('YEARS ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  if (_experience < 50) {  // Maximum 50 years
                    setState(() {
                      _experience++;
                      _hasChanges = true;
                    });
                    HapticFeedback.lightImpact();
                  }
                },
                icon: Icon(
                  LucideIcons.plusCircle,
                  color: _experience >= 50 ? Colors.grey : AppTheme.emerald,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(child: Text("High experience builds customer trust", style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4)))),
      ],
    );
  }

  Widget _buildPortfolioHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Work Portfolio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
            Text('Showcase your best haircuts and styles', style: TextStyle(fontSize: 11, color: (isDark ? Colors.white : Colors.black).withOpacity(0.4))),
          ],
        ),
        InkWell(
          onTap: _pickPortfolioImages,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: AppTheme.emerald.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(LucideIcons.plus, color: AppTheme.emerald, size: 16),
                const SizedBox(width: 4),
                const Text('ADD', style: TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPortfolioGrid(bool isDark) {
    final allImages = [
      ..._existingPortfolioImages.map((e) => {'path': e, 'isNetwork': true}),
      ..._pickedPortfolioImages.map((e) => {'path': e.path, 'isNetwork': false}),
    ];

    if (allImages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.04),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: (isDark ? Colors.white : Colors.black).withOpacity(0.05), width: 2),
        ),
        child: Column(
          children: [
            const Icon(LucideIcons.imagePlus, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('No photos added yet', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, 
        mainAxisSpacing: 12, 
        crossAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemCount: allImages.length,
      itemBuilder: (context, index) {
        final img = allImages[index];
        return _buildPortfolioThumb(img['path'] as String, isNetwork: img['isNetwork'] as bool, isDark: isDark);
      },
    );
  }

  Widget _buildPortfolioThumb(String path, {required bool isNetwork, required bool isDark}) {
    bool isPinned = _pinnedPhotoUrl == path;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: isPinned ? Border.all(color: AppTheme.emerald, width: 3) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _getImageWidget(path, isNetwork),
          // Delete
          Positioned(
             top: 8, right: 8,
             child: InkWell(
               onTap: () {
                 setState(() {
                   if (isNetwork) _existingPortfolioImages.remove(path);
                   else _pickedPortfolioImages.removeWhere((file) => file.path == path);
                   _hasChanges = true;
                 });
               },
               child: Container(
                 padding: const EdgeInsets.all(6),
                 decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                 child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
               ),
             ),
          ),
          // Pin
          Positioned(
             top: 8, left: 8,
             child: InkWell(
               onTap: () {
                 setState(() => _pinnedPhotoUrl = (_pinnedPhotoUrl == path ? null : path));
                 HapticFeedback.lightImpact();
               },
               child: Container(
                 padding: const EdgeInsets.all(6),
                 decoration: BoxDecoration(color: isPinned ? AppTheme.emerald : Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                 child: Icon(LucideIcons.pin, color: Colors.white, size: 14),
               ),
             ),
          ),
          // Tag Overlay
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: InkWell(
              onTap: () => _showTagDialog(path),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black.withOpacity(0.8), Colors.transparent]),
                ),
                child: Row(
                  children: [
                     Icon(LucideIcons.tag, color: Colors.white.withOpacity(0.7), size: 10),
                     const SizedBox(width: 4),
                     Expanded(
                       child: Text(
                         _photoTags[path] ?? 'Add Tag', 
                         style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                         maxLines: 1,
                       ),
                     ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getImageWidget(String path, bool isNetwork) {
    if (isNetwork) {
      final resolved = ref.read(apiServiceProvider).resolveUrl(path);
      return Image.network(resolved ?? "", fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(LucideIcons.imageOff));
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }

  Widget _buildTextField(bool isDark, String label, TextEditingController controller, IconData icon, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: (isDark ? Colors.white : Colors.black).withOpacity(0.7))),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: (isDark ? Colors.white : Colors.black).withOpacity(0.2), fontSize: 13),
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
            'My Account', // Changed from "Edit Profile" as per UX request to feel "Empowering"
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          _buildPreviewButton(isDark),
        ],
      ),
    );
  }

  Widget _buildPreviewButton(bool isDark) {
     return TextButton.icon(
      onPressed: () {
        context.push('/staff-preview', extra: _fullProfile ?? widget.staffBasicInfo);
      },
      icon: const Icon(LucideIcons.eye, size: 18),
      label: const Text('PREVIEW'),
      style: TextButton.styleFrom(
        foregroundColor: AppTheme.emerald,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        backgroundColor: AppTheme.emerald.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSkillsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.award, size: 20, color: AppTheme.emerald),
            const SizedBox(width: 8),
            const Text(
              'Skills & Expertise',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Select your specialties',
          style: TextStyle(
            fontSize: 12,
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _getAvailableSkills().map((skill) {
            final isSelected = _selectedSkills.contains(skill);
            return InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() {
                  if (isSelected) {
                    _selectedSkills.remove(skill);
                  } else {
                    _selectedSkills.add(skill);
                  }
                  _hasChanges = true;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.emerald
                      : (isDark ? Colors.white : Colors.black).withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.emerald
                        : (isDark ? Colors.white : Colors.black).withOpacity(0.1),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(
                          LucideIcons.check,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    Text(
                      skill,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
