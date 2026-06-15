import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import 'main.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bloodGroupController = TextEditingController();
  final _locationController = TextEditingController();
  final _dobController = TextEditingController();
  final _genderController = TextEditingController();
  final _userLanguagesController = TextEditingController();

  // Tour guide specific fields
  final _guideDivisionController = TextEditingController();
  final _languagesController = TextEditingController();
  final _pricePerDayController = TextEditingController();
  final _bioController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _profile;
  String _originalName = '';
  bool _isTourGuide = false;
  bool _isApproved = true;
  String? _avatarUrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      setState(() {
        _profile = data;
        _originalName = data['full_name'] ?? '';
        _nameController.text = _originalName;
        _phoneController.text = data['phone'] ?? '';
        _bloodGroupController.text = data['blood_group'] ?? '';
        _locationController.text = data['location'] ?? '';
        _dobController.text = data['date_of_birth'] != null
            ? data['date_of_birth'].toString().substring(0, 10)
            : '';
        _genderController.text = data['gender'] ?? '';
        _userLanguagesController.text =
            (data['user_languages'] as List?)?.join(', ') ?? '';

        final rawAvatarUrl = data['avatar_url'];
        _avatarUrl = (rawAvatarUrl != null && rawAvatarUrl.toString().isNotEmpty) ? rawAvatarUrl : null;

        _isTourGuide = data['role'] == 'tour_guide';
        _isApproved = data['is_approved'] ?? true;
        if (_isTourGuide) {
          _guideDivisionController.text = data['guide_division'] ?? '';
          _languagesController.text =
              (data['languages'] as List?)?.join(', ') ?? '';
          _pricePerDayController.text =
              (data['price_per_day'] ?? 0).toString();
          _bioController.text = data['bio'] ?? '';
        }
      });
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<bool> _verifyCurrentPassword(String password) async {
    final user = supabase.auth.currentUser;
    if (user == null || user.email == null) return false;
    try {
      await supabase.auth.signInWithPassword(
        email: user.email!,
        password: password,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  // ✅ FIXED: Works on web, Android, iOS
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );
      if (image == null) return;

      setState(() => _loading = true);
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get file bytes
      final Uint8List bytes = await image.readAsBytes();

      // Determine file extension and MIME type robustly (works on web & mobile)
      String filePath = image.path;        // e.g., /data/.../image.jpg or blob:http:...
      String fileName = image.name;        // e.g., image.jpg (works on web!)
      String extension = '';

      // First try to get extension from file name (works everywhere)
      if (fileName.contains('.')) {
        extension = fileName.substring(fileName.lastIndexOf('.'));
      } else if (filePath.contains('.') && !filePath.startsWith('blob:')) {
        // Fallback for mobile paths (not blob)
        extension = filePath.substring(filePath.lastIndexOf('.'));
      }

      // If still no extension, default to .jpg
      if (extension.isEmpty) extension = '.jpg';

      // Get MIME type from extension
      String mimeType = lookupMimeType('dummy$extension') ?? 'image/jpeg';
      if (!mimeType.startsWith('image/')) {
        mimeType = 'image/jpeg'; // fallback
      }

      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String fileNameFinal = '$timestamp$extension';
      final String storagePath = '${user.id}/$fileNameFinal';

      // Upload with correct Content-Type
      await supabase.storage.from('avatars').uploadBinary(
        storagePath,
        bytes,
        fileOptions: FileOptions(
          contentType: mimeType,
          upsert: true,
        ),
      );

      final String publicUrl = supabase.storage.from('avatars').getPublicUrl(storagePath);

      // Update profile table
      await supabase
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() => _avatarUrl = publicUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated successfully!')),
        );
      }
    } catch (e) {
      print('Upload error: $e');
      String errorMsg = 'Failed to upload image. ';
      final String errorString = e.toString().toLowerCase();
      if (errorString.contains('bucket not found')) {
        errorMsg = 'Storage bucket "avatars" not found. Please run the SQL script to create it.';
      } else if (errorString.contains('row level security') || errorString.contains('permission denied')) {
        errorMsg = 'Permission denied. Check Supabase Storage policies for bucket "avatars".';
      } else {
        errorMsg += e.toString();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) {
      _showError('Full name cannot be empty.');
      return;
    }

    Map<String, dynamic> updates = {
      'full_name': newName,
      'phone': _phoneController.text.trim(),
      'blood_group': _bloodGroupController.text.trim().isEmpty
          ? null
          : _bloodGroupController.text.trim(),
      'location': _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      'date_of_birth': _dobController.text.trim().isEmpty
          ? null
          : _dobController.text.trim(),
      'gender': _genderController.text.trim().isEmpty
          ? null
          : _genderController.text.trim(),
      'user_languages': _userLanguagesController.text.trim().isEmpty
          ? []
          : _userLanguagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
    };

    if (_isTourGuide && _isApproved) {
      updates['guide_division'] = _guideDivisionController.text.trim().isEmpty
          ? null
          : _guideDivisionController.text.trim();
      updates['languages'] = _languagesController.text.trim().isEmpty
          ? []
          : _languagesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      updates['price_per_day'] =
          double.tryParse(_pricePerDayController.text.trim()) ?? 0;
      updates['bio'] = _bioController.text.trim().isEmpty
          ? null
          : _bioController.text.trim();
    }

    bool hasChanges = false;
    if (_originalName != newName) hasChanges = true;
    if (_profile != null) {
      if ((_profile!['phone'] ?? '') != (_phoneController.text.trim())) hasChanges = true;
      if ((_profile!['blood_group'] ?? '') != (_bloodGroupController.text.trim())) hasChanges = true;
      if ((_profile!['location'] ?? '') != (_locationController.text.trim())) hasChanges = true;
      if ((_profile!['date_of_birth']?.toString().substring(0,10) ?? '') != (_dobController.text.trim())) hasChanges = true;
      if ((_profile!['gender'] ?? '') != (_genderController.text.trim())) hasChanges = true;
      List<String> oldLangs = List<String>.from(_profile!['user_languages'] ?? []);
      List<String> newLangs = List<String>.from(updates['user_languages'] ?? []);
      if (oldLangs.length != newLangs.length || oldLangs.join(',') != newLangs.join(',')) hasChanges = true;
      if (_isTourGuide && _isApproved) {
        if ((_profile!['guide_division'] ?? '') != (_guideDivisionController.text.trim())) hasChanges = true;
        List<String> oldGuideLangs = List<String>.from(_profile!['languages'] ?? []);
        List<String> newGuideLangs = List<String>.from(updates['languages'] ?? []);
        if (oldGuideLangs.length != newGuideLangs.length || oldGuideLangs.join(',') != newGuideLangs.join(',')) hasChanges = true;
        if ((_profile!['price_per_day'] ?? 0) != updates['price_per_day']) hasChanges = true;
        if ((_profile!['bio'] ?? '') != (_bioController.text.trim())) hasChanges = true;
      }
    }

    if (!hasChanges) {
      _showError('No changes to save.');
      return;
    }

    final passwordController = TextEditingController();
    bool verified = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter your current password to save changes.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final ok = await _verifyCurrentPassword(passwordController.text.trim());
              Navigator.pop(ctx, ok);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    ).then((value) => verified = value ?? false);

    if (!verified) {
      _showError('Incorrect password. Changes not saved.');
      return;
    }

    setState(() => _loading = true);
    try {
      if (newName != _originalName) {
        final existing = await supabase
            .from('profiles')
            .select('id')
            .eq('full_name', newName)
            .maybeSingle();
        if (existing != null) {
          _showError('This name is already taken.');
          setState(() => _loading = false);
          return;
        }
      }

      await supabase.from('profiles').update(updates).eq('id', user.id);
      _originalName = newName;
      await _loadProfile();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
            (_) => false,
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dobController.text.isNotEmpty
          ? DateTime.tryParse(_dobController.text) ?? DateTime.now().subtract(const Duration(days: 18 * 365))
          : DateTime.now().subtract(const Duration(days: 18 * 365)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MyApp.primaryColor,
              onPrimary: Colors.white,
              onSurface: MyApp.primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text = picked.toIso8601String().substring(0, 10);
      });
    }
  }

  InputDecoration _getInputDecoration({required String label, required IconData icon, String? hint}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      floatingLabelStyle: const TextStyle(color: MyApp.primaryColor, fontWeight: FontWeight.w600),
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black26, fontSize: 13),
      prefixIcon: Icon(icon, color: MyApp.primaryColor.withOpacity(0.7), size: 22),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.withOpacity(0.1), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: MyApp.secondaryColor, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: MyApp.scaffoldBackground,
        appBar: AppBar(title: const Text('Profile'), backgroundColor: MyApp.primaryColor),
        body: const Center(child: Text('Not logged in.', style: TextStyle(color: MyApp.primaryColor))),
      );
    }

    return Scaffold(
      backgroundColor: MyApp.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white)),
        backgroundColor: MyApp.primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _signOut,
            tooltip: 'Sign Out',
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: MyApp.secondaryColor, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: MyApp.primaryColor.withOpacity(0.1),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                              ]
                          ),
                          child: CircleAvatar(
                            radius: 52,
                            backgroundColor: Colors.white,
                            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                            child: _avatarUrl == null
                                ? const Icon(Icons.person, size: 55, color: MyApp.secondaryColor)
                                : null,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: MyApp.primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _originalName.isNotEmpty ? _originalName : 'User Profile',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MyApp.primaryColor),
                  ),
                  const SizedBox(height: 4),
                  Text(user.email ?? '', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const SizedBox(height: 14),

                  if (_profile != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _profile!['role'] == 'admin'
                            ? const Color(0xFFFFECB3)
                            : (_profile!['role'] == 'tour_guide'
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFE3F2FD)),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        'Role: ${_profile!['role'].toString().toUpperCase()}${_profile!['role'] == 'tour_guide' && _profile!['is_approved'] == false ? ' (Pending)' : ''}',
                        style: TextStyle(
                          color: _profile!['role'] == 'admin'
                              ? const Color(0xFFFF8F00)
                              : (_profile!['role'] == 'tour_guide'
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFF1565C0)),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),
            const Text('Basic Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
            const SizedBox(height: 12),

            _buildTextField(_nameController, 'Full Name *', Icons.person),
            const SizedBox(height: 14),
            _buildTextField(_phoneController, 'Phone Number', Icons.phone, keyboardType: TextInputType.phone),
            const SizedBox(height: 14),
            _buildDropdownField(
              _bloodGroupController,
              'Blood Group',
              Icons.bloodtype,
              ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
            ),
            const SizedBox(height: 14),
            _buildTextField(_locationController, 'Location (City/Area)', Icons.location_on),
            const SizedBox(height: 14),
            _buildDateField(_dobController, 'Date of Birth', Icons.cake),
            const SizedBox(height: 14),
            _buildDropdownField(
              _genderController,
              'Gender',
              Icons.person_outline,
              ['Male', 'Female'],
            ),
            const SizedBox(height: 14),
            _buildTextField(_userLanguagesController, 'Languages (comma separated)', Icons.translate,
                hint: 'e.g., English, Bangla, Hindi'),

            if (_isTourGuide && _isApproved) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  const Icon(Icons.explore, color: MyApp.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  const Text('Tour Guide Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(_guideDivisionController, 'Operating Division', Icons.location_city),
              const SizedBox(height: 14),
              _buildTextField(_languagesController, 'Languages (comma separated)', Icons.g_translate,
                  hint: 'e.g., English, Bangla'),
              const SizedBox(height: 14),
              _buildTextField(_pricePerDayController, 'Price per Day (BDT)', Icons.payments,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 14),
              _buildTextField(_bioController, 'Bio / Experience', Icons.assignment, maxLines: 3),
            ],

            if (_isTourGuide && !_isApproved)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(top: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFB74D).withOpacity(0.5)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                        child: Text(
                            'Your tour guide profile is currently pending administrator verification. Settings will unlock post approval.',
                            style: TextStyle(color: Color(0xFFE65100), fontSize: 13, height: 1.4))),
                  ],
                ),
              ),

            const SizedBox(height: 36),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _loading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MyApp.primaryColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton.icon(
                onPressed: _signOut,
                icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                label: const Text('Sign Out Account', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600, fontSize: 15)),
                style: TextButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.2)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      {TextInputType keyboardType = TextInputType.text, int maxLines = 1, String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: MyApp.primaryColor, fontSize: 15),
      decoration: _getInputDecoration(label: label, icon: icon, hint: hint),
    );
  }

  Widget _buildDropdownField(TextEditingController controller, String label, IconData icon, List<String> items) {
    return DropdownButtonFormField<String>(
      value: controller.text.isEmpty ? null : controller.text,
      style: const TextStyle(color: MyApp.primaryColor, fontSize: 15),
      decoration: _getInputDecoration(label: label, icon: icon),
      dropdownColor: Colors.white,
      icon: const Icon(Icons.arrow_drop_down, color: MyApp.primaryColor),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(color: MyApp.primaryColor)))).toList(),
      onChanged: (value) {
        setState(() {
          controller.text = value ?? '';
        });
      },
    );
  }

  Widget _buildDateField(TextEditingController controller, String label, IconData icon) {
    return GestureDetector(
      onTap: _selectDate,
      child: AbsorbPointer(
        child: TextField(
          controller: controller,
          style: const TextStyle(color: MyApp.primaryColor, fontSize: 15),
          decoration: _getInputDecoration(label: label, icon: icon, hint: 'YYYY-MM-DD'),
        ),
      ),
    );
  }
}