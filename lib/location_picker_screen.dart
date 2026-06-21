import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';

class LocationResult {
  final LatLng location;
  final String? address;

  LocationResult({required this.location, this.address});
}

class LocationPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const LocationPickerScreen({super.key, this.initialLocation});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedLocation = const LatLng(23.8103, 90.4125); // default Dhaka
  String? _address;
  bool _isLoading = true;
  bool _isGeocoding = false;
  bool _hasPermission = false;

  static const Color primaryColor = Color(0xFF0B2B26);
  static const Color secondaryColor = Color(0xFF8EB69B);

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selectedLocation = widget.initialLocation!;
      _isLoading = false;
      _checkLocationPermission();
      _getAddress(_selectedLocation);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (!mounted) return;
    setState(() {
      _hasPermission = status.isGranted;
    });
  }

  Future<void> _getCurrentLocation() async {
    final status = await Permission.location.request();
    if (status.isDenied || status.isPermanentlyDenied) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        final newLocation = LatLng(position.latitude, position.longitude);
        setState(() {
          _selectedLocation = newLocation;
          _isLoading = false;
          _hasPermission = true;
        });
        _moveCamera(newLocation);
        _getAddress(newLocation);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasPermission = false;
        });
      }
    }
  }

  Future<void> _getAddress(LatLng location) async {
    setState(() => _isGeocoding = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _address = "${place.name}, ${place.subLocality}, ${place.locality}";
          // Remove leading commas if any parts are empty
          _address = _address?.replaceAll(RegExp(r'^, |, $'), '').replaceAll(RegExp(r', , '), ', ');
        });
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
      setState(() => _address = "Unknown location");
    } finally {
      setState(() => _isGeocoding = false);
    }
  }

  void _moveCamera(LatLng target) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 15),
      ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_isLoading) {
      _moveCamera(_selectedLocation);
    }
  }

  void _onTap(LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
    _getAddress(point);
  }

  void _confirmLocation() {
    Navigator.pop(context, LocationResult(location: _selectedLocation, address: _address));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Select Location'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _confirmLocation,
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (!_hasPermission && widget.initialLocation == null)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Location permission denied.\nPlease enable location services.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _getCurrentLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation,
                zoom: 14,
              ),
              onTap: _onTap,
              markers: {
                Marker(
                  markerId: const MarkerId('selected_location'),
                  position: _selectedLocation,
                  draggable: true,
                  onDragEnd: (newPos) {
                    setState(() {
                      _selectedLocation = newPos;
                    });
                    _getAddress(newPos);
                  },
                ),
              },
              myLocationEnabled: _hasPermission,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              compassEnabled: true,
            ),
          if (!_isLoading)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: primaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _isGeocoding
                              ? const LinearProgressIndicator()
                              : Text(
                            _address ?? 'Tapping map to get address...',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.pin_drop, color: Colors.grey, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lat: ${_selectedLocation.latitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              Text(
                                'Lng: ${_selectedLocation.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: _confirmLocation,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: secondaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Confirm'),
                        ),
                      ],
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
