import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'profile_screen.dart';
import 'auth_screen.dart';
import 'chat_list_screen.dart';
import 'chat_screen.dart';
import 'booking_history_screen.dart';
import 'map_screen.dart'; // <-- added import

class GuideHomeScreen extends StatefulWidget {
  const GuideHomeScreen({super.key});

  @override
  State<GuideHomeScreen> createState() => _GuideHomeScreenState();
}

class _GuideHomeScreenState extends State<GuideHomeScreen> {
  List<Map<String, dynamic>> _pendingBookings = [];
  List<Map<String, dynamic>> _upcomingBookings = [];
  List<Map<String, dynamic>> _recentReviews = [];
  bool _loading = true;
  double _totalEarnings = 0;
  double _earningsThisMonth = 0;
  double _earningsToday = 0;
  int _totalBookings = 0;
  int _unreadCount = 0;
  bool _isAvailable = true;
  RealtimeChannel? _unreadChannel;
  String? _errorMessage;

  // Design Colors Matching Your Theme
  static const Color brandPrimary = Color(0xFF0B2B26);     // Dark Teal
  static const Color brandSecondary = Color(0xFF8EB69B);   // Soft Sage Green
  static const Color brandBackground = Color(0xFFF2F0FA);  // White Lilac

  DateTime _focusedMonth = DateTime.now();
  Map<DateTime, List<dynamic>> _bookingsByDate = {};

  final List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  // Week starts on Sunday
  final List<String> _weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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

  // ---------- UNREAD COUNT ----------
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

  // ---------- LOAD DATA ----------
  Future<void> _loadData() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
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
      final profileData = await supabase
          .from('profiles')
          .select('is_available')
          .eq('id', user.id)
          .single();
      _isAvailable = profileData['is_available'] ?? true;

      final bookingsData = await supabase
          .from('bookings')
          .select()
          .eq('reference_id', user.id.toString())
          .eq('booking_type', 'tour_guide')
          .order('created_at', ascending: false);

      final allBookings = List<Map<String, dynamic>>.from(bookingsData);

      final userIds = allBookings.map((b) => b['user_id'] as String).toSet().toList();
      Map<String, Map<String, dynamic>> touristProfiles = {};
      if (userIds.isNotEmpty) {
        final profilesData = await supabase
            .from('profiles')
            .select('id, full_name, avatar_url, email, phone')
            .inFilter('id', userIds);
        for (var p in profilesData) {
          touristProfiles[p['id']] = Map<String, dynamic>.from(p);
        }
      }

      final enhancedBookings = allBookings.map((b) {
        final touristId = b['user_id'];
        final profile = touristProfiles[touristId];
        b['tourist_full_name'] = profile?['full_name'] ?? 'Unknown Tourist';
        b['tourist_avatar_url'] = profile?['avatar_url'];
        b['tourist_email'] = profile?['email'];
        b['tourist_phone'] = profile?['phone'];
        return b;
      }).toList();

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

      _totalBookings = enhancedBookings.length;
      _totalEarnings = enhancedBookings
          .where((b) => b['status'] == 'confirmed')
          .fold(0.0, (sum, b) => sum + (b['total_price'] as num).toDouble());

      final firstOfMonth = DateTime(now.year, now.month, 1);
      _earningsThisMonth = enhancedBookings
          .where((b) =>
      b['status'] == 'confirmed' &&
          b['travel_date'] != null &&
          DateTime.parse(b['travel_date']).isAfter(firstOfMonth))
          .fold(0.0, (sum, b) => sum + (b['total_price'] as num).toDouble());

      final firstOfToday = DateTime(now.year, now.month, now.day);
      _earningsToday = enhancedBookings
          .where((b) =>
      b['status'] == 'confirmed' &&
          b['travel_date'] != null &&
          DateTime.parse(b['travel_date']).isAfter(firstOfToday))
          .fold(0.0, (sum, b) => sum + (b['total_price'] as num).toDouble());

      final reviewsData = await supabase
          .from('guide_reviews')
          .select('*, profiles!guide_reviews_user_id_fkey(full_name, avatar_url)')
          .eq('guide_id', user.id)
          .order('created_at', ascending: false)
          .limit(3);
      _recentReviews = List<Map<String, dynamic>>.from(reviewsData);

