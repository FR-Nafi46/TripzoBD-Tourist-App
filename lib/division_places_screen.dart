import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'place_details_screen.dart';
import 'add_place_suggestion_screen.dart';

class DivisionPlacesScreen extends StatefulWidget {
  final String divisionName;
  const DivisionPlacesScreen({super.key, required this.divisionName});

  @override
  State<DivisionPlacesScreen> createState() => _DivisionPlacesScreenState();
}

class _DivisionPlacesScreenState extends State<DivisionPlacesScreen> {
  late Future<List<Map<String, dynamic>>> _placesFuture;

  static const Color darkTeal = Color(0xFF0B2B26);
  static const Color softSage = Color(0xFF8EB69B);
  static const Color bgLilac = Color(0xFFF2F0FA);

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  void _loadPlaces() {
    _placesFuture = supabase
        .from('places')
        .select()
        .eq('division', widget.divisionName)
        .order('name');
    setState(() {});
  }

  // Helper: build star row for average rating
  Widget _buildRatingStars(double rating) {
    final fullStars = rating.floor();
    final fractional = rating - fullStars;
    final stars = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star, size: 12, color: Colors.amber));
      } else if (i == fullStars && fractional > 0) {
        stars.add(Icon(Icons.star_half, size: 12, color: Colors.amber));
      } else {
        stars.add(Icon(Icons.star_border, size: 12, color: Colors.amber));
      }
    }
    return Row(children: stars);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgLilac,
      appBar: AppBar(
        title: Text(
          '${widget.divisionName} Places',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: darkTeal,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final user = supabase.auth.currentUser;
          if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please log in to suggest a place.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            return;
          }
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddPlaceSuggestionScreen(division: widget.divisionName),
            ),
          );
          if (result == true) {
            _loadPlaces();
          }
        },
        icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
        label: const Text(
          'Suggest Place',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5, color: Colors.white),
        ),
        backgroundColor: darkTeal,
        elevation: 4,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(darkTeal),
                strokeWidth: 3,
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Something went wrong. Please try again.',
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
                ),
              ),
            );
          }

          final places = snapshot.data ?? [];
          if (places.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.explore_outlined, size: 64, color: darkTeal.withOpacity(0.4)),
                  const SizedBox(height: 16),
                  Text(
                    'No places discovered here yet.',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: darkTeal.withOpacity(0.8)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap below to suggest your favorite spot!',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _loadPlaces(),
            color: darkTeal,
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.78,
              ),
              itemCount: places.length,
              itemBuilder: (context, index) {
                return _buildPlaceCard(places[index]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlaceCard(Map<String, dynamic> place) {
    String? displayImage;
    if (place['cover_image'] != null && place['cover_image'].toString().isNotEmpty) {
      displayImage = place['cover_image'];
    } else if (place['images'] != null && place['images'] is List && (place['images'] as List).isNotEmpty) {
      displayImage = (place['images'] as List).first.toString();
    } else if (place['image_url'] != null && place['image_url'].toString().isNotEmpty) {
      displayImage = place['image_url'];
    }

    // Get rating data
    final double avgRating = (place['avg_rating'] ?? 0.0).toDouble();
    final int totalReviews = place['total_reviews'] ?? 0;

    return GestureDetector(
      onTap: () async {
        try {
          final updatedPlace = await supabase
              .from('places')
              .select()
              .eq('id', place['id'])
              .single();

          if (mounted) {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: updatedPlace)),
            );
            _loadPlaces();
          }
        } catch (e) {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaceDetailsScreen(place: place)),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withOpacity(0.04),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: displayImage != null
                        ? Image.network(
                      displayImage,
                      fit: BoxFit.cover,
                      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded) return child;
                        return AnimatedOpacity(
                          opacity: frame == null ? 0 : 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: child,
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: softSage.withOpacity(0.2),
                        child: const Icon(Icons.broken_image_rounded, color: softSage, size: 28),
                      ),
                    )
                        : Container(
                      color: softSage.withOpacity(0.15),
                      child: const Center(
                        child: Icon(Icons.landscape_rounded, size: 36, color: softSage),
                      ),
                    ),
                  ),
                  // Floating Category Pill
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        place['category'] ?? 'General',
                        style: const TextStyle(
                          color: darkTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Text Meta Details
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place['name'] ?? 'Unknown Place',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: darkTeal,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 12, color: softSage),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          widget.divisionName,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  // Display average rating if any reviews exist
                  if (totalReviews > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildRatingStars(avgRating),
                        const SizedBox(width: 4),
                        Text(
                          '($avgRating)',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalReviews review${totalReviews != 1 ? 's' : ''}',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}