import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    var query = supabase
        .from('profiles')
        .select('id, full_name, guide_division, languages, price_per_day, rating, bio, avatar_url')
        .eq('role', 'tour_guide')
        .eq('is_approved', true);
    if (_selectedDivision != 'All') {
      query = query.eq('guide_division', _selectedDivision);
    }
    _guidesFuture = query.order('rating', ascending: false);
    setState(() {});
  }

  Future<void> _book(Map<String, dynamic> guide) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to book.')));
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;

    try {
      await supabase.from('bookings').insert({
        'user_id': user.id,
        'booking_type': 'tour_guide',
        'reference_id': guide['id'], // UUID of the guide's profile
        'travel_date': picked.toIso8601String().substring(0, 10),
        'guests': 1,
        'total_price': guide['price_per_day'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${guide['full_name']} booked successfully!'))
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tour Guide Booking')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _selectedDivision,
              decoration: const InputDecoration(
                  labelText: 'Filter by Division',
                  border: OutlineInputBorder()),
              items: _divisions
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                _selectedDivision = v ?? 'All';
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _guidesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final guides = snapshot.data ?? [];
                if (guides.isEmpty) {
                  return const Center(child: Text('No guides found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: guides.length,
                  itemBuilder: (context, i) {
                    final g = guides[i];
                    final languages =
                        (g['languages'] as List?)?.join(', ') ?? '';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor:
                              MyApp.primaryColor.withOpacity(0.15),
                              backgroundImage: g['avatar_url'] != null
                                  ? NetworkImage(g['avatar_url'])
                                  : null,
                              child: g['avatar_url'] == null
                                  ? Icon(Icons.person,
                                  size: 30, color: MyApp.primaryColor)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g['full_name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text(g['guide_division'],
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 13)),
                                  if (languages.isNotEmpty)
                                    Text('🗣 $languages',
                                        style:
                                        const TextStyle(fontSize: 12)),
                                  Row(
                                    children: [
                                      const Icon(Icons.star,
                                          size: 14, color: Colors.amber),
                                      Text(' ${g['rating'] ?? '-'}',
                                          style:
                                          const TextStyle(fontSize: 13)),
                                      const Spacer(),
                                      Text('৳${g['price_per_day']}/day',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: MyApp.primaryColor)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _book(g),
                              style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8)),
                              child: const Text('Book'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}