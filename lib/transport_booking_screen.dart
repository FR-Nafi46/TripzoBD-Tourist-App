import 'package:flutter/material.dart';

class TransportBookingScreen extends StatelessWidget {
  const TransportBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Booking')),
      body: const Center(child: Text('Transport booking will be implemented with database.')),
    );
  }
}