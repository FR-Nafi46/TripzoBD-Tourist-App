import 'package:flutter/material.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Map')),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 60, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Google Maps will be integrated here using API.',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}