import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class HotelBookingScreen extends StatefulWidget {
  const HotelBookingScreen({super.key});

  @override
  State<HotelBookingScreen> createState() => _HotelBookingScreenState();
}

class _HotelBookingScreenState extends State<HotelBookingScreen> {
  late Future<List<Map<String, dynamic>>> _hotelsFuture;
  String _selectedDivision = 'All';
  final List<String> _divisions = [
    'All', 'Dhaka', 'Chattogram', 'Rajshahi',
    'Khulna', 'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh',
  ];

  final Color _primaryColor = const Color(0xFF0B2B26);
  final Color _secondaryColor = const Color(0xFF8EB69B);
  final Color _bgBackground = const Color(0xFFF2F0FA);

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  void _loadHotels() {
    var query = supabase.from('hotels').select();
    if (_selectedDivision != 'All') {
      // Case‑insensitive exact match
      query = query.ilike('division', _selectedDivision);
    }
    _hotelsFuture = query.order('stars', ascending: false);
    setState(() {});
  }

  Future<void> _addHotel() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a hotel.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final divisionController = TextEditingController();
    final addressController = TextEditingController();
    final priceController = TextEditingController();
    final starsController = TextEditingController();
    final descriptionController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Add New Hotel', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Hotel Name *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: divisionController,
                  decoration: const InputDecoration(labelText: 'Division *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price per Night (BDT) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: starsController,
                  decoration: const InputDecoration(labelText: 'Stars (1–5)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final val = int.tryParse(v.trim());
                    if (val == null || val < 1 || val > 5) {
                      return 'Enter a number between 1 and 5';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;

              final name = nameController.text.trim();
              final division = divisionController.text.trim();
              final address = addressController.text.trim();
              final price = double.tryParse(priceController.text.trim()) ?? 0.0;
              final stars = int.tryParse(starsController.text.trim());
              final description = descriptionController.text.trim();

              final hotelData = {
                'name': name,
                'division': division,
                'address': address.isEmpty ? null : address,
                'price_per_night': price,
                'stars': stars ?? 0,
                'description': description.isEmpty ? null : description,
              };

              try {
                await supabase.from('hotels').insert(hotelData);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hotel added successfully!')),
                  );
                  _loadHotels();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding hotel: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add Hotel'),
          ),
        ],
      ),
    );
  }

  void _viewHotel(Map<String, dynamic> hotel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelDetailScreen(hotel: hotel),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: const Text(
          'Hotel Information',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addHotel,
        icon: const Icon(Icons.add),
        label: const Text('Add Hotel'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                                _loadHotels();
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
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _hotelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Something went wrong. Please try again.',
                      style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                    ),
                  );
                }
                final hotels = snapshot.data ?? [];
                if (hotels.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.hotel_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No hotels found in $_selectedDivision.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: hotels.length,
                  itemBuilder: (context, i) {
                    final hotel = hotels[i];
                    final stars = hotel['stars'] ?? 0;

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
                          onTap: () => _viewHotel(hotel),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: _secondaryColor.withOpacity(0.2),
                                  child: Icon(Icons.hotel, size: 28, color: _primaryColor),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              hotel['name'] ?? 'Hotel Name',
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
                                      Row(
                                        children: [
                                          Icon(Icons.location_on, size: 13, color: _secondaryColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            hotel['division'] ?? 'Undefined',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (hotel['address'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          hotel['address'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                        ),
                                      ],
                                      const SizedBox(height: 8),
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
                                      Row(
                                        children: [
                                          _buildStars(stars.toDouble(), size: 14),
                                          const Spacer(),
                                          RichText(
                                            text: TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: '৳${hotel['price_per_night']}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: _primaryColor,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: '/night',
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    final fullStars = rating.floor();
    final stars = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star_rounded, size: size, color: Colors.amber[600]));
      } else {
        stars.add(Icon(Icons.star_border_rounded, size: size, color: Colors.grey[300]));
      }
    }
    return Row(children: stars);
  }
}

class HotelDetailScreen extends StatelessWidget {
  final Map<String, dynamic> hotel;
  const HotelDetailScreen({super.key, required this.hotel});

  final Color _primaryColor = const Color(0xFF0B2B26);
  final Color _bgBackground = const Color(0xFFF2F0FA);

  @override
  Widget build(BuildContext context) {
    final stars = (hotel['stars'] ?? 0).toDouble();

    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: Text(hotel['name'] ?? 'Hotel Details', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        hotel['name'] ?? 'Unknown Hotel',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _buildStars(stars, size: 18),
                const Divider(height: 32, thickness: 1.2),
                _infoRow(Icons.location_city, 'Division', hotel['division'] ?? 'N/A'),
                if (hotel['address'] != null && hotel['address'].toString().isNotEmpty)
                  _infoRow(Icons.location_on, 'Address', hotel['address']),
                _infoRow(Icons.payments, 'Price per Night', '৳${hotel['price_per_night']} / night'),
                if (hotel['description'] != null && hotel['description'].toString().isNotEmpty)
                  _infoRow(Icons.description, 'Description', hotel['description']),
                if (hotel['created_at'] != null)
                  _infoRow(Icons.calendar_today, 'Added on', _formatDate(hotel['created_at'])),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: _primaryColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 18}) {
    final fullStars = rating.floor();
    final stars = <Widget>[];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(Icon(Icons.star_rounded, size: size, color: Colors.amber[600]));
      } else {
        stars.add(Icon(Icons.star_border_rounded, size: size, color: Colors.grey[300]));
      }
    }
    return Row(children: stars);
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date.toString()).toLocal();
      return '${parsed.day}/${parsed.month}/${parsed.year}';
    } catch (_) {
      return date.toString();
    }
  }
}