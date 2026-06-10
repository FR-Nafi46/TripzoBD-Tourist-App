import 'package:flutter/material.dart';

class HotelBookingScreen extends StatelessWidget {
  const HotelBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hotel Booking')),
      body: const Center(child: Text('Hotel booking will be implemented with database.')),
    );
  }
}