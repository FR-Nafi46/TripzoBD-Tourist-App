import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'main.dart';

class PlaceSuggestionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> suggestion;
  final VoidCallback onActionComplete;

  const PlaceSuggestionDetailScreen({
    super.key,
    required this.suggestion,
    required this.onActionComplete,
  });

  @override
  State<PlaceSuggestionDetailScreen> createState() =>
      _PlaceSuggestionDetailScreenState();
}

class _PlaceSuggestionDetailScreenState
    extends State<PlaceSuggestionDetailScreen> {
  bool _processing = false;
  late List<String> _images;
  String? _errorMessage;

  final PageController _pageController = PageController();
  int _currentImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _extractImages();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _extractImages() {
    _images = [];
    _errorMessage = null;

    final imagesRaw = widget.suggestion['images'];
    if (imagesRaw != null) {
      if (imagesRaw is List) {
        _images = imagesRaw.map((e) => e.toString()).toList();
      } else if (imagesRaw is String) {
        try {
          final decoded = jsonDecode(imagesRaw);
          if (decoded is List) {
            _images = decoded.map((e) => e.toString()).toList();
          } else {
            _images = [imagesRaw];
          }
        } catch (e) {
          if (imagesRaw.isNotEmpty) _images = [imagesRaw];
        }
      }
    }

    final cover = widget.suggestion['cover_image'];
    if (cover != null && cover.toString().isNotEmpty) {
      String coverUrl = cover.toString();
      if (!_images.contains(coverUrl)) {
        _images.insert(0, coverUrl);
      }
    }

    if (_images.isEmpty) {
      final legacy = widget.suggestion['image_url'];
      if (legacy != null && legacy.toString().isNotEmpty) {
        _images = [legacy.toString()];
      }
    }

    if (_images.isEmpty) {
      _errorMessage = 'No media links attached to this suggestion.';
    }
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            clipBehavior: Clip.none,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 64, color: Colors.white24),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      await supabase.from('places').insert({
        'division': widget.suggestion['division'],
        'name': widget.suggestion['name'],
        'description': widget.suggestion['description'],
        'category': widget.suggestion['category'],
        'history': widget.suggestion['history'],
        'best_time_to_visit': widget.suggestion['best_time_to_visit'],
        'entry_fee': widget.suggestion['entry_fee'],
        'opening_hours': widget.suggestion['opening_hours'],
        'latitude': widget.suggestion['latitude'],
        'longitude': widget.suggestion['longitude'],
        'images': _images,
        'cover_image': widget.suggestion['cover_image'] ?? (_images.isNotEmpty ? _images[0] : null),
      });

      await supabase
          .from('place_suggestions')
          .update({'status': 'approved'})
          .eq('id', widget.suggestion['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Suggestion successfully moved live to public catalog.')),
        );
        widget.onActionComplete();
        Navigator.pop(context);
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
        title: const Text('Drop Suggestion?'),
        content: const Text('Are you sure you want to mark this place proposal as rejected?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Proposal', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _processing = true);
    try {
      await supabase
          .from('place_suggestions')
          .update({'status': 'rejected'})
          .eq('id', widget.suggestion['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion flagged as rejected.')));
        widget.onActionComplete();
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Rejection failed: $e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _infoRow(IconData icon, String title, dynamic value, {bool isLast = false}) {
    if (value == null || value.toString().isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: Colors.blueGrey[600]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  const SizedBox(height: 4),
                  Text(value.toString(), style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
        if (!isLast) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.suggestion;
    final lat = s['latitude'];
    final lng = s['longitude'];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Review Proposal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_images.isNotEmpty)
              Container(
                height: 250,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: PageView.builder(
                        controller: _pageController,
                        itemCount: _images.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final isCover = _images[index] == s['cover_image'] || (index == 0 && s['cover_image'] == null);
                          return GestureDetector(
                            onTap: () => _showFullScreenImage(_images[index]),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  _images[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.broken_image, color: Colors.grey, size: 40),
                                  ),
                                ),
                                Positioned(
                                  top: 14,
                                  left: 14,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: isCover ? Colors.orange : Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      isCover ? 'Primary Cover' : 'Image #${index + 1}',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    if (_images.length > 1)
                      Positioned(
                        bottom: 14,
                        right: 14,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              _images.length,
                                  (index) => Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _currentImageIndex == index
                                      ? Colors.white
                                      : Colors.white.withOpacity(0.4),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              Container(
                height: 140,
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(width: 1, color: Colors.grey[300]!),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 36),
                      const SizedBox(height: 6),
                      Text(_errorMessage ?? 'No visuals supplied.', style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                    ],
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    s['name'] ?? 'Untitled Submission',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          (s['category'] ?? 'Uncategorized').toString().toUpperCase(),
                          style: TextStyle(color: Colors.blue[800], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 2),
                      Text(s['division'] ?? 'Global', style: TextStyle(color: Colors.grey[700], fontSize: 14, fontWeight: FontWeight.w500)),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (lat != null && lng != null) ...[
                    const Text('Location Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 200,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: LatLng(lat, lng), zoom: 15),
                          markers: {Marker(markerId: const MarkerId('preview'), position: LatLng(lat, lng))},
                          liteModeEnabled: true,
                          myLocationEnabled: false,
                          myLocationButtonEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey[200]!),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.notes, 'About Destination', s['description']),
                          _infoRow(Icons.history_edu, 'Heritage & Historical Background', s['history']),
                          _infoRow(Icons.calendar_today, 'Optimal Time to Visit', s['best_time_to_visit']),
                          _infoRow(Icons.payments_outlined, 'Access / Entry Fee Structure', s['entry_fee']),
                          _infoRow(Icons.schedule, 'Operational Window / Hours', s['opening_hours']),
                          _infoRow(
                            Icons.explore_outlined,
                            'Geographic Telemetry',
                            s['latitude'] != null ? 'Latitude: ${s['latitude']}\nLongitude: ${s['longitude']}' : null,
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _processing ? null : _reject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.red,
                            elevation: 0,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Reject Submission', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _processing ? null : _approve,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[700],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _processing
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Approve & Go Live', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
