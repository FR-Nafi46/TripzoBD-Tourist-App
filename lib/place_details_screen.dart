import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'main.dart';

class PlaceDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PlaceDetailsScreen({super.key, required this.place});

  @override
  State<PlaceDetailsScreen> createState() => _PlaceDetailsScreenState();
}

class _PlaceDetailsScreenState extends State<PlaceDetailsScreen> {
  int _currentImageIndex = 0;
  late List<String> _images;
  bool _addingPhotos = false;
  bool _deletingPhoto = false;
  final PageController _pageController = PageController();

  // Review & Rating state
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;
  double _avgRating = 0.0;
  int _totalReviews = 0;
  Map<String, dynamic>? _userReview;
  int _userRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submittingReview = false;
  bool _editingReview = false;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _loadReviewsAndRating();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  void _loadImages() {
    _images = [];
    if (widget.place['images'] != null && widget.place['images'] is List) {
      _images = List<String>.from(widget.place['images'].map((e) => e.toString()));
    }
    final cover = widget.place['cover_image'];
    if (cover != null && cover.toString().isNotEmpty) {
      String coverUrl = cover.toString();
      if (!_images.contains(coverUrl)) {
        _images.insert(0, coverUrl);
      }
    }
    final legacy = widget.place['image_url'];
    if (_images.isEmpty && legacy != null && legacy.toString().isNotEmpty) {
      _images = [legacy.toString()];
    }
  }

