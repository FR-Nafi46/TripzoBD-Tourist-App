import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class BookingHistoryScreen extends StatefulWidget {
  const BookingHistoryScreen({super.key});

  @override
  State<BookingHistoryScreen> createState() => _BookingHistoryScreenState();
}

class _BookingHistoryScreenState extends State<BookingHistoryScreen> {
  late Future<List<Map<String, dynamic>>> _bookingsFuture;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  void _loadBookings() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      _bookingsFuture = Future.value([]);
      return;
    }
    _bookingsFuture = supabase
        .from('bookings')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    setState(() {});
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: const Text('Are you sure you want to cancel this booking?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await supabase
          .from('bookings')
          .update({'status': 'cancelled'})
          .eq('id', booking['id']);
      _loadBookings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Booking cancelled')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      return dateStr.substring(0, 10);
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Booking History')),
        body: const Center(child: Text('Please log in to view bookings.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Booking History')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _bookingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final bookings = snapshot.data ?? [];
          if (bookings.isEmpty) {
            return const Center(child: Text('No bookings found.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: bookings.length,
            itemBuilder: (context, i) {
              final b = bookings[i];
              final isPending = b['status'] == 'pending';
              final isCancelled = b['status'] == 'cancelled';
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${b['booking_type']?.toUpperCase() ?? 'BOOKING'}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: MyApp.primaryColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCancelled
                                  ? Colors.red.withOpacity(0.1)
                                  : isPending
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              b['status'] ?? 'confirmed',
                              style: TextStyle(
                                color: isCancelled
                                    ? Colors.red
                                    : isPending
                                    ? Colors.orange
                                    : Colors.green,
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (b['booking_type'] == 'hotel') ...[
                        Text('Reference ID: ${b['reference_id']}'),
                        if (b['check_in'] != null)
                          Text('Check-in: ${_formatDate(b['check_in'])}'),
                        if (b['check_out'] != null)
                          Text('Check-out: ${_formatDate(b['check_out'])}'),
                      ],
                      if (b['booking_type'] == 'transport') ...[
                        Text('Trip ID: ${b['reference_id']}'),
                        if (b['travel_date'] != null)
                          Text('Travel date: ${_formatDate(b['travel_date'])}'),
                      ],
                      if (b['booking_type'] == 'tour_guide') ...[
                        Text('Guide ID: ${b['reference_id']}'),
                        if (b['travel_date'] != null)
                          Text('Tour date: ${_formatDate(b['travel_date'])}'),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Total: ৳${b['total_price']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Booked on: ${_formatDate(b['created_at'])}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      if (isPending)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => _cancelBooking(b),
                              icon: const Icon(Icons.cancel, size: 18),
                              label: const Text('Cancel Booking'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                            ),
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
    );
  }
}