import 'package:flutter/material.dart';

class DivisionPlacesScreen extends StatelessWidget {
  final String divisionName;
  const DivisionPlacesScreen({super.key, required this.divisionName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('$divisionName Places')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 60, color: Colors.grey),
              SizedBox(height: 20),
              Text(
                'Tourist places will be displayed here after database integration.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}