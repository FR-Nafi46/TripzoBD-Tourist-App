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

  @override
  void initState() {
    super.initState();
    _loadHotels();
  }

  void _loadHotels() {
    var query = supabase.from('hotels').select();
    if (_selectedDivision != 'All') {
      query = query.eq('division', _selectedDivision);
    }
    _hotelsFuture = query.order('stars', ascending: false);
    setState(() {});
  }

  Future<void> _book(Map<String, dynamic> hotel) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to book.')));
      return;
    }

    // Simple one-night booking dialog
    DateTime? checkIn;
    DateTime? checkOut;

    await showDialog(
      context: context,
      builder: (ctx) => _BookingDialog(
        hotel: hotel,
        onConfirm: (ci, co) {
          checkIn = ci;
          checkOut = co;
        },
      ),
    );

    if (checkIn == null || checkOut == null) return;
    final nights = checkOut!.difference(checkIn!).inDays;
    if (nights <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check-out must be after check-in.')));
      return;
    }
    final total = (hotel['price_per_night'] as num) * nights;

    try {
      await supabase.from('bookings').insert({
        'user_id':      user.id,
        'booking_type': 'hotel',
        'reference_id': hotel['id'],
        'check_in':     checkIn!.toIso8601String().substring(0, 10),
        'check_out':    checkOut!.toIso8601String().substring(0, 10),
        'guests':       1,
        'total_price':  total,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Booked ${hotel['name']} for $nights night(s). Total: ৳$total')));
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
      appBar: AppBar(title: const Text('Hotel Booking')),
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
                _loadHotels();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _hotelsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final hotels = snapshot.data ?? [];
                if (hotels.isEmpty) {
                  return const Center(child: Text('No hotels found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: hotels.length,
                  itemBuilder: (context, i) {
                    final hotel = hotels[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(hotel['name'],
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ),
                                Row(
                                  children: List.generate(
                                    hotel['stars'] ?? 0,
                                        (_) => const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(hotel['division'],
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 13)),
                            if (hotel['address'] != null)
                              Text(hotel['address'],
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 12)),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '৳${hotel['price_per_night']} / night',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: MyApp.primaryColor),
                                ),
                                ElevatedButton(
                                  onPressed: () => _book(hotel),
                                  child: const Text('Book Now'),
                                ),
                              ],
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

// ── Simple booking dialog ──────────────────────────────────────────────────
class _BookingDialog extends StatefulWidget {
  final Map<String, dynamic> hotel;
  final void Function(DateTime checkIn, DateTime checkOut) onConfirm;
  const _BookingDialog({required this.hotel, required this.onConfirm});

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  DateTime? _checkIn;
  DateTime? _checkOut;

  Future<void> _pick(bool isCheckIn) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => isCheckIn ? _checkIn = picked : _checkOut = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Book ${widget.hotel['name']}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_checkIn == null
                ? 'Select Check-in'
                : 'Check-in: ${_checkIn!.toLocal().toString().substring(0, 10)}'),
            onTap: () => _pick(true),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(_checkOut == null
                ? 'Select Check-out'
                : 'Check-out: ${_checkOut!.toLocal().toString().substring(0, 10)}'),
            onTap: () => _pick(false),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            if (_checkIn != null && _checkOut != null) {
              widget.onConfirm(_checkIn!, _checkOut!);
              Navigator.pop(context);
            }
          },
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}