      _bookingsByDate = {};
      for (var b in enhancedBookings) {
        if (b['status'] == 'confirmed' && b['travel_date'] != null) {
          final dateStr = b['travel_date'].toString().substring(0, 10);
          final date = DateTime.parse(dateStr);
          final key = DateTime(date.year, date.month, date.day);
          if (_bookingsByDate.containsKey(key)) {
            _bookingsByDate[key]!.add(b);
          } else {
            _bookingsByDate[key] = [b];
          }
        }
      }

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
      }
    }
  }

  // ---------- TOGGLE AVAILABILITY ----------
  Future<void> _toggleAvailability() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      final newValue = !_isAvailable;
      await supabase
          .from('profiles')
          .update({'is_available': newValue})
          .eq('id', user.id);
      setState(() {
        _isAvailable = newValue;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newValue ? 'You are now available for bookings' : 'You are now unavailable'),
          backgroundColor: newValue ? Colors.green : Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  // ---------- UPDATE BOOKING STATUS ----------
  Future<void> _updateBookingStatus(Map<String, dynamic> booking, String newStatus) async {
    if (_loading) return;

    final bookingId = booking['id'];
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _loading = true);
    try {
      if (newStatus == 'confirmed') {
        final travelDate = booking['travel_date'];
        final conflict = await supabase
            .from('bookings')
            .select('id')
            .eq('reference_id', user.id)
            .eq('booking_type', 'tour_guide')
            .eq('travel_date', travelDate)
            .eq('status', 'confirmed')
            .neq('id', bookingId)
            .maybeSingle();

        if (conflict != null) {
          if (mounted) {
            setState(() => _loading = false);
            _showAlreadyBookedDialog(travelDate);
          }
          return;
        }
      }

      await supabase
          .from('bookings')
          .update({'status': newStatus})
          .eq('id', bookingId);

      if (newStatus == 'confirmed') {
        final travelDate = booking['travel_date'];
        await supabase
            .from('bookings')
            .update({'status': 'cancelled'})
            .eq('reference_id', user.id)
            .eq('booking_type', 'tour_guide')
            .eq('travel_date', travelDate)
            .eq('status', 'pending')
            .neq('id', bookingId);
      }

      await _loadData();
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAlreadyBookedDialog(String? travelDate) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Already Booked'),
        content: Text('You already have a confirmed booking on ${_formatDate(travelDate)}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('OK', style: TextStyle(color: brandPrimary)),
          ),
        ],
      ),
    );
  }

  void _showTouristDialog(Map<String, dynamic> tourist) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(tourist['full_name'] ?? 'Tourist', style: const TextStyle(color: brandPrimary, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (tourist['avatar_url'] != null)
              CircleAvatar(
                radius: 40,
                backgroundImage: NetworkImage(tourist['avatar_url']),
              )
            else
              const CircleAvatar(
                radius: 40,
                backgroundColor: brandSecondary,
                child: Icon(Icons.person, size: 40, color: Colors.white),
              ),
            const SizedBox(height: 16),
            if (tourist['email'] != null)
              ListTile(
                leading: const Icon(Icons.email, color: brandPrimary),
                title: Text(tourist['email'], style: const TextStyle(fontSize: 14)),
              ),
            if (tourist['phone'] != null)
              ListTile(
                leading: const Icon(Icons.phone, color: brandPrimary),
                title: Text(tourist['phone'], style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _contactTourist(
                tourist['id'],
                tourist['full_name'] ?? 'Tourist',
                tourist['avatar_url'],
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: brandPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Message'),
          ),
        ],
      ),
    );
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

  // ---------- UPDATED: Week starts on Sunday ----------
  List<DateTime?> _getDaysInMonth(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final days = <DateTime>[];
    for (int i = 0; i < last.day; i++) {
      days.add(DateTime(month.year, month.month, i + 1));
    }
    // Sunday = 0, Monday = 1, ..., Saturday = 6
    final leadingOffset = first.weekday % 7; // Monday->1, Sunday->0
    final List<DateTime?> fullGrid = List.filled(leadingOffset + days.length, null);
    for (int i = 0; i < days.length; i++) {
      fullGrid[leadingOffset + i] = days[i];
    }
    return fullGrid;
  }

  // ---------- MODERN DESIGN UI HELPERS ----------
  Widget _statCard(String label, dynamic value, IconData icon, Color containerBgColor, {bool useDarkText = false}) {
    final Color contentColor = useDarkText ? brandPrimary : Colors.white;
    final Color labelColor = useDarkText ? Colors.grey.shade600 : Colors.white.withOpacity(0.85);

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: containerBgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              spreadRadius: 0,
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: useDarkText ? containerBgColor.withOpacity(0.12) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: contentColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value.toString(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: contentColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(color: labelColor, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickAction(IconData icon, String label, int count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: brandBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: brandPrimary, size: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: brandPrimary),
                ),
              ],
            ),
            if (count > 0)
              Positioned(
                right: 16,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- BUILD ----------
  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return const Scaffold(
        backgroundColor: brandBackground,
        body: Center(child: Text('Please log in.')),
      );
    }

    return Scaffold(
      backgroundColor: brandBackground,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: brandPrimary,
        centerTitle: false,
        actions: [
          Row(
            children: [
              Text(
                _isAvailable ? 'Available' : 'Unavailable',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white),
              ),
              Switch(
                value: _isAvailable,
                onChanged: (_) => _toggleAvailability(),
                activeColor: brandSecondary,
                inactiveThumbColor: Colors.grey.shade400,
                inactiveTrackColor: Colors.grey.shade700,
              ),
            ],
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _signOut,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: brandPrimary))
          : RefreshIndicator(
        onRefresh: _loadData,
        color: brandPrimary,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                    ],
                  ),
                ),

              // ----- Unified Quick Action Layout (now includes Map) -----
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _quickAction(Icons.person_outline_rounded, 'Profile', 0, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),
                  _quickAction(Icons.history_rounded, 'History', 0, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()))),
                  _quickAction(Icons.chat_bubble_outline_rounded, 'Messages', _unreadCount, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()))),
                  _quickAction(Icons.map_rounded, 'Map', 0, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MapScreen()))), // <-- added Map button
                ],
              ),
              const SizedBox(height: 24),

              // ----- Financial & Stats Section -----
              Row(
                children: [
                  _statCard('Total Trips', _totalBookings, Icons.map_outlined, Colors.cyan),
                  const SizedBox(width: 12),
                  _statCard('Total Income', '৳${_totalEarnings.toStringAsFixed(0)}', Icons.payments_outlined, Colors.green.shade600),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _statCard('This Month', '৳${_earningsThisMonth.toStringAsFixed(0)}', Icons.calendar_month_outlined, Colors.orange.shade600),
                  const SizedBox(width: 12),
                  _statCard('Today', '৳${_earningsToday.toStringAsFixed(0)}', Icons.today_outlined, Colors.deepPurple.shade600),
                ],
              ),
              const SizedBox(height: 24),

              // ----- Calendar & Schedule Details -----
              _buildBookingCalendar(),
              const SizedBox(height: 24),
              _buildTodaySchedule(),
              const SizedBox(height: 24),

              // ----- Upcoming Trips Block -----
              const Text(
                'Upcoming Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPrimary),
              ),
              const SizedBox(height: 12),
              if (_upcomingBookings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('No upcoming trips scheduled.', style: TextStyle(color: Colors.grey))),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _upcomingBookings.length,
                  itemBuilder: (context, index) {
                    final b = _upcomingBookings[index];
                    final touristName = b['tourist_full_name'] ?? 'Unknown Tourist';
                    final isPast = b['travel_date'] != null && DateTime.parse(b['travel_date']).isBefore(DateTime.now());
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: brandSecondary.withOpacity(0.2), shape: BoxShape.circle),
                          child: const Icon(Icons.event_available, color: brandPrimary),
                        ),
                        title: Text(touristName, style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                        subtitle: Text('Date: ${_formatDate(b['travel_date'])}', style: TextStyle(color: Colors.grey.shade600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.info_outline_rounded, color: brandSecondary),
                              onPressed: () => _showTouristDialog({
                                'id': b['user_id'],
                                'full_name': touristName,
                                'avatar_url': b['tourist_avatar_url'],
                                'email': b['tourist_email'],
                                'phone': b['tourist_phone'],
                              }),
                            ),
                            Text('৳${b['total_price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                            if (isPast && b['status'] == 'confirmed')
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: ElevatedButton(
                                  onPressed: _loading ? null : () => _updateBookingStatus(b, 'completed'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandPrimary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: const Text('Complete', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              const SizedBox(height: 24),

              // ----- Request Management / Pending Orders -----
              const Text(
                'Incoming Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPrimary),
              ),
              const SizedBox(height: 12),
              if (_pendingBookings.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: const Center(child: Text('No structural active requests.', style: TextStyle(color: Colors.grey))),
                )
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

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: brandSecondary, width: 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Booking ID #${b['id']}', style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                                child: Text('PENDING', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold, fontSize: 11)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            children: [
                              Expanded(child: Text('Tourist: $touristName', style: const TextStyle(fontWeight: FontWeight.w600, color: brandPrimary))),
                              IconButton(
                                icon: const Icon(Icons.info_outline_rounded, color: brandSecondary, size: 20),
                                onPressed: () => _showTouristDialog({
                                  'id': touristId,
                                  'full_name': touristName,
                                  'avatar_url': avatarUrl,
                                  'email': b['tourist_email'],
                                  'phone': b['tourist_phone'],
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Travel Date: ${_formatDate(b['travel_date'])}', style: TextStyle(color: Colors.grey.shade700)),
                          Text('Offer Price: ৳${b['total_price']}', style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => _contactTourist(touristId, touristName, avatarUrl),
                                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                                label: const Text('Discuss'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: brandPrimary,
                                  side: const BorderSide(color: brandPrimary),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: _loading ? null : () => _updateBookingStatus(b, 'cancelled'),
                                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                    child: const Text('Decline'),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _loading ? null : () => _updateBookingStatus(b, 'confirmed'),
                                    style: ElevatedButton.styleFrom(backgroundColor: brandPrimary, foregroundColor: Colors.white, elevation: 0),
                                    child: const Text('Accept'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 24),

              // ----- Feedbacks Section -----
              if (_recentReviews.isNotEmpty) ...[
                const Text(
                  'Recent Feedback',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPrimary),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: _recentReviews.map((r) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: brandSecondary.withOpacity(0.3),
                        backgroundImage: r['profiles']?['avatar_url'] != null ? NetworkImage(r['profiles']['avatar_url']) : null,
                        child: r['profiles']?['avatar_url'] == null ? Text(r['profiles']?['full_name']?[0] ?? '?', style: const TextStyle(color: brandPrimary)) : null,
                      ),
                      title: Text(r['profiles']?['full_name'] ?? 'Anonymous', style: const TextStyle(fontWeight: FontWeight.bold, color: brandPrimary)),
                      subtitle: Text(r['comment'] ?? '', style: TextStyle(color: Colors.grey.shade600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) => Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: index < (r['rating'] ?? 0) ? Colors.amber : Colors.grey.shade300,
                        )),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------- CALENDAR WIDGET ----------
  Widget _buildBookingCalendar() {
    if (_upcomingBookings.isEmpty) return const SizedBox.shrink();

    final days = _getDaysInMonth(_focusedMonth);
    final String currentMonthName = _monthNames[_focusedMonth.month - 1];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: brandPrimary),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
              ),
              Text(
                '$currentMonthName ${_focusedMonth.year}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: brandPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: brandPrimary),
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Day Names Grid Header (starting with Sun)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: 7,
            itemBuilder: (context, index) {
              // Friday is the 5th index (0-based) because week starts Sunday
              final isFriday = _weekdays[index] == 'Fri';
              return Center(
                child: Text(
                  _weekdays[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isFriday ? Colors.red : brandPrimary.withOpacity(0.6),
                  ),
                ),
              );
            },
          ),
          const Divider(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              if (date == null) {
                return const SizedBox.shrink();
              }

              final hasBooking = _bookingsByDate.containsKey(date);
              final isToday = date.day == DateTime.now().day && date.month == DateTime.now().month && date.year == DateTime.now().year;
              final isFriday = date.weekday == DateTime.friday;

              Color textColor = brandPrimary;
              if (isToday) {
                textColor = Colors.white;
              } else if (isFriday) {
                textColor = Colors.red;
              }

              return Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isToday ? brandPrimary : (hasBooking ? brandSecondary.withOpacity(0.3) : Colors.transparent),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontWeight: (isToday || hasBooking || isFriday) ? FontWeight.bold : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: brandSecondary.withOpacity(0.4), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Booked Dates', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySchedule() {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().substring(0, 10);
    final todayBookings = _upcomingBookings.where((b) {
      final date = b['travel_date']?.toString().substring(0, 10);
      return date == todayStr;
    }).toList();

    if (todayBookings.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Lineup',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: brandPrimary),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 90,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: todayBookings.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (ctx, idx) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: brandPrimary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    todayBookings[idx]['tourist_full_name'] ?? 'Tourist',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🕐 ${todayBookings[idx]['travel_date']?.toString().substring(11, 16) ?? 'All Day'}',
                    style: const TextStyle(color: brandSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}