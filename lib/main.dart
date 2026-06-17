import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://celldfiaorxajhqsxlgg.supabase.co',
    anonKey: 'sb_publishable_OvWZrsH1VOPIr8AQ_8fuxQ__Q3TGLiW',
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // New color scheme
  static const Color primaryColor = Color(0xFF0B2B26);     // Dark Teal
  static const Color secondaryColor = Color(0xFF8EB69B);   // Soft Sage Green
  static const Color scaffoldBackground = Color(0xFFF2F0FA); // White Lilac

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangladesh Tourist App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: scaffoldBackground,
        colorScheme: const ColorScheme.light(
          primary: primaryColor,
          secondary: secondaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: scaffoldBackground,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black87),
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}