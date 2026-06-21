import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mime/mime.dart';
import 'main.dart';
import 'location_picker_screen.dart';

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

  LatLng? _selectedLocation;
  String? _selectedAddress;

  List<Uint8List> _imageBytesList = [];
  List<String> _imageFileNames = [];
  int _coverIndex = 0;
  bool _loading = false;

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
    super.dispose();
  }

  Future<void> _pickLocationFromMap() async {
    final result = await Navigator.push<LocationResult>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialLocation: _selectedLocation,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedLocation = result.location;
        _selectedAddress = result.address;

        // If the name field is empty, suggest the address as the name
        if (_nameController.text.isEmpty && result.address != null) {
          _nameController.text = result.address!;
        }
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      // withData: true is REQUIRED on Android/iOS. Without it, file_picker
      // only returns a file path (not bytes) on mobile, so file.bytes is
      // null and picked photos silently fail to be added. On web, bytes
      // are always returned regardless of this flag.
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.image,
        withData: true,
      );

      if (result == null) return;

      final validFiles = result.files.where((f) => f.bytes != null).toList();
      final skipped = result.files.length - validFiles.length;

      setState(() {
        _imageBytesList = [..._imageBytesList, ...validFiles.map((f) => f.bytes!)];
        _imageFileNames = [..._imageFileNames, ...validFiles.map((f) => f.name)];
        _coverIndex = 0;
      });

      if (skipped > 0 && mounted) {
        _showError('$skipped photo(s) could not be read and were skipped.');
      } else if (validFiles.isNotEmpty && mounted) {
        final totalMb = validFiles.fold<int>(0, (sum, f) => sum + f.size) / (1024 * 1024);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${validFiles.length} photo(s) selected • ${totalMb.toStringAsFixed(1)} MB total (full quality, not compressed)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError('Failed to pick images: $e');
    }
  }

  // Moves the photo at [index] to the front of the list, which is what
  // marks it as the cover photo (index 0 is always treated as the cover,
  // both in the UI badge below and in _uploadImages/_submitSuggestion
  // where imageUrls[0] becomes cover_image).
  void _setCover(int index) {
    if (index == 0) return; // already the cover, nothing to do
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

      // Detect the real image MIME type from the file extension so the
      // original bytes are served back with the correct Content-Type
      // (uploadBinary defaults to a generic binary type otherwise).
      String mimeType = lookupMimeType(_imageFileNames[i]) ?? 'image/jpeg';
      if (!mimeType.startsWith('image/')) mimeType = 'image/jpeg';

      try {
        await supabase.storage.from('place-suggestions').uploadBinary(
          filePath,
          bytes,
          fileOptions: FileOptions(contentType: mimeType, cacheControl: '3600'),
        );
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
        'latitude': _selectedLocation?.latitude,
        'longitude': _selectedLocation?.longitude,
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

  Widget _buildLocationPicker() {
    final bool hasLocation = _selectedLocation != null;

    return GestureDetector(
      onTap: _pickLocationFromMap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasLocation ? softSage : Colors.grey.shade300,
            width: hasLocation ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasLocation ? darkTeal : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasLocation ? Icons.location_on_rounded : Icons.add_location_alt_rounded,
                color: hasLocation ? Colors.white : Colors.grey.shade500,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasLocation ? 'Location Selected' : 'Pin on Map (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: hasLocation ? darkTeal : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasLocation
                        ? (_selectedAddress ?? 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}')
                        : 'Tap to open map and drop a pin',
                    style: TextStyle(
                      fontSize: 12,
                      color: hasLocation ? softSage : Colors.grey.shade400,
                      fontWeight: hasLocation ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              hasLocation ? Icons.edit_location_alt_rounded : Icons.chevron_right_rounded,
              color: hasLocation ? softSage : Colors.grey.shade400,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // Single photo thumbnail in the horizontal picker strip.
  // Tapping anywhere on the photo (other than the remove "x") makes it
  // the cover photo. The star badge mirrors that state, and also acts as
  // a secondary tap target for users who look for an explicit control.
  Widget _buildPhotoThumbnail(int index) {
    final bool isCover = index == 0;

    return GestureDetector(
      onTap: () => _setCover(index),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.all(isCover ? 2.5 : 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isCover ? Border.all(color: darkTeal, width: 2.5) : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCover ? 9.5 : 12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                _imageBytesList[index],
                fit: BoxFit.cover,
              ),

              if (isCover)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: darkTeal, borderRadius: BorderRadius.circular(4)),
                    child: const Text(
                      'COVER',
                      style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _imageBytesList.removeAt(index);
                      _imageFileNames.removeAt(index);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                  ),
                ),
              ),

              // Explicit "set as cover" affordance, doubles as a status
              // indicator (filled star = current cover).
              Positioned(
                bottom: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _setCover(index),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: isCover ? darkTeal : Colors.black.withOpacity(0.45),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isCover ? Icons.star_rounded : Icons.star_border_rounded,
                      color: Colors.white,
                      size: 16,
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
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                _buildLocationPicker(),
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
                  decoration: _buildInputDecoration(label: 'Entry Fee', prefixIcon: Icons.payments_rounded, hint: 'e.g., Free or 50 BDT'),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _openingHoursController,
                  decoration: _buildInputDecoration(label: 'Opening Hours', prefixIcon: Icons.access_time_filled_rounded, hint: 'e.g., 9 AM - 6 PM'),
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(height: 32),

                const Text(
                  'Upload Photos',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: darkTeal),
                ),
                const SizedBox(height: 12),

                if (_imageBytesList.isEmpty)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_rounded, color: Colors.grey.shade400, size: 40),
                          const SizedBox(height: 8),
                          Text('Tap to select photos', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _imageBytesList.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _imageBytesList.length) {
                              return GestureDetector(
                                onTap: _pickImages,
                                child: Container(
                                  width: 100,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade300),
                                  ),
                                  child: Icon(Icons.add, color: Colors.grey.shade400),
                                ),
                              );
                            }
                            return _buildPhotoThumbnail(index);
                          },
                        ),
                      ),
                      if (_imageBytesList.length > 1) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tap a photo (or its star) to set it as the cover image',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitSuggestion,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: darkTeal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Submit Suggestion', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}