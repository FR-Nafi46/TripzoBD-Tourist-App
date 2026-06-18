import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:collection/collection.dart';
import 'main.dart';

class TourGuideDetailScreen extends StatefulWidget {
  final Map<String, dynamic> guide;
  const TourGuideDetailScreen({super.key, required this.guide});

  @override
  State<TourGuideDetailScreen> createState() => _TourGuideDetailScreenState();
}

class _TourGuideDetailScreenState extends State<TourGuideDetailScreen> {
  bool _booking = false;

  // Review state
  List<Map<String, dynamic>> _reviews = [];
  bool _reviewsLoading = true;
  Map<String, dynamic>? _userReview;
  int _userRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _submittingReview = false;
  bool _editingReview = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    setState(() => _reviewsLoading = true);
    final guideId = widget.guide['id'];
    final user = supabase.auth.currentUser;

    try {
      final reviewsData = await supabase
          .from('guide_reviews')
          .select('*, profiles!guide_reviews_user_id_fkey(full_name)')
          .eq('guide_id', guideId)
          .order('created_at', ascending: false);

      _reviews = List<Map<String, dynamic>>.from(reviewsData);

      final guideStats = await supabase
          .from('profiles')
          .select('avg_rating, total_reviews')
          .eq('id', guideId)
          .single();

      widget.guide['avg_rating'] = guideStats['avg_rating'] ?? 0.0;
      widget.guide['total_reviews'] = guideStats['total_reviews'] ?? 0;

      if (user != null) {
        _userReview = _reviews.firstWhereOrNull((r) => r['user_id'] == user.id);
        if (_userReview != null) {
          _userRating = _userReview!['rating'];
          _commentController.text = _userReview!['comment'] ?? '';
        } else {
          _userRating = 5;
          _commentController.clear();
        }
      }
    } catch (e) {
      print('Error loading reviews: $e');
      _showMessage('Failed to load reviews: $e', isError: true);
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
    final guideId = widget.guide['id'];

    try {
      if (_userReview != null && !_editingReview) {
        _showMessage('You already reviewed this guide. Use edit option.', isError: true);
        return;
      }

      if (_editingReview) {
        await supabase
            .from('guide_reviews')
            .update({
          'rating': _userRating,
          'comment': comment.isEmpty ? null : comment,
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('id', _userReview!['id']);
        _showMessage('Review updated!');
      } else {
        await supabase.from('guide_reviews').insert({
          'guide_id': guideId,
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
      await _loadReviews();
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
      await supabase.from('guide_reviews').delete().eq('id', _userReview!['id']);
      _showMessage('Review deleted.');
      setState(() {
        _userReview = null;
        _userRating = 5;
        _commentController.clear();
        _editingReview = false;
      });
      await _loadReviews();
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return dateStr;
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: isError ? Colors.redAccent : MyApp.primaryColor,
    ));
  }

  // ==================== UPDATED BOOKING METHOD ====================
  Future<void> _bookGuide() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage('Please log in to book.', isError: true);
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    setState(() => _booking = true);
    try {
      // 1. Check if guide is already booked on that date (confirmed)
      final existingBooking = await supabase
          .from('bookings')
          .select('id')
          .eq('reference_id', widget.guide['id'].toString())
          .eq('travel_date', picked.toIso8601String().substring(0, 10))
          .eq('status', 'confirmed')
          .maybeSingle();

      if (existingBooking != null) {
        setState(() => _booking = false);
        if (mounted) {
          _showGuideBookedDialog(picked);
        }
        return;
      }

      // 2. Create the booking
      await supabase.from('bookings').insert({
        'user_id': user.id,
        'booking_type': 'tour_guide',
        'reference_id': widget.guide['id'].toString(),
        'travel_date': picked.toIso8601String().substring(0, 10),
        'guests': 1,
        'total_price': widget.guide['price_per_day'],
        'status': 'pending',
      });

      // 3. Send a chat message to the guide
      final messageContent =
          'I would like to book you for ${picked.toIso8601String().substring(0, 10)}. Please confirm.';
      try {
        final inserted = await supabase.from('messages').insert({
          'sender_id': user.id,
          'receiver_id': widget.guide['id'],
          'content': messageContent,
        }).select();

        // Log success (optional)
        print('Message inserted: ${inserted.first}');
      } catch (msgError) {
        // If message fails, still notify the user that booking succeeded but message failed.
        print('Message insertion error: $msgError');
        _showMessage(
            'Booking created, but we could not send a message to the guide. Please contact them directly.',
            isError: true);
        setState(() => _booking = false);
        Navigator.pop(context);
        return;
      }

      // 4. Success
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Booking requested! A message has been sent to ${widget.guide['full_name']}.'),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Booking failed: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }
  // ================================================================

  void _showGuideBookedDialog(DateTime date) {
    final dateStr = date.toIso8601String().substring(0, 10);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Guide Already Booked'),
        content: Text(
          '${widget.guide['full_name'] ?? 'This guide'} is already booked for '
              '$dateStr. Please choose a different date or pick another guide.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final languages = (g['languages'] as List?)?.join(', ') ?? 'Not specified';
    final avgRating = (g['avg_rating'] ?? 0.0).toDouble();
    final totalReviews = g['total_reviews'] ?? 0;
    final fullName = g['full_name'] ?? 'Unknown Guide';
    final division = g['guide_division'] ?? 'N/A';
    final price = g['price_per_day'] ?? 0;
    final bio = g['bio'] ?? 'No bio provided.';
    final phone = g['phone'] ?? 'Not provided';
    final email = g['email'] ?? 'Not provided';
    final isLoggedIn = supabase.auth.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(fullName),
        backgroundColor: MyApp.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReviews,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and Name
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: MyApp.primaryColor.withOpacity(0.1),
                      backgroundImage: g['avatar_url'] != null
                          ? NetworkImage(g['avatar_url'])
                          : null,
                      child: g['avatar_url'] == null
                          ? Icon(Icons.person, size: 60, color: MyApp.primaryColor)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: MyApp.primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: MyApp.secondaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildStars(avgRating, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$avgRating ($totalReviews)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: MyApp.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Info cards
              _infoCard(Icons.location_city, 'Division', division),
              _infoCard(Icons.translate, 'Languages', languages),
              _infoCard(Icons.payments, 'Price per Day', '৳ $price'),
              _infoCard(Icons.phone, 'Phone', phone),
              _infoCard(Icons.email, 'Email', email),

              const SizedBox(height: 16),
              if (bio.isNotEmpty) ...[
                const Text(
                  'About Me',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MyApp.primaryColor),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: Colors.grey[50],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      bio,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // ---------- REVIEW SECTION ----------
              Card(
                elevation: 0,
                color: Colors.grey[50],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reviews',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MyApp.primaryColor),
                      ),
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
                              child: Text(_userReview!['comment'], style: const TextStyle(fontSize: 14)),
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
                              fillColor: Colors.white,
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
                          decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
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
                          child: Center(child: Text('No reviews yet. Be the first!', style: TextStyle(color: Colors.grey))),
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
                                          Text(
                                            review['profiles']?['full_name'] ?? 'Anonymous',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          _buildStars(review['rating'].toDouble(), size: 14),
                                        ],
                                      ),
                                    ),
                                    if (isOwnReview) const Icon(Icons.edit_note, size: 16, color: MyApp.secondaryColor),
                                  ],
                                ),
                                if (review['comment'] != null && review['comment'].toString().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(review['comment'], style: const TextStyle(fontSize: 14)),
                                  ),
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

              const SizedBox(height: 32),

              // Book button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _booking ? null : _bookGuide,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: MyApp.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _booking
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text(
                    'Book Now',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        color: Colors.grey[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: MyApp.primaryColor, size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}