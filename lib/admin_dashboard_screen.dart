import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'place_suggestion_detail_screen.dart';
import 'tour_guide_approval_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isAdmin = false;
  bool _loading = true;
  int _totalAdmins = 0;
  int _totalTourists = 0;
  int _totalGuides = 0;
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

      // Count admins
      final admins = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'admin');
      // Count tourists (role = 'user')
      final tourists = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'user');
      // Count guides (role = 'tour_guide')
      final guides = await supabase
          .from('profiles')
          .select('id')
          .eq('role', 'tour_guide');

      final places = await supabase.from('places').select('id');

      final suggestions = await supabase
          .from('place_suggestions')
          .select('*, profiles(full_name)')
          .eq('status', 'pending')
          .order('created_at', ascending: false);

      final pendingGuides = await supabase
          .from('profiles')
          .select('*')
          .eq('role', 'tour_guide')
          .eq('is_approved', false)
          .order('created_at', ascending: false);

      setState(() {
        _isAdmin = true;
        _totalAdmins = (admins as List).length;
        _totalTourists = (tourists as List).length;
        _totalGuides = (guides as List).length;
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

  Future<void> _refreshTourGuides() async {
    final pendingGuides = await supabase
        .from('profiles')
        .select('*')
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

            // Metrics Grid: Total Admins, Tourists, Guides, Places
            Row(
              children: [
                _statCard('Admins', _totalAdmins, Icons.admin_panel_settings, const Color(0xFF1E3A8A)),
                const SizedBox(width: 12),
                _statCard('Tourists', _totalTourists, Icons.people, MyApp.secondaryColor),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _statCard('Guides', _totalGuides, Icons.person_pin, Colors.green.shade700),
                const SizedBox(width: 12),
                _statCard('Places', _places, Icons.map, MyApp.primaryColor),
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

            // ============================================================
            // Pending Tour Guide Approvals
            // ============================================================
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
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[50],
                        backgroundImage: g['avatar_url'] != null
                            ? NetworkImage(g['avatar_url'])
                            : null,
                        child: g['avatar_url'] == null
                            ? Icon(Icons.person, color: Colors.blue[700])
                            : null,
                      ),
                      title: Text(
                        g['full_name'] ?? 'Unknown',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${g['guide_division'] ?? 'Global'} Division'),
                          Text(
                            '৳${g['price_per_day']}/day',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          if (g['email'] != null && g['email'].toString().isNotEmpty)
                            Text('📧 ${g['email']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                          if (g['phone'] != null && g['phone'].toString().isNotEmpty)
                            Text('📞 ${g['phone']}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TourGuideApprovalDetailScreen(
                              guide: g,
                              onActionComplete: _refreshTourGuides,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),
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