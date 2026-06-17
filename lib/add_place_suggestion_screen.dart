import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class AddPlaceSuggestionScreen extends StatefulWidget {
  final String division;
  const AddPlaceSuggestionScreen({super.key, required this.division});

  @override
  State<AddPlaceSuggestionScreen> createState() => _AddPlaceSuggestionScreenState();
}

class _AddPlaceSuggestionScreenState extends State<AddPlaceSuggestionScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _historyController = TextEditingController();
  final _bestTimeController = TextEditingController();
  final _entryFeeController = TextEditingController();
  final _openingHoursController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  List<Uint8List> _imageBytesList = [];
  List<String> _imageFileNames = [];
  int _coverIndex = 0;
  bool _loading = false;

  // App Palette Mapped Locally
  static const Color darkTeal = Color(0xFF0B2B26);
  static const Color softSage = Color(0xFF8EB69B);
  static const Color bgLilac = Color(0xFFF2F0FA);

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _historyController.dispose();
    _bestTimeController.dispose();
    _entryFeeController.dispose();
    _openingHoursController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );

    if (result != null) {
      setState(() {
        _imageBytesList = result.files.map((file) => file.bytes!).toList();
        _imageFileNames = result.files.map((file) => file.name).toList();
        _coverIndex = 0;
      });
    }
  }

  void _setCover(int index) {
    setState(() {
      final selectedBytes = _imageBytesList.removeAt(index);
      final selectedName = _imageFileNames.removeAt(index);
      _imageBytesList.insert(0, selectedBytes);
      _imageFileNames.insert(0, selectedName);
      _coverIndex = 0;
    });
  }

  Future<List<String>> _uploadImages() async {
    List<String> uploadedUrls = [];
    final user = supabase.auth.currentUser!;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final userFolder = user.id;

    for (int i = 0; i < _imageBytesList.length; i++) {
      final bytes = _imageBytesList[i];
      final ext = _imageFileNames[i].split('.').last;
      final fileName = '${user.id}_${timestamp}_$i.$ext';
      final filePath = '$userFolder/$fileName';

      try {
        await supabase.storage.from('place-suggestions').uploadBinary(filePath, bytes);
        final publicUrl = supabase.storage.from('place-suggestions').getPublicUrl(filePath);
        uploadedUrls.add(publicUrl);
      } catch (e) {
        throw Exception('Failed to upload image ${_imageFileNames[i]}: $e');
      }
    }
    return uploadedUrls;
  }

  Future<void> _submitSuggestion() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Place name is required');
      return;
    }

    setState(() => _loading = true);
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showError('You must be logged in');
      setState(() => _loading = false);
      return;
    }

    try {
      List<String> imageUrls = [];
      String? coverImageUrl;

      if (_imageBytesList.isNotEmpty) {
        imageUrls = await _uploadImages();
        if (imageUrls.isEmpty) {
          throw Exception('No images were uploaded. Please try again.');
        }
        coverImageUrl = imageUrls[0];
      }

      await supabase.from('place_suggestions').insert({
        'division': widget.division,
        'name': name,
        'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
        'category': _categoryController.text.trim().isEmpty ? null : _categoryController.text.trim(),
        'history': _historyController.text.trim().isEmpty ? null : _historyController.text.trim(),
        'best_time_to_visit': _bestTimeController.text.trim().isEmpty ? null : _bestTimeController.text.trim(),
        'entry_fee': _entryFeeController.text.trim().isEmpty ? null : _entryFeeController.text.trim(),
        'opening_hours': _openingHoursController.text.trim().isEmpty ? null : _openingHoursController.text.trim(),
        'latitude': _latController.text.trim().isEmpty ? null : double.tryParse(_latController.text.trim()),
        'longitude': _lngController.text.trim().isEmpty ? null : double.tryParse(_lngController.text.trim()),
        'images': imageUrls,
        'cover_image': coverImageUrl,
        'suggested_by': user.id,
        'status': 'pending',
      });

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Suggestion submitted! Admin will review it.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to submit: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData prefixIcon, String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(prefixIcon, color: darkTeal.withOpacity(0.6), size: 22),
      labelStyle: TextStyle(color: darkTeal.withOpacity(0.7), fontSize: 14),
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      alignLabelWithHint: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: darkTeal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent.shade400, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.redAccent.shade700, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLilac,
      appBar: AppBar(
        title: const Text(
          'Suggest a Place',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: darkTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on background tap
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Meta Information Banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: darkTeal.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: darkTeal.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.map_rounded, color: darkTeal),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Destination Area',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${widget.division} Division',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkTeal),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Core details inputs
                TextFormField(
                  controller: _nameController,
                  decoration: _buildInputDecoration(label: 'Place Name *', prefixIcon: Icons.location_city_rounded),
                  style: const TextStyle(fontSize: 15),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Please enter the place name' : null,
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _categoryController,
                  decoration: _buildInputDecoration(
                    label: 'Category',
                    prefixIcon: Icons.category_rounded,
                    hint: 'e.g., Beach, Historical, Forest Resort',
                  ),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: _buildInputDecoration(label: 'Short Description', prefixIcon: Icons.description_rounded),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _historyController,
                  maxLines: 4,
                  decoration: _buildInputDecoration(label: 'History & Background Heritage', prefixIcon: Icons.auto_stories_rounded),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _bestTimeController,
                  decoration: _buildInputDecoration(label: 'Best Time to Visit', prefixIcon: Icons.wb_sunny_rounded, hint: 'e.g., October to March'),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _entryFeeController,
                  decoration: _buildInputDecoration(label: 'Entry Fee Structure', prefixIcon: Icons.payments_rounded, hint: 'e.g., Free / ৳20 entry rate'),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _openingHoursController,
                  decoration: _buildInputDecoration(label: 'Opening Hours', prefixIcon: Icons.alarm_rounded, hint: 'e.g., 9:00 AM – 5:00 PM'),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                // Coordinate Grouping
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _buildInputDecoration(label: 'Latitude (Optional)', prefixIcon: Icons.pin_drop_rounded),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextFormField(
                        controller: _lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Longitude (Optional)',
                          labelStyle: TextStyle(color: darkTeal.withOpacity(0.7), fontSize: 14),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: darkTeal, width: 1.5),
                          ),
                        ),
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Media picker Header Info
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Visual Showcases',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: darkTeal),
                    ),
                    if (_imageBytesList.isNotEmpty)
                      TextButton.icon(
                        onPressed: _pickImages,
                        icon: const Icon(Icons.refresh_rounded, size: 18, color: softSage),
                        label: const Text('Reselect', style: TextStyle(color: softSage, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 10),

                // Interactive Media Slot View Container
                if (_imageBytesList.isEmpty)
                  InkWell(
                    onTap: _pickImages,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: 130,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: softSage.withOpacity(0.4), width: 1.5, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, size: 42, color: softSage.withOpacity(0.8)),
                          const SizedBox(height: 8),
                          Text(
                            'Select Beautiful Destination Images',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text('Supports multiple image selections', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 110,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageBytesList.length,
                          itemBuilder: (context, index) {
                            final isCover = (index == _coverIndex);
                            return GestureDetector(
                              onTap: () => _setCover(index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 110,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isCover ? softSage : Colors.transparent,
                                    width: isCover ? 3 : 0,
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(isCover ? 8 : 10),
                                        child: Image.memory(
                                          _imageBytesList[index],
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    if (isCover)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: darkTeal,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.star_rounded, color: Colors.white, size: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 10, left: 2),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 13, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              'Tap an image thumbnail to set it as the cover display photo.',
                              style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 40),

                // Action Submission CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitSuggestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkTeal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: darkTeal.withOpacity(0.6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                        : const Text(
                      'Submit Place Suggestion',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}