import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'constants.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  void _dialNumber(String number) async {
    final Uri uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $uri';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 80,
              child: ElevatedButton.icon(
                onPressed: () => _dialNumber('999'),
                icon: const Icon(Icons.phone, size: 32),
                label: const Text('SOS EMERGENCY CALL', style: TextStyle(fontSize: 22)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Emergency Contacts', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: emergencyContacts.entries.map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.contact_phone),
                    title: Text(entry.key),
                    subtitle: Text(entry.value),
                    trailing: IconButton(
                      icon: const Icon(Icons.call, color: Colors.green),
                      onPressed: () => _dialNumber(entry.value),
                    ),
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.local_hospital, color: Colors.red),
              title: const Text('Nearby Hospitals'),
              subtitle: const Text('Feature will be available after map integration'),
              onTap: () {
                // TODO: implement nearby hospital locator
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Nearby hospital finder coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}