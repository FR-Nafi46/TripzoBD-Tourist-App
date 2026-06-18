import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class TourGuideApprovalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> guide;
  final Future<void> Function() onActionComplete;

  const TourGuideApprovalDetailScreen({
    super.key,
    required this.guide,
    required this.onActionComplete,
  });

  @override
  State<TourGuideApprovalDetailScreen> createState() =>
      _TourGuideApprovalDetailScreenState();
}

class _TourGuideApprovalDetailScreenState
    extends State<TourGuideApprovalDetailScreen> {
  bool _processing = false;

  // Custom palette shortcuts mapped directly from your configuration
  final Color _primaryColor = const Color(0xFF0B2B26);
  final Color _secondaryColor = const Color(0xFF8EB69B);
  final Color _bgBackground = const Color(0xFFF2F0FA);

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('profiles')
          .update({'is_approved': true})
          .eq('id', widget.guide['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour guide approved successfully.')),
        );
        await widget.onActionComplete();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError('Approval failed: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _reject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Application'),
        content: const Text(
          'Are you sure you want to reject this tour guide? '
              'This action permanently deletes their application and account metadata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Reject & Delete',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('profiles').delete().eq('id', widget.guide['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tour guide rejected and removed.')),
        );
        await widget.onActionComplete();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      _showError('Rejection failed: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
    );
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    List<String> names = name.split(" ");
    if (names.length > 1) {
      return "${names[0][0]}${names[1][0]}".toUpperCase();
    }
    return names[0][0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guide;
    final String fullName = g['full_name'] ?? 'Anonymous Applicant';

    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: const Text(
          'Application Review',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Profile Hero Card ---
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: _secondaryColor.withOpacity(0.3),
                            backgroundImage: g['avatar_url'] != null
                                ? NetworkImage(g['avatar_url'])
                                : null,
                            child: g['avatar_url'] == null
                                ? Text(
                              _getInitials(fullName),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: _primaryColor,
                              ),
                            )
                                : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            fullName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: _primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: _primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Submitted: ${_formatDate(g['created_at'])}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1),
                          const SizedBox(height: 16),

                          // Quick Contact Sub-row
                          _buildContactRow(Icons.email_outlined, g['email']),
                          const SizedBox(height: 10),
                          _buildContactRow(Icons.phone_android_outlined, g['phone']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Dynamic Information Header ---
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      child: Text(
                        'APPLICANT DETAILS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),

                    // --- Build Dynamic Info Cards Stack ---
                    _buildInfoCards(g),
                  ],
                ),
              ),
            ),

            // --- Sticky Action Bar at Bottom ---
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _processing ? null : _reject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[700],
                        side: BorderSide(color: Colors.red[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'REJECT',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _processing ? null : _approve,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _processing
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'APPROVE',
                        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactRow(IconData icon, dynamic value) {
    if (value == null || value.toString().trim().isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value.toString(),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCards(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> fields = [
      {'key': 'guide_division', 'icon': Icons.location_city, 'label': 'Operating Division'},
      {'key': 'location', 'icon': Icons.location_on, 'label': 'Current Location'},
      {'key': 'languages', 'icon': Icons.translate, 'label': 'Spoken Languages', 'isList': true},
      {'key': 'price_per_day', 'icon': Icons.payments, 'label': 'Expected Price per Day', 'isCurrency': true},
      {'key': 'date_of_birth', 'icon': Icons.cake, 'label': 'Date of Birth'},
      {'key': 'gender', 'icon': Icons.person_outline, 'label': 'Gender'},
      {'key': 'blood_group', 'icon': Icons.bloodtype, 'label': 'Blood Group'},
      {'key': 'user_languages', 'icon': Icons.g_translate, 'label': 'Secondary Languages', 'isList': true},
      {'key': 'bio', 'icon': Icons.assignment, 'label': 'Bio & Professional Experience', 'isMultiline': true},
    ];

    final displayedWidgets = <Widget>[];

    for (var field in fields) {
      final key = field['key'] as String;
      final value = data[key];
      if (value == null) continue;

      final iconData = field['icon'] as IconData;
      final label = field['label'] as String;
      final isList = field['isList'] as bool? ?? false;
      final isCurrency = field['isCurrency'] as bool? ?? false;
      final isMultiline = field['isMultiline'] as bool? ?? false;

      String displayValue;
      if (isList) {
        if (value is List) {
          displayValue = value.join(', ');
        } else if (value is String) {
          final trimmed = value.trim();
          if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
            final inner = trimmed.substring(1, trimmed.length - 1);
            final parts = inner.split(',').map((s) => s.trim().replaceAll('"', '')).toList();
            displayValue = parts.join(', ');
          } else {
            displayValue = value;
          }
        } else {
          displayValue = value.toString();
        }
      } else if (isCurrency) {
        displayValue = '৳ $value';
      } else {
        displayValue = value.toString();
      }

      if (displayValue.trim().isEmpty) continue;

      displayedWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: _primaryColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isMultiline ? FontWeight.normal : FontWeight.w500,
                        color: _primaryColor,
                        height: isMultiline ? 1.4 : 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (displayedWidgets.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: Text(
            'No detailed metadata available for this applicant.',
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
      );
    }

    // Wrap elements nicely with structural dividers between rows inside a pristine background layout card
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: displayedWidgets.length,
        separatorBuilder: (context, index) => Divider(
          color: Colors.grey[200],
          height: 1,
        ),
        itemBuilder: (context, index) => displayedWidgets[index],
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final parsed = DateTime.parse(date.toString()).toLocal();
      // Returns cleaner output: "YYYY-MM-DD"
      return "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}";
    } catch (_) {
      return date.toString();
    }
  }
}