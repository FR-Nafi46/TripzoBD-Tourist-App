import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'place_suggestion_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isAdmin = false;
  bool _loading = true;
  int _bookings = 0;
  int _users = 0;
  int _places = 0;
  List<Map<String, dynamic>> _pendingSuggestions = [];
  List<Map<String, dynamic>> _pendingTourGuides = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final profile = await supabase
          .from('profiles')
          .select('role, is_admin')
          .eq('id', user.id)
          .maybeSingle();

      final isAdminUser = (profile != null) &&
          ((profile['is_admin'] == true) || (profile['role'] == 'admin'));

      if (!isAdminUser) {
        setState(() {
          _isAdmin = false;
          _loading = false;
        });
        return;
      }

      final bookings = await supabase.from('bookings').select('id');
      final users = await supabase.from('profiles').select('id');
      final places = await supabase.from('places').select('id');
      final suggestions = await supabase
          .from('place_suggestions')
          .select('*, profiles(full_name)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final pendingGuides = await supabase
          .from('profiles')
          .select('id, full_name, guide_division, languages, price_per_day, bio, created_at, avatar_url')
          .eq('role', 'tour_guide')
          .eq('is_approved', false)
          .order('created_at', ascending: false);

      setState(() {
        _isAdmin = true;
        _bookings = (bookings as List).length;
        _users = (users as List).length;
        _places = (places as List).length;
        _pendingSuggestions = List<Map<String, dynamic>>.from(suggestions);
        _pendingTourGuides = List<Map<String, dynamic>>.from(pendingGuides);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading admin data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _refreshSuggestions() async {
    final suggestions = await supabase
        .from('place_suggestions')
        .select('*, profiles(full_name)')
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    setState(() {
      _pendingSuggestions = List<Map<String, dynamic>>.from(suggestions);
    });
  }

  Future<void> _approveTourGuide(Map<String, dynamic> guide) async {
    try {
      await supabase
          .from('profiles')
          .update({'is_approved': true})
          .eq('id', guide['id']);
      _refreshTourGuides();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour guide approved!')),
        );
      }
    } catch (e) {
      _showError('Approval failed: $e');
    }
  }

  Future<void> _rejectTourGuide(Map<String, dynamic> guide) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Tour Guide'),
        content: const Text('Are you sure? This will permanently delete the account registration.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      // Delete the profile (cascades to auth.users via foreign key)
      await supabase.from('profiles').delete().eq('id', guide['id']);
      _refreshTourGuides();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour guide rejected and removed.')),
        );
      }
    } catch (e) {
      _showError('Reject failed: $e');
    }
  }

  Future<void> _refreshTourGuides() async {
    final pendingGuides = await supabase
        .from('profiles')
        .select('id, full_name, guide_division, languages, price_per_day, bio, created_at, avatar_url')
        .eq('role', 'tour_guide')
        .eq('is_approved', false)
        .order('created_at', ascending: false);
    setState(() {
      _pendingTourGuides = List<Map<String, dynamic>>.from(pendingGuides);
    });
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w600))),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.w600))),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text('Admin access required.', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Admin Console', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('System Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 12),

            // Metrics Grid
            Row(
              children: [
                _statCard('Total Bookings', _bookings, Icons.assignment, const Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                _statCard('Total Users', _users, Icons.people_alt, MyApp.secondaryColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Total Places', _places, Icons.map, MyApp.primaryColor),
              ],
            ),
            const SizedBox(height: 28),

            // Pending Place Suggestions
            _sectionHeader('Pending Place Suggestions', _pendingSuggestions.length),
            const SizedBox(height: 10),
            if (_pendingSuggestions.isEmpty)
              _emptyState('No pending place suggestions at this time.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingSuggestions.length,
                itemBuilder: (context, i) {
                  final s = _pendingSuggestions[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.location_on, color: Colors.orange),
                      ),
                      title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Division: ${s['division']} • Category: ${s['category'] ?? 'N/A'}', style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            if (s['description'] != null) ...[
                              const SizedBox(height: 4),
                              Text(s['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                            const SizedBox(height: 6),
                            Text('Submitted by: ${s['profiles']?['full_name'] ?? 'Unknown'}', style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaceSuggestionDetailScreen(
                              suggestion: s,
                              onActionComplete: _refreshSuggestions,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // Pending Tour Guide Approvals
            _sectionHeader('Pending Tour Guide Approvals', _pendingTourGuides.length),
            const SizedBox(height: 10),
            if (_pendingTourGuides.isEmpty)
              _emptyState('No pending tour guide applications.')
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _pendingTourGuides.length,
                itemBuilder: (context, i) {
                  final g = _pendingTourGuides[i];
                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: Colors.blue[50],
                                backgroundImage: g['avatar_url'] != null ? NetworkImage(g['avatar_url']) : null,
                                child: g['avatar_url'] == null
                                    ? Icon(Icons.person, color: Colors.blue[700])
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(g['full_name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                                    Text('${g['guide_division'] ?? 'Global'} Division', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text('৳${g['price_per_day']}/day', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15)),
                            ],
                          ),
                          const Divider(height: 24),
                          Text('Languages: ${g['languages']?.join(', ') ?? 'N/A'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                          if (g['bio'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Bio: ${g['bio']}', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.close, size: 16),
                                label: const Text('Reject'),
                                onPressed: () => _rejectTourGuide(g),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: const Icon(Icons.check, size: 16),
                                label: const Text('Approve'),
                                onPressed: () => _approveTourGuide(g),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // Recent System Bookings
            const Text('Recent System Bookings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 10),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: supabase
                  .from('bookings')
                  .select()
                  .order('created_at', ascending: false)
                  .limit(25),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final list = snapshot.data ?? [];
                if (list.isEmpty) return _emptyState('No bookings found in system.');

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey[200]!),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: list.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.grey[100], height: 1),
                    itemBuilder: (context, i) {
                      final b = list[i];
                      final isPending = b['status'] == 'pending';
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        leading: CircleAvatar(
                          backgroundColor: isPending ? Colors.amber[50] : Colors.green[50],
                          child: Icon(Icons.receipt_long, color: isPending ? Colors.amber[800] : Colors.green[800], size: 20),
                        ),
                        title: Text(
                          '${b['booking_type']} (#${b['id']})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text(
                          '৳${b['total_price']} • ${b['created_at'].toString().substring(0, 10)}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                        trailing: isPending
                            ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: MyApp.secondaryColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            fixedSize: const Size(80, 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          ),
                          onPressed: () async {
                            await supabase
                                .from('bookings')
                                .update({'status': 'confirmed'})
                                .eq('id', b['id']);
                            setState(() {});
                          },
                          child: const Text('Confirm', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                            : Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (b['status'] as String).toUpperCase(),
                            style: TextStyle(color: Colors.grey[700], fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12)),
            child: Text('$count pending', style: TextStyle(color: Colors.red[700], fontSize: 11, fontWeight: FontWeight.bold)),
          )
        ]
      ],
    );
  }

  Widget _emptyState(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message, style: TextStyle(color: Colors.grey[600], fontSize: 14, fontStyle: FontStyle.italic)),
    );
  }

  Widget _statCard(String label, int value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$value', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}