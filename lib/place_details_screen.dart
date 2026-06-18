import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      final reviewsData = await supabase
          .from('place_reviews')
          .select('*, profiles(full_name)')
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

      // Find user's own review – fixed version without orElse: null
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
      print('Error loading reviews: $e');
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
        _showMessage('Review updated!');
      } else {
        await supabase.from('place_reviews').insert({
          'place_id': placeId,
          'user_id': user.id,
          'rating': _userRating,
          'comment': comment.isEmpty ? null : comment,
        });
        _showMessage('Review added!');
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
        title: const Text('Delete Review'),
        content: const Text('Are you sure you want to delete your review?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
        stars.add(Icon(Icons.star, size: size, color: Colors.amber));
      } else if (i == fullStars && fractional > 0) {
        stars.add(Icon(Icons.star_half, size: size, color: Colors.amber));
      } else {
        stars.add(Icon(Icons.star_border, size: size, color: Colors.amber));
      }
    }
    if (showNumber) {
      stars.add(const SizedBox(width: 6));
      stars.add(Text(rating.toStringAsFixed(1), style: TextStyle(fontSize: size, fontWeight: FontWeight.bold)));
    }
    return Row(children: stars);
  }

  Widget _buildRatingSelector() {
    return Row(
      children: List.generate(5, (index) {
        int value = index + 1;
        return IconButton(
          icon: Icon(
            _userRating >= value ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 32,
          ),
          onPressed: () => setState(() => _userRating = value),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
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
        _showMessage('Added ${newImageUrls.length} photo(s)!');
      }
    } catch (e) {
      _showMessage('Failed to upload: $e', isError: true);
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
        title: const Text('Delete Photo'),
        content: const Text('Remove this photo from the gallery?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
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
      backgroundColor: isError ? Colors.redAccent : MyApp.primaryColor,
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

  Widget _infoSection(String title, dynamic content) {
    if (content == null || content.toString().isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: MyApp.primaryColor)),
      const SizedBox(height: 8),
      Text(content.toString(), style: TextStyle(fontSize: 15, height: 1.6, color: Colors.grey.shade800)),
    ]);
  }

  Widget _infoTile(IconData icon, String label, dynamic value) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [Icon(icon, size: 20, color: MyApp.primaryColor), const SizedBox(width: 12), Expanded(child: Text(value.toString(), style: const TextStyle(fontSize: 15)))]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = supabase.auth.currentUser != null;
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 900;

    return Scaffold(
      backgroundColor: MyApp.scaffoldBackground,
      appBar: AppBar(
        title: Text(widget.place['name'] ?? 'Place Details', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: MyApp.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isLoggedIn)
            _addingPhotos
                ? const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                : IconButton(icon: const Icon(Icons.add_a_photo_outlined), onPressed: _addMorePhotos),
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
                  Card(
                    margin: isLargeScreen ? const EdgeInsets.only(top: 24) : EdgeInsets.zero,
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(isLargeScreen ? 16 : 0)),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: isLargeScreen ? 450 : 350,
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _images.length,
                            onPageChanged: (index) => setState(() => _currentImageIndex = index),
                            itemBuilder: (context, index) => GestureDetector(
                              onTap: () => _showFullScreenImage(_images[index]),
                              child: Stack(fit: StackFit.expand, children: [
                                Image.network(_images[index], fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.grey.shade200, child: const Icon(Icons.broken_image, size: 50))),
                                const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.transparent, Colors.black45], begin: Alignment.topCenter, end: Alignment.bottomCenter, stops: [0.7, 1.0])))),
                              ]),
                            ),
                          ),
                          if (isLoggedIn)
                            Positioned(
                              top: 16, right: 16,
                              child: CircleAvatar(
                                backgroundColor: const Color(0xB3000000),
                                child: _deletingPhoto
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent), onPressed: _deleteCurrentImage),
                              ),
                            ),
                          if (_images.length > 1)
                            Positioned(
                              bottom: 16, right: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(30)),
                                child: Text('${_currentImageIndex + 1} / ${_images.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.all(isLargeScreen ? 0 : 16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.place['name'] ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
                              const SizedBox(height: 8),
                              Row(children: [const Icon(Icons.location_on, size: 18, color: MyApp.secondaryColor), const SizedBox(width: 6), Text(widget.place['division'] ?? '', style: TextStyle(color: Colors.grey.shade700, fontSize: 15))]),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _buildStars(_avgRating, size: 20, showNumber: true),
                                  const SizedBox(width: 12),
                                  Text('($_totalReviews review${_totalReviews != 1 ? 's' : ''})', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _infoSection('Description', widget.place['description']),
                              const Divider(height: 32),
                              _infoTile(Icons.calendar_today_rounded, 'Best Time to Visit', widget.place['best_time_to_visit']),
                              _infoTile(Icons.confirmation_num_outlined, 'Entry Fee', widget.place['entry_fee']),
                              _infoTile(Icons.access_time_rounded, 'Opening Hours', widget.place['opening_hours']),
                              if (widget.place['history'] != null) ...[_infoSection('History', widget.place['history'])],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ==================== REVIEW SECTION ====================
                      Card(
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('User Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: MyApp.primaryColor)),
                              const SizedBox(height: 12),

                              if (isLoggedIn) ...[
                                if (_userReview != null && !_editingReview) ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.rate_review, color: MyApp.secondaryColor),
                                      const SizedBox(width: 8),
                                      const Text('Your review:', style: TextStyle(fontWeight: FontWeight.w500)),
                                      const SizedBox(width: 12),
                                      _buildStars(_userReview!['rating'].toDouble(), size: 16),
                                      const Spacer(),
                                      TextButton(onPressed: _startEditReview, child: const Text('Edit')),
                                      TextButton(onPressed: _deleteReview, child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                  if (_userReview!['comment'] != null && _userReview!['comment'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4, left: 32),
                                      child: Text(_userReview!['comment'], style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                    ),
                                  const SizedBox(height: 16),
                                ] else ...[
                                  const Text('Share your experience:', style: TextStyle(fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  _buildRatingSelector(),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _commentController,
                                    maxLines: 3,
                                    decoration: InputDecoration(
                                      hintText: 'Write your comment (optional)',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      if (_editingReview) ...[
                                        ElevatedButton(onPressed: _cancelEdit, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey), child: const Text('Cancel')),
                                        const SizedBox(width: 12),
                                      ],
                                      ElevatedButton(
                                        onPressed: _submittingReview ? null : _submitReview,
                                        child: _submittingReview
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                            : Text(_editingReview ? 'Update Review' : 'Submit Review'),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                ],
                              ] else ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock_open, size: 16, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text('Log in to write a review.', style: TextStyle(color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                const Divider(height: 24),
                              ],

                              if (_reviewsLoading)
                                const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                              else if (_reviews.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Center(child: Text('No reviews yet. Be the first to review!', style: TextStyle(color: Colors.grey))),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _reviews.length,
                                  separatorBuilder: (_, __) => const Divider(height: 20),
                                  itemBuilder: (context, index) {
                                    final review = _reviews[index];
                                    final isOwnReview = isLoggedIn && review['user_id'] == supabase.auth.currentUser!.id;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Text(review['profiles']?['full_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold)),
                                                  const SizedBox(width: 8),
                                                  _buildStars(review['rating'].toDouble(), size: 14),
                                                ],
                                              ),
                                            ),
                                            if (isOwnReview)
                                              const Icon(Icons.edit_note, size: 16, color: MyApp.secondaryColor),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (review['comment'] != null && review['comment'].toString().isNotEmpty)
                                          Text(review['comment'], style: const TextStyle(fontSize: 14)),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(review['created_at']),
                                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
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