  Future<void> _loadReviewsAndRating() async {
    setState(() => _reviewsLoading = true);
    final placeId = widget.place['id'];
    final user = supabase.auth.currentUser;
    try {
      // Updated to fetch avatar_url from the profiles table relational link
      final reviewsData = await supabase
          .from('place_reviews')
          .select('*, profiles(full_name, avatar_url)')
          .eq('place_id', placeId)
          .order('created_at', ascending: false);

      _reviews = List<Map<String, dynamic>>.from(reviewsData);

      final placeStats = await supabase
          .from('places')
          .select('avg_rating, total_reviews')
          .eq('id', placeId)
          .single();

      _avgRating = (placeStats['avg_rating'] ?? 0.0).toDouble();
      _totalReviews = placeStats['total_reviews'] ?? 0;

      if (user != null) {
        _userReview = null;
        for (var r in _reviews) {
          if (r['user_id'] == user.id) {
            _userReview = r;
            break;
          }
        }
        if (_userReview != null) {
          _userRating = _userReview!['rating'];
          _commentController.text = _userReview!['comment'] ?? '';
        }
      } else {
        _userReview = null;
      }
    } catch (e) {
      debugPrint('Error loading reviews: $e');
    } finally {
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _submitReview() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please log in to review.', isError: true);
      return;
    }

    final comment = _commentController.text.trim();
    if (_userRating == 0) {
      _showMessage('Please select a rating.', isError: true);
      return;
    }

    setState(() => _submittingReview = true);
    final placeId = widget.place['id'];

    try {
      if (_userReview != null && !_editingReview) {
        _showMessage('You already reviewed this place. Use edit option.', isError: true);
        return;
      }

      if (_editingReview) {
        await supabase
            .from('place_reviews')
            .update({
          'rating': _userRating,
          'comment': comment.isEmpty ? null : comment,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('id', _userReview!['id']);
        _showMessage('Review updated successfully!');
      } else {
        await supabase.from('place_reviews').insert({
          'place_id': placeId,
          'user_id': user.id,
          'rating': _userRating,
          'comment': comment.isEmpty ? null : comment,
        });
        _showMessage('Review added successfully!');
      }

      setState(() {
        _editingReview = false;
        _userRating = 5;
        _commentController.clear();
      });
      await _loadReviewsAndRating();
      widget.place['avg_rating'] = _avgRating;
      widget.place['total_reviews'] = _totalReviews;
    } catch (e) {
      _showMessage('Failed to submit review: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  Future<void> _deleteReview() async {
    if (_userReview == null) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review', style: TextStyle(fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
        content: const Text('Are you sure you want to permanently delete your review?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _submittingReview = true);
    try {
      await supabase.from('place_reviews').delete().eq('id', _userReview!['id']);
      _showMessage('Review deleted.');
      setState(() {
        _userReview = null;
        _userRating = 5;
        _commentController.clear();
        _editingReview = false;
      });
      await _loadReviewsAndRating();
    } catch (e) {
      _showMessage('Failed to delete review: $e', isError: true);
    } finally {
      if (mounted) setState(() => _submittingReview = false);
    }
  }

  void _startEditReview() {
    if (_userReview == null) return;
    setState(() {
      _editingReview = true;
      _userRating = _userReview!['rating'];
      _commentController.text = _userReview!['comment'] ?? '';
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingReview = false;
      if (_userReview != null) {
        _userRating = _userReview!['rating'];
        _commentController.text = _userReview!['comment'] ?? '';
      } else {
        _userRating = 5;
        _commentController.clear();
      }
    });
  }

  Widget _buildStars(double rating, {double size = 18, bool showNumber = false}) {
    final fullStars = rating.floor();
    final fractional = rating - fullStars;
    final stars = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star_rounded, size: size, color: const Color(0xFFFFB300)));
      } else if (i == fullStars && fractional > 0) {
        stars.add(Icon(Icons.star_half_rounded, size: size, color: const Color(0xFFFFB300)));
      } else {
        stars.add(Icon(Icons.star_border_rounded, size: size, color: Colors.grey.shade300));
      }
    }
    if (showNumber) {
      stars.add(const SizedBox(width: 8));
      stars.add(Text(
        rating.toStringAsFixed(1),
        style: TextStyle(fontSize: size - 2, fontWeight: FontWeight.bold, color: MyApp.primaryColor),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  Widget _buildRatingSelector() {
    return Row(
      children: List.generate(5, (index) {
        int value = index + 1;
        return IconButton(
          icon: Icon(
            _userRating >= value ? Icons.star_rounded : Icons.star_border_rounded,
            color: const Color(0xFFFFB300),
            size: 40,
          ),
          onPressed: () => setState(() => _userRating = value),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
    );
  }

  Widget _buildDistributionLine(String star, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Text(star, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFFFB300)),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percentage,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(MyApp.secondaryColor),
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addMorePhotos() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please log in to add photos.', isError: true);
      return;
    }
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.image,
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => _addingPhotos = true);
    try {
      List<String> newImageUrls = [];
      final placeId = widget.place['id'];
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < result.files.length; i++) {
        final file = result.files[i];
        final bytes = file.bytes;
        if (bytes == null) continue;
        final ext = file.name.split('.').last;
        final fileName = 'place_${placeId}_${timestamp}_$i.$ext';
        final filePath = 'places/$placeId/$fileName';
        await supabase.storage.from('place-photos').uploadBinary(filePath, bytes);
        final publicUrl = supabase.storage.from('place-photos').getPublicUrl(filePath);
        newImageUrls.add(publicUrl);
      }
      if (newImageUrls.isNotEmpty) {
        final currentImages = List<String>.from(widget.place['images'] ?? []);
        final updatedImages = [...currentImages, ...newImageUrls];
        await supabase.from('places').update({'images': updatedImages}).eq('id', placeId);
        setState(() {
          widget.place['images'] = updatedImages;
          _loadImages();
        });
        _showMessage('Successfully added ${newImageUrls.length} image(s)!');
      }
    } catch (e) {
      _showMessage('Failed to upload images: $e', isError: true);
    } finally {
      if (mounted) setState(() => _addingPhotos = false);
    }
  }

  Future<void> _deleteCurrentImage() async {
    if (_images.isEmpty) return;
    final imageUrlToRemove = _images[_currentImageIndex];
    final placeId = widget.place['id'];
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo', style: TextStyle(fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
        content: const Text('Are you sure you want to remove this image from the gallery?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    ) ?? false;
    if (!confirm) return;
    setState(() => _deletingPhoto = true);
    try {
      final currentImages = List<String>.from(widget.place['images'] ?? []);
      currentImages.remove(imageUrlToRemove);
      await supabase.from('places').update({'images': currentImages}).eq('id', placeId);
      setState(() {
        widget.place['images'] = currentImages;
        _loadImages();
        if (_currentImageIndex >= _images.length && _images.isNotEmpty) {
          _currentImageIndex = _images.length - 1;
        }
      });
      _showMessage('Photo removed.');
    } catch (e) {
      _showMessage('Failed to delete photo: $e', isError: true);
    } finally {
      if (mounted) setState(() => _deletingPhoto = false);
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: InteractiveViewer(maxScale: 4.0, child: Center(child: Image.network(imageUrl, fit: BoxFit.contain))),
    )));
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: isError ? const Color(0xFFD32F2F) : MyApp.primaryColor,
    ));
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  void _openInGoogleMaps() async {
    final lat = widget.place['latitude'];
    final lng = widget.place['longitude'];
    if (lat == null || lng == null) {
      _showMessage('Location coordinates not available for this place.', isError: true);
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      _showMessage('Could not launch Google Maps.', isError: true);
    }
  }

  Widget _infoSection(String title, dynamic content) {
    if (content == null || content.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: MyApp.primaryColor, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: Text(
              content.toString(),
              style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: MyApp.secondaryColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: MyApp.primaryColor),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value.toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: MyApp.primaryColor)),
            ],
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = supabase.auth.currentUser != null;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 900;

    double fiveStarPercent = 0.0;
    double fourStarPercent = 0.0;
    double threeStarPercent = 0.0;
    double twoStarPercent = 0.0;
    double oneStarPercent = 0.0;

    if (_reviews.isNotEmpty) {
      int count5 = _reviews.where((r) => r['rating'] == 5).length;
      int count4 = _reviews.where((r) => r['rating'] == 4).length;
      int count3 = _reviews.where((r) => r['rating'] == 3).length;
      int count2 = _reviews.where((r) => r['rating'] == 2).length;
      int count1 = _reviews.where((r) => r['rating'] == 1).length;

      fiveStarPercent = count5 / _reviews.length;
      fourStarPercent = count4 / _reviews.length;
      threeStarPercent = count3 / _reviews.length;
      twoStarPercent = count2 / _reviews.length;
      oneStarPercent = count1 / _reviews.length;
    }

    return Scaffold(
      backgroundColor: MyApp.scaffoldBackground,
      appBar: AppBar(
        title: Text(widget.place['name'] ?? 'Details', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 20)),
        backgroundColor: MyApp.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isLoggedIn)
            _addingPhotos
                ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                : IconButton(icon: const Icon(Icons.add_a_photo_rounded), onPressed: _addMorePhotos),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 1000 : double.infinity),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_images.isNotEmpty)
                  Stack(
                    children: [
                      SizedBox(
                        height: 380,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: _images.length,
                          onPageChanged: (index) => setState(() => _currentImageIndex = index),
                          itemBuilder: (context, index) => GestureDetector(
                            onTap: () => _showFullScreenImage(_images[index]),
                            child: Hero(
                              tag: _images[index],
                              child: Image.network(
                                _images[index],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.broken_image, size: 50, color: Colors.grey)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black.withOpacity(0.1), Colors.transparent, Colors.black.withOpacity(0.4)],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.65), borderRadius: BorderRadius.circular(20)),
                          child: Text('${_currentImageIndex + 1} / ${_images.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ),
                      ),
                      if (isLoggedIn)
                        Positioned(
                          top: 20,
                          right: 20,
                          child: Container(
                            decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), shape: BoxShape.circle),
                            child: IconButton(
                              icon: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                              onPressed: _deletingPhoto ? null : _deleteCurrentImage,
                            ),
                          ),
                        ),
                    ],
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.place['name'] ?? '', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: MyApp.primaryColor, height: 1.2)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        _buildStars(_avgRating, showNumber: true, size: 20),
                                        const SizedBox(width: 8),
                                        Text('($_totalReviews reviews)', style: TextStyle(color: Colors.grey.shade500, fontSize: 14, fontWeight: FontWeight.w500)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (widget.place['latitude'] != null) ...[
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  onPressed: _openInGoogleMaps,
                                  icon: const Icon(Icons.directions_rounded, size: 18),
                                  label: const Text('Directions', style: TextStyle(fontWeight: FontWeight.bold)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: MyApp.secondaryColor,
                                    foregroundColor: MyApp.primaryColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      _infoTile(Icons.category_rounded, 'Category', widget.place['category']),
                      _infoTile(Icons.location_on_rounded, 'Division', widget.place['division']),
                      _infoTile(Icons.access_time_filled_rounded, 'Opening Hours', widget.place['opening_hours']),
                      _infoTile(Icons.payments_rounded, 'Entry Fee', widget.place['entry_fee']),
                      _infoTile(Icons.wb_sunny_rounded, 'Best Time to Visit', widget.place['best_time_to_visit']),

                      const SizedBox(height: 8),
                      const Divider(height: 40, thickness: 1.2),

                      _infoSection('Description', widget.place['description']),
                      _infoSection('History', widget.place['history']),

                      const Divider(height: 40, thickness: 1.2),

                      const Text('Guest Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MyApp.primaryColor, letterSpacing: 0.5)),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 10, offset: const Offset(0, 4))]
                        ),
                        child: Row(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _avgRating.toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: MyApp.primaryColor),
                                ),
                                _buildStars(_avgRating, size: 14),
                                const SizedBox(height: 6),
                                Text(
                                  '$_totalReviews reviews',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: Column(
                                children: [
                                  _buildDistributionLine('5', fiveStarPercent),
                                  _buildDistributionLine('4', fourStarPercent),
                                  _buildDistributionLine('3', threeStarPercent),
                                  _buildDistributionLine('2', twoStarPercent),
                                  _buildDistributionLine('1', oneStarPercent),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (isLoggedIn) ...[
                        if (_userReview != null && !_editingReview) ...[
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: MyApp.secondaryColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: MyApp.secondaryColor.withOpacity(0.3)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: MyApp.primaryColor, borderRadius: BorderRadius.circular(6)),
                                        child: const Text('Your Post', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.white, letterSpacing: 0.5)),
                                      ),
                                      const Spacer(),
                                      IconButton(icon: const Icon(Icons.edit_rounded, size: 20, color: MyApp.primaryColor), onPressed: _startEditReview),
                                      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Colors.redAccent), onPressed: _deleteReview),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  _buildStars(_userReview!['rating'].toDouble(), size: 18),
                                  if (_userReview!['comment'] != null && _userReview!['comment'].toString().isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    Text(_userReview!['comment'], style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.5, fontStyle: FontStyle.italic)),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.rate_review_outlined, color: MyApp.secondaryColor, size: 20),
                                    const SizedBox(width: 8),
                                    Text(_editingReview ? 'Modify your review' : 'Write a Review', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: MyApp.primaryColor)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildRatingSelector(),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: _commentController,
                                  maxLines: 3,
                                  style: const TextStyle(fontSize: 14, color: MyApp.primaryColor),
                                  decoration: InputDecoration(
                                    hintText: 'Tell others about opening hours, crowd, or neat tips...',
                                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                                    filled: true,
                                    fillColor: MyApp.scaffoldBackground.withOpacity(0.4),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (_editingReview) ...[
                                      TextButton(onPressed: _cancelEdit, child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600))),
                                      const SizedBox(width: 8),
                                    ],
                                    ElevatedButton(
                                      onPressed: _submittingReview ? null : _submitReview,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: MyApp.primaryColor,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      child: _submittingReview
                                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                          : Text(_editingReview ? 'Update Post' : 'Post Review', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],

                      if (_reviewsLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
                      else if (_reviews.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 40.0),
                            child: Column(
                              children: [
                                Icon(Icons.forum_outlined, size: 48, color: Colors.grey.shade300),
                                const SizedBox(height: 12),
                                Text('Be the first to share your experience!', style: TextStyle(color: Colors.grey.shade400, fontSize: 14, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _reviews.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final review = _reviews[index];
                            final String fullUserName = review['profiles']?['full_name'] ?? 'Anonymous User';
                            final String? avatarUrl = review['profiles']?['avatar_url'];
                            final String firstLetter = fullUserName.isNotEmpty ? fullUserName.substring(0, 1).toUpperCase() : 'A';

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 6, offset: const Offset(0, 2))]
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Profile Picture Container with explicit image fallback handling
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: MyApp.primaryColor.withOpacity(0.08),
                                    backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: (avatarUrl == null || avatarUrl.isEmpty)
                                        ? Text(
                                      firstLetter,
                                      style: const TextStyle(color: MyApp.primaryColor, fontWeight: FontWeight.bold, fontSize: 14),
                                    )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                fullUserName,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: MyApp.primaryColor),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              _formatDate(review['created_at']),
                                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        _buildStars(review['rating'].toDouble(), size: 14),
                                        if (review['comment'] != null && review['comment'].toString().trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            review['comment']!,
                                            style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.45),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}