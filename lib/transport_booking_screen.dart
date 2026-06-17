import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class TransportBookingScreen extends StatefulWidget {
  const TransportBookingScreen({super.key});

  @override
  State<TransportBookingScreen> createState() => _TransportBookingScreenState();
}

class _TransportBookingScreenState extends State<TransportBookingScreen> {
  late Future<List<Map<String, dynamic>>> _transportsFuture;
  String _selectedType = 'All';
  final List<String> _types = ['All', 'Bus', 'Train', 'Launch', 'Air'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    var query = supabase.from('transports').select();
    if (_selectedType != 'All') query = query.eq('type', _selectedType);
    _transportsFuture = query.order('price');
    setState(() {});
  }

  Future<void> _book(Map<String, dynamic> transport) async {
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
        'user_id':      user.id,
        'booking_type': 'transport',
        'reference_id': transport['id'],
        'travel_date':  picked.toIso8601String().substring(0, 10),
        'guests':       1,
        'total_price':  transport['price'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                '${transport['type']} booked: ${transport['from_location']} → ${transport['to_location']}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'Train':  return Icons.train;
      case 'Air':    return Icons.flight;
      case 'Launch': return Icons.directions_boat;
      default:       return Icons.directions_bus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Booking')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                  labelText: 'Filter by Type',
                  border: OutlineInputBorder()),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) {
                _selectedType = v ?? 'All';
                _load();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _transportsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) {
                  return const Center(child: Text('No transports found.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final t = list[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: MyApp.primaryColor,
                          child: Icon(_icon(t['type']),
                              color: Colors.white, size: 20),
                        ),
                        title: Text(
                          '${t['from_location']} → ${t['to_location']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                            '${t['operator']}  •  ${t['type']}  •  ${t['departure_time'] ?? ''}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('৳${t['price']}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: MyApp.primaryColor)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () => _book(t),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: MyApp.primaryColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text('Book',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 12)),
                              ),
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