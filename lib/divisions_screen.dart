import 'package:flutter/material.dart';
import 'division_places_screen.dart';
import 'constants.dart';

class DivisionsScreen extends StatelessWidget {
  const DivisionsScreen({super.key});

  // Map division to an appropriate icon
  IconData _getDivisionIcon(String division) {
    switch (division) {
      case 'Dhaka':
        return Icons.location_city;
      case 'Chattogram':
        return Icons.terrain;
      case 'Rajshahi':
        return Icons.landscape;
      case 'Khulna':
        return Icons.forest;
      case 'Barishal':
        return Icons.water;
      case 'Sylhet':
        return Icons.grass;
      case 'Rangpur':
        return Icons.agriculture;
      case 'Mymensingh':
        return Icons.nature_people;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Divisions of Bangladesh')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.0,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemCount: divisions.length,
          itemBuilder: (context, index) {
            final division = divisions[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DivisionPlacesScreen(divisionName: division),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: const [
                      Color(0xFF8EB69B), // soft sage
                      Color(0xFF6B9C7A), // deeper green
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getDivisionIcon(division),
                      size: 42,
                      color: const Color(0xFF0B2B26).withOpacity(0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      division,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0B2B26),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}