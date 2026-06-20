import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';

class TransportBookingScreen extends StatefulWidget {
  const TransportBookingScreen({super.key});

  @override
  State<TransportBookingScreen> createState() => _TransportBookingScreenState();
}

class _TransportBookingScreenState extends State<TransportBookingScreen> {
  late Future<List<Map<String, dynamic>>> _companiesFuture;
  String _selectedDivision = 'All';
  final List<String> _divisions = [
    'All', 'Dhaka', 'Chattogram', 'Rajshahi',
    'Khulna', 'Barishal', 'Sylhet', 'Rangpur', 'Mymensingh',
  ];

  // Configured precisely around the app's explicit color palette
  final Color _primaryColor = const Color(0xFF0B2B26);     // Dark Teal
  final Color _secondaryColor = const Color(0xFF8EB69B);   // Soft Sage Green
  final Color _bgBackground = const Color(0xFFF2F0FA);     // White Lilac

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  void _loadCompanies() {
    var query = supabase.from('car_rental_companies').select();
    if (_selectedDivision != 'All') {
      query = query.eq('division', _selectedDivision);
    }
    _companiesFuture = query.order('name', ascending: true);
    setState(() {});
  }

  // ─── ADD TRANSPORT / RENTAL COMPANY ──────────────────────────────
  Future<void> _addCompany() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to add a transport.')),
      );
      return;
    }

    final nameController = TextEditingController();
    final divisionController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final carTypesController = TextEditingController();
    final serviceAreaController = TextEditingController();
    final descriptionController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text('Add Transport Company', style: TextStyle(color: _primaryColor, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Company Name *'),
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
                  controller: phoneController,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email Address'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: carTypesController,
                  decoration: const InputDecoration(
                    labelText: 'Car Types (comma separated)',
                    hintText: 'e.g. Sedan, SUV, Minivan',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: serviceAreaController,
                  decoration: const InputDecoration(
                    labelText: 'Service Area',
                    hintText: 'e.g. All Bangladesh, Dhaka only',
                  ),
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
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();
              final carTypesRaw = carTypesController.text.trim();
              final serviceArea = serviceAreaController.text.trim();
              final description = descriptionController.text.trim();

              List<String> carTypes = [];
              if (carTypesRaw.isNotEmpty) {
                carTypes = carTypesRaw
                    .split(',')
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
              }

              final companyData = {
                'name': name,
                'division': division,
                'phone': phone.isEmpty ? null : phone,
                'email': email.isEmpty ? null : email,
                'car_types': carTypes,
                'service_area': serviceArea.isEmpty ? null : serviceArea,
                'description': description.isEmpty ? null : description,
              };

              try {
                await supabase.from('car_rental_companies').insert(companyData);
                if (mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transport added successfully!')),
                  );
                  _loadCompanies();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error adding transport: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Add Transport'),
          ),
        ],
      ),
    );
  }

  void _viewCompany(Map<String, dynamic> company) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransportDetailScreen(company: company),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: const Text(
          'Transport Information',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
        ),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCompany,
        icon: const Icon(Icons.add),
        label: const Text('Add Transport'),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Horizontal Choice Chip Scrollbar Filter ---
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
                                _loadCompanies();
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

          // --- Main Core List Feed ---
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _companiesFuture,
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
                final companies = snapshot.data ?? [];
                if (companies.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_car_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text(
                          'No transport companies found in $_selectedDivision.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: companies.length,
                  itemBuilder: (context, i) {
                    final company = companies[i];
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
                          onTap: () => _viewCompany(company),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Left Icon Element mirroring the design style
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: _secondaryColor.withOpacity(0.2),
                                  child: Icon(Icons.directions_car, size: 26, color: _primaryColor),
                                ),
                                const SizedBox(width: 16),

                                // Explanatory Details
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              company['name'] ?? 'Company Name',
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
                                            company['division'] ?? 'Undefined',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Car Types chips wrap
                                      if (company['car_types'] != null && (company['car_types'] as List).isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: (company['car_types'] as List)
                                                .map<Widget>((type) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _bgBackground,
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                type.toString(),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: _primaryColor,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ))
                                                .toList(),
                                          ),
                                        ),

                                      // --- Clean Dotted Separator Match ---
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
                                      const SizedBox(height: 6),

                                      // Contact details sub-row footer
                                      Row(
                                        children: [
                                          if (company['phone'] != null) ...[
                                            Icon(Icons.phone, size: 13, color: Colors.grey[400]),
                                            const SizedBox(width: 4),
                                            Text(
                                              company['phone'],
                                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                            ),
                                          ] else ...[
                                            Text('Contact Available', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                          ],
                                          const Spacer(),
                                          if (company['service_area'] != null)
                                            Text(
                                              company['service_area'],
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _secondaryColor,
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
}

// ─── Transport Detail Screen ──────────────────────────────────────────
class TransportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> company;
  const TransportDetailScreen({super.key, required this.company});

  final Color _primaryColor = const Color(0xFF0B2B26);
  final Color _bgBackground = const Color(0xFFF2F0FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBackground,
      appBar: AppBar(
        title: Text(company['name'] ?? 'Company Details', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19)),
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
                Text(
                  company['name'] ?? 'Unknown Company',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _primaryColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const Divider(height: 32, thickness: 1.2),

                _infoRow(Icons.location_city, 'Division', company['division'] ?? 'N/A'),
                if (company['phone'] != null && company['phone'].toString().isNotEmpty)
                  _infoRow(Icons.phone, 'Phone', company['phone']),
                if (company['email'] != null && company['email'].toString().isNotEmpty)
                  _infoRow(Icons.email, 'Email', company['email']),
                if (company['car_types'] != null && (company['car_types'] as List).isNotEmpty)
                  _infoRow(
                    Icons.directions_car,
                    'Available Fleet / Car Types',
                    (company['car_types'] as List).join(', '),
                  ),
                if (company['service_area'] != null && company['service_area'].toString().isNotEmpty)
                  _infoRow(Icons.location_on, 'Service Area', company['service_area']),
                if (company['description'] != null && company['description'].toString().isNotEmpty)
                  _infoRow(Icons.description, 'Description', company['description']),
                if (company['created_at'] != null)
                  _infoRow(Icons.calendar_today, 'Added on', _formatDate(company['created_at'])),
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