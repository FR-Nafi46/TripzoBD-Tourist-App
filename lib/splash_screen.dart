import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'home_screen.dart';
import 'auth_screen.dart';
import 'guide_home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait at least 2 seconds for splash visibility
    await Future.delayed(const Duration(seconds: 2));

    final session = supabase.auth.currentSession;
    if (session == null) {
      _navigateTo(const AuthScreen());
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('role, is_approved')
          .eq('id', session.user.id)
          .maybeSingle();

      if (profile == null) {
        // Profile missing – fallback to AuthScreen (should not happen normally)
        _navigateTo(const AuthScreen());
        return;
      }

      final role = profile['role'] as String?;
      final isApproved = profile['is_approved'] as bool? ?? false;

      if (role == 'tour_guide' && isApproved) {
        _navigateTo(const GuideHomeScreen());
      } else {
        // Tourist, admin, or unapproved guide – go to regular HomeScreen
        _navigateTo(const HomeScreen());
      }
    } catch (e) {
      // On error, go to AuthScreen as safe fallback
      debugPrint('Splash error: $e');
      _navigateTo(const AuthScreen());
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EB69B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 170,
              height: 170,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/company/BDTSlogo.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Supporting your journey,\nevery step of the way',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}