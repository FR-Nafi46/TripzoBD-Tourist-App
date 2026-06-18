import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'tour_guide_detail_screen.dart';

class TourGuideBookingScreen extends StatefulWidget {
  const TourGuideBookingScreen({super.key});

  @override
  State<TourGuideBookingScreen> createState() => _TourGuideBookingScreenState();
}

class _TourGuideBookingScreenState extends State<TourGuideBookingScreen> {
  late Future<List<Map<String, dynamic>>> _guidesFuture;
  String _selectedDivision = 'All';
  final List<String> _divisions = [
    'All', 'Dhaka', 'Chattogram', 'Rajshahi',
    'Khulna', 'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh',
  ];

  // Configured precisely around your app's explicit color palette
  final Color _primaryColor = const Color(0xFF0B2B26);     // Dark Teal
  final Color _secondaryColor = const Color(0xFF8EB69B);   // Soft Sage Green
  final Color _bgBackground = const Color(0xFFF2F0FA);     // White Lilac

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final supabase = Supabase.instance.client;
    var query = supabase
        .from('profiles')
        .select('id, full_name, guide_division, languages, price_per_day, bio, avatar_url, phone, email, avg_rating, total_reviews')
        .eq('role', 'tour_guide')
        .eq('is_approved', true)
        .eq('is_available', true);   // <-- Only show available guides

    if (_selectedDivision != 'All') {
      query = query.eq('guide_division', _selectedDivision);
    }
    _guidesFuture = query.order('avg_rating', ascending: false);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: const Text(
          'Find a Tour Guide',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Horizontal Choice Chip Scrollbar Filter ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'EXPLORE REGIONS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 38,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _divisions.length,
                    itemBuilder: (context, index) {
                      final division = _divisions[index];
                      final isSelected = _selectedDivision == division;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(division),
                          selected: isSelected,
                          selectedColor: _primaryColor,
                          backgroundColor: _bgBackground,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : _primaryColor,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected ? _primaryColor : Colors.grey[300]!,
                              width: 1,
                            ),
                          ),
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _selectedDivision = division;
                                _load();
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // --- Main Core Grid/List Feed ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _guidesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: _primaryColor),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Something went wrong. Please try again.',
                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                    ),
                  );
                }
                final guides = snapshot.data ?? [];
                if (guides.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No available guides in $_selectedDivision right now.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: guides.length,
                  itemBuilder: (context, i) {
                    return _buildGuideCard(guides[i]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideCard(Map<String, dynamic> guide) {
    // Dynamic Language Handling with parsing rules safely
    String languagesString = '';
    final rawLanguages = guide['languages'];
    if (rawLanguages is List) {
      languagesString = rawLanguages.join(', ');
    } else if (rawLanguages is String) {
      final trimmed = rawLanguages.trim();
      if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
        languagesString = trimmed
            .substring(1, trimmed.length - 1)
            .split(',')
            .map((s) => s.trim().replaceAll('"', ''))
            .join(', ');
      } else {
        languagesString = trimmed;
      }
    }

    final avgRating = (guide['avg_rating'] ?? 0.0).toDouble();
    final totalReviews = guide['total_reviews'] ?? 0;
    final String fullName = guide['full_name'] ?? 'Local Guide';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TourGuideDetailScreen(guide: guide),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Avatar Element ---
                CircleAvatar(
                  radius: 32,
                  backgroundColor: _secondaryColor.withOpacity(0.2),
                  backgroundImage: guide['avatar_url'] != null
                      ? NetworkImage(guide['avatar_url'])
                      : null,
                  child: guide['avatar_url'] == null
                      ? Icon(Icons.person_outline, size: 32, color: _primaryColor)
                      : null,
                ),
                const SizedBox(width: 16),

                // --- Explanatory Details Container ---
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 17,
                                color: _primaryColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right, size: 20, color: Colors.grey[400]),
                        ],
                      ),
                      const SizedBox(height: 3),

                      // Region badge row
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 13, color: _secondaryColor),
                          const SizedBox(width: 4),
                          Text(
                            guide['guide_division'] ?? 'Undefined',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Language details
                      if (languagesString.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '🗣  $languagesString',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),

                      // --- Clean Dotted/Dashed Intermittent Separator ---
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: List.generate(
                            24,
                                (index) => Expanded(
                              child: Container(
                                color: index % 2 == 0 ? Colors.transparent : Colors.grey[200],
                                height: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // --- Ratings and Cost Footer Sub-Row ---
                      Row(
                        children: [
                          _buildStars(avgRating, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                            ),
                          ),
                          Text(
                            ' ($totalReviews)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                          const Spacer(),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '৳${guide['price_per_day']}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: _primaryColor,
                                  ),
                                ),
                                TextSpan(
                                  text: '/day',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.normal,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildStars(double rating, {double size = 18}) {
    final fullStars = rating.floor();
    final fractional = rating - fullStars;
    final stars = <Widget>[];

    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star_rounded, size: size, color: Colors.amber[600]));
      } else if (i == fullStars && fractional > 0) {
        stars.add(Icon(Icons.star_half_rounded, size: size, color: Colors.amber[600]));
      } else {
        stars.add(Icon(Icons.star_border_rounded, size: size, color: Colors.grey[300]));
      }
    }
    return Row(children: stars);
  }
}