import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';

class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({super.key});

  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _upcomingBookings = [];
  bool _loading = true;
  double _totalEarnings = 0;
  int _totalBookings = 0;
  int _unreadCount = 0;
  RealtimeChannel? _unreadChannel;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
    _subscribeUnread();
  }

  @override
  void dispose() {
    if (_unreadChannel != null) {
      supabase.removeChannel(_unreadChannel!);
    }
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final response = await supabase
          .from('messages')
          .select('id')
          .eq('receiver_id', user.id)
          .isFilter('read_at', null);
      if (mounted) {
        setState(() => _unreadCount = response.length);
      }
    } catch (e) {
      debugPrint('Error loading unread count: $e');
    }
  }

  void _subscribeUnread() {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    _unreadChannel = supabase
        .channel('unread-guide-${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        if (!mounted) return;
        final newRecord = payload.newRecord;
        final oldRecord = payload.oldRecord;

        if (payload.eventType == PostgresChangeEvent.insert) {
          if (newRecord != null &&
              newRecord['receiver_id'] == user.id &&
              newRecord['read_at'] == null) {
            setState(() => _unreadCount++);
          }
        } else if (payload.eventType == PostgresChangeEvent.update) {
          if (newRecord != null && newRecord['receiver_id'] == user.id) {
            final oldReadAt = oldRecord?['read_at'];
            final newReadAt = newRecord['read_at'];
            if (oldReadAt == null && newReadAt != null) {
              setState(() {
                if (_unreadCount > 0) _unreadCount--;
              });
            } else if (oldReadAt != null && newReadAt == null) {
              setState(() => _unreadCount++);
            }
          }
        }
      },
    );
    _unreadChannel!.subscribe();
  }

  // 🔹 MAIN DATA LOAD – now with bulletproof error handling
  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      debugPrint('❌ No authenticated user in _loadData');
      setState(() {
        _loading = false;
        _errorMessage = 'You must be logged in.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('🔄 Loading bookings for guide: ${user.id}');

      // 1. Fetch all tour guide bookings
      final bookingsData = await supabase
          .from('bookings')
          .select()
          .eq('reference_id', user.id.toString())
          .eq('booking_type', 'tour_guide')
          .order('created_at', ascending: false);

      debugPrint('✅ Fetched ${bookingsData.length} bookings');

      final allBookings = List<Map<String, dynamic>>.from(bookingsData);

      // 2. Collect tourist user IDs
      final userIds = allBookings.map((b) => b['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> touristProfiles = {};
      if (userIds.isNotEmpty) {
        final profilesData = await supabase
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', userIds);
        for (var p in profilesData) {
          touristProfiles[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      // 3. Attach tourist info
      final enhancedBookings = allBookings.map((b) {
        final touristId = b['user_id'];
        final profile = touristProfiles[touristId];
        b['tourist_full_name'] = profile?['full_name'] ?? 'Unknown Tourist';
        b['tourist_avatar_url'] = profile?['avatar_url'];
        return b;
      }).toList();

      // 4. Separate pending and upcoming
      _pendingBookings = enhancedBookings
          .where((b) => b['status'] == 'pending')
          .toList();

      final now = DateTime.now();
      _upcomingBookings = enhancedBookings
          .where((b) =>
      b['status'] == 'confirmed' &&
          b['travel_date'] != null &&
          DateTime.tryParse(b['travel_date'])?.isAfter(now.subtract(const Duration(days: 1))) == true)
          .toList();

      // 5. Calculate earnings
      _totalBookings = enhancedBookings.length;
      _totalEarnings = enhancedBookings
          .where((b) => b['status'] == 'confirmed')
          .fold(0.0, (sum, b) => sum + (b['total_price'] as num).toDouble());

      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = null;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error in _loadData: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to load data: $e';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 🔹 UPDATE BOOKING STATUS
  Future<void> _updateBookingStatus(String bookingId, String newStatus) async {
    if (_loading) return; // prevent double tap

    setState(() => _loading = true);
    try {
      await supabase
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);

      debugPrint('✅ Booking $bookingId updated to $newStatus');

      // Reload data
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking $newStatus'),
            backgroundColor: newStatus == 'confirmed' ? Colors.green : Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Update error: $e');
      debugPrint(stackTrace.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update booking: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => _loading = false);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _contactTourist(String touristId, String touristName, String? avatarUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          partnerId: touristId,
          partnerName: touristName,
          partnerAvatar: avatarUrl,
        ),
      ),
    ).then((_) => _loadUnreadCount());
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
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
        appBar: AppBar(title: const Text('Guide Dashboard')),
        body: const Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Guide Dashboard'),
        backgroundColor: MyApp.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.chat),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
                  ).then((_) => _loadUnreadCount());
                },
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      _unreadCount > 99 ? '99+' : _unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show error if any
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              // Stats row
              Row(
                children: [
                  _statCard('Total Bookings', _totalBookings, Icons.bookmark, Colors.blue),
                  const SizedBox(width: 12),
                  _statCard('Earnings', '৳${_totalEarnings.toStringAsFixed(0)}', Icons.monetization_on, Colors.green),
                ],
              ),
              const SizedBox(height: 24),

              // Upcoming Schedule
              const Text(
                'Your Upcoming Schedule',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_upcomingBookings.isEmpty)
                const Center(child: Text('No confirmed bookings yet.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _upcomingBookings.length,
                  itemBuilder: (context, index) {
                    final b = _upcomingBookings[index];
                    final touristName = b['tourist_full_name'] ?? 'Unknown Tourist';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.event_available, color: Colors.green),
                        title: Text(touristName),
                        subtitle: Text('Date: ${_formatDate(b['travel_date'])}'),
                        trailing: Text('৳${b['total_price']}'),
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // Pending bookings
              const Text(
                'Pending Bookings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              if (_pendingBookings.isEmpty)
                const Center(child: Text('No pending bookings.'))
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _pendingBookings.length,
                  itemBuilder: (context, index) {
                    final b = _pendingBookings[index];
                    final touristName = b['tourist_full_name'] ?? 'Unknown Tourist';
                    final touristId = b['user_id'];
                    final avatarUrl = b['tourist_avatar_url'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Booking #${b['id']}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'PENDING',
                                    style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Tourist: $touristName'),
                            Text('Travel date: ${_formatDate(b['travel_date'])}'),
                            Text('Total: ৳${b['total_price']}'),
                            Text('Booked on: ${_formatDate(b['created_at'])}'),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () => _contactTourist(touristId, touristName, avatarUrl),
                                  icon: const Icon(Icons.chat, size: 16),
                                  label: const Text('Contact'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: MyApp.primaryColor,
                                  ),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: _loading
                                          ? null
                                          : () => _updateBookingStatus(b['id'], 'cancelled'),
                                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                                      child: const Text('Reject'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: _loading
                                          ? null
                                          : () => _updateBookingStatus(b['id'], 'confirmed'),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                      child: const Text('Accept'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, dynamic value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value.toString(),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                ),
                Text(label, style: TextStyle(color: Colors.grey[700])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}