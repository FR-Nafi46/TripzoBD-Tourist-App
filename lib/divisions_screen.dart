import 'package:flutter/material.dart';
import 'main.dart';
import 'division_places_screen.dart';
import 'constants.dart';

class DivisionsScreen extends StatelessWidget {
  const DivisionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Divisions of Bangladesh')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 2 per row
            childAspectRatio: 1.2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
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
              child: Card(
                color: MyApp.primaryColor.withOpacity(0.85),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Center(
                  child: Text(
                    division,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}