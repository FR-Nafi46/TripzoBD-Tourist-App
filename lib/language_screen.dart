import 'package:flutter/material.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLanguage = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Language Translation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedLanguage,
              decoration: const InputDecoration(
                labelText: 'Select Language',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'English', child: Text('English')),
                DropdownMenuItem(value: 'Bangla', child: Text('Bangla')),
                DropdownMenuItem(value: 'Arabic', child: Text('Arabic')),
                DropdownMenuItem(value: 'French', child: Text('French')),
              ],
              onChanged: (value) {
                setState(() => _selectedLanguage = value ?? 'English');
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // TODO: Integrate translation API later
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Translation feature coming soon')),
                );
              },
              child: const Text('Translate'),
            ),
          ],
        ),
      ),
    );
  }
}