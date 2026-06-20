import 'dart:async';                    // <-- added for Timer
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final TextEditingController _searchController = TextEditingController();
  LatLng? _currentPosition;
  bool _isLoading = true;
  bool _isSearching = false;
  BitmapDescriptor? _myLocationIcon;

  // ---------- New: zoom-based scaling ----------
  double _currentZoom = 14.0;         // initial zoom
  static const double _baseZoom = 14.0; // reference zoom = original size
  Timer? _zoomTimer;                  // debounce timer

  static const LatLng _defaultLocation = LatLng(23.8103, 90.4125);

  @override
  void initState() {
    super.initState();
    _createMyLocationIcon(scale: 1.0).then((_) => _getCurrentLocation());
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _zoomTimer?.cancel();
    super.dispose();
  }

  /// Creates the custom blue pulsing "You are here" dot.
  /// [scale] grows the icon when the user zooms in.
  Future<void> _createMyLocationIcon({double scale = 1.0}) async {
    final baseSize = 80.0;
    final size = baseSize * scale.clamp(0.5, 2.5); // prevent extreme sizes
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Outer pulsing ring
    final outerPaint = Paint()
      ..color = const Color(0xFF4285F4).withOpacity(0.25)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 2, outerPaint);

    // Middle ring
    final middlePaint = Paint()
      ..color = const Color(0xFF4285F4).withOpacity(0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 3, middlePaint);

    // White border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 4.5, borderPaint);

    // Inner blue dot
    final dotPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), size / 6, dotPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.ceil(), size.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final Uint8List imageBytes = byteData!.buffer.asUint8List();

    _myLocationIcon = BitmapDescriptor.fromBytes(imageBytes);
  }

  void _addOrUpdateMyLocationMarker(LatLng position) {
    final marker = Marker(
      markerId: const MarkerId('my_location'),
      position: position,
      icon: _myLocationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      infoWindow: const InfoWindow(title: 'You are here'),
      zIndex: 3,
    );
    setState(() {
      _markers.removeWhere((m) => m.markerId == const MarkerId('my_location'));
      _markers.add(marker);
    });
  }

  /// Called every time the camera moves – updates the zoom level and redraws the icon.
  void _onCameraMove(CameraPosition position) {
    final newZoom = position.zoom;
    // ignore tiny changes
    if ((newZoom - _currentZoom).abs() < 0.3) return;
    _currentZoom = newZoom;

    // Debounce to avoid rebuilding the icon dozens of times per second
    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(milliseconds: 150), () {
      _updateMarkerSize();
    });
  }

  /// Regenerates the icon for the current zoom and refreshes the marker.
  Future<void> _updateMarkerSize() async {
    if (_currentPosition == null) return;
    final scale = _currentZoom / _baseZoom;
    await _createMyLocationIcon(scale: scale);
    _addOrUpdateMyLocationMarker(_currentPosition!);
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() {
        _isLoading = false;
        _currentPosition = null;
      });
      _fetchPlaces();
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _isLoading = false;
      });

      _addOrUpdateMyLocationMarker(_currentPosition!);

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 14),
        ),
      );
      _fetchPlaces();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _currentPosition = null;
      });
      _fetchPlaces();
    }
  }

  Future<void> _fetchPlaces() async {
    try {
      final response = await supabase.from('places').select();
      final List<Map<String, dynamic>> places =
      List<Map<String, dynamic>>.from(response);

      final newMarkers = <Marker>{};

      for (final place in places) {
        final lat = place['latitude'] as double?;
        final lng = place['longitude'] as double?;
        if (lat == null || lng == null) continue;

        final marker = Marker(
          markerId: MarkerId(place['id'].toString()),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: place['name'] ?? 'Place',
            snippet: place['category'] ?? 'Attraction',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
        newMarkers.add(marker);
      }

      setState(() {
        _markers.addAll(newMarkers);
      });
    } catch (e) {
      debugPrint('Error loading places: $e');
    }
  }

  Future<Map<String, dynamic>> _callPlacesProxy(Map<String, dynamic> body) async {
    final res = await supabase.functions.invoke(
      'places-proxy',
      body: body,
    );
    return res.data as Map<String, dynamic>;
  }

  Future<void> _searchPlace(String query) async {
    if (query.isEmpty) return;
    setState(() => _isSearching = true);

    try {
      final autocompleteData = await _callPlacesProxy({
        'type': 'autocomplete',
        'input': query,
      });

      if (autocompleteData['status'] != 'OK' ||
          (autocompleteData['predictions'] as List).isEmpty) {
        setState(() => _isSearching = false);
        return;
      }

      final placeId = autocompleteData['predictions'][0]['place_id'] as String;

      final detailsData = await _callPlacesProxy({
        'type': 'details',
        'place_id': placeId,
      });

      if (detailsData['status'] != 'OK') {
        setState(() => _isSearching = false);
        return;
      }

      final location = detailsData['result']['geometry']['location'];
      final double lat = location['lat'];
      final double lng = location['lng'];
      final String name = detailsData['result']['name'] ?? 'Searched Place';

      final tempMarker = Marker(
        markerId: const MarkerId('search_result'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      );

      setState(() {
        _markers.removeWhere((m) => m.markerId == const MarkerId('search_result'));
        _markers.add(tempMarker);
        _isSearching = false;
      });

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 16),
        ),
      );

      _searchController.clear();
    } catch (e) {
      debugPrint('Search error: $e');
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Search failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _goToCurrentLocation() async {
    if (_currentPosition != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition!, zoom: 15),
        ),
      );
    } else {
      await _getCurrentLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Map'),
        backgroundColor: MyApp.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _goToCurrentLocation,
            tooltip: 'My Location',
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (_currentPosition != null) {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _currentPosition!, zoom: 14),
                  ),
                );
              } else {
                _mapController?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    const CameraPosition(target: _defaultLocation, zoom: 12),
                  ),
                );
              }
            },
            initialCameraPosition: const CameraPosition(
              target: _defaultLocation,
              zoom: 12,
            ),
            markers: _markers,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            mapType: MapType.normal,
            onTap: (_) => FocusScope.of(context).unfocus(),
            onCameraMove: _onCameraMove,   // <-- added for zoom-resizing
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),

          // "My Location" FAB moved to bottom LEFT
          Positioned(
            bottom: 24,
            left: 16,                       // <-- changed from right: 16
            child: FloatingActionButton(
              mini: true,
              backgroundColor: Colors.white,
              onPressed: _goToCurrentLocation,
              tooltip: 'My Location',
              child: const Icon(Icons.my_location, color: Color(0xFF4285F4)),
            ),
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search places...',
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          icon: Icon(Icons.search, color: MyApp.primaryColor),
                        ),
                        onSubmitted: _searchPlace,
                      ),
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.only(right: 16),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: MyApp.primaryColor,
                        ),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        FocusScope.of(context).unfocus();
                        setState(() {
                          _markers.removeWhere(
                                (m) => m.markerId == const MarkerId('search_result'),
                          );
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}