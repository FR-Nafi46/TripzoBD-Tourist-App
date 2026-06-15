import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'constants.dart';
import 'divisions_screen.dart';
import 'map_screen.dart';
import 'sos_screen.dart';
import 'language_screen.dart';
import 'currency_converter_screen.dart';
import 'hotel_booking_screen.dart';
import 'transport_booking_screen.dart';
import 'tour_guide_booking_screen.dart';
import 'payment_screen.dart';
import 'booking_history_screen.dart';
import 'profile_screen.dart';
import 'admin_dashboard_screen.dart';
import 'main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = const [
    _HomeContent(),
    DivisionsScreen(),
    MapScreen(),
    SosScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bangladesh Tourist App')),
      drawer: _buildDrawer(),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: MyApp.primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Divisions'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(icon: Icon(Icons.sos), label: 'SOS'),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return Drawer(
        child: ListView(
          children: const [
            DrawerHeader(child: Text('Please log in')),
            ListTile(title: Text('Login')),
          ],
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: supabase
          .from('profiles')
          .select('role, is_approved, full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Drawer(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        bool isAdmin = false;
        bool isApprovedGuide = false;
        String fullName = 'Tourist App';
        String? avatarUrl;

        if (snapshot.hasError || snapshot.data == null) {
          _ensureProfileExists(user.id);
        } else {
          final data = snapshot.data!;
          final role = data['role'] ?? 'user';
          final isApproved = data['is_approved'] ?? false;
          isAdmin = (role == 'admin');
          isApprovedGuide = (role == 'tour_guide' && isApproved);
          fullName = data['full_name'] ?? 'Tourist App';

          final rawAvatarUrl = data['avatar_url'];
          avatarUrl = (rawAvatarUrl != null && rawAvatarUrl.toString().isNotEmpty) ? rawAvatarUrl : null;
        }

        return _buildDrawerContent(
          isAdmin: isAdmin,
          isApprovedGuide: isApprovedGuide,
          fullName: fullName,
          avatarUrl: avatarUrl,
        );
      },
    );
  }

  Future<void> _ensureProfileExists(String userId) async {
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      if (existing == null) {
        await supabase.from('profiles').insert({
          'id': userId,
          'full_name': 'User',
          'role': 'user',
        });
      }
    } catch (e) {
      print('Profile creation error: $e');
    }
  }

  Widget _buildDrawerContent({
    required bool isAdmin,
    required bool isApprovedGuide,
    required String fullName,
    String? avatarUrl,
  }) {
    return Drawer(
      backgroundColor: const Color(0xFF033E2B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              margin: EdgeInsets.zero,
              padding: EdgeInsets.zero,
              decoration: const BoxDecoration(
                color: Color(0xFF033E2B),
                borderRadius: BorderRadius.only(topRight: Radius.circular(24)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: MountainSceneryPainter())),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null
                                  ? const Icon(Icons.account_circle, size: 55, color: Color(0xFF033E2B))
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            fullName,
                            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _drawerItem(context, 'Home', Icons.home, () => setState(() => _currentIndex = 0)),
            _drawerItem(context, 'Divisions', Icons.map, () => setState(() => _currentIndex = 1)),
            _drawerItem(context, 'Language Translation', Icons.translate, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LanguageScreen()))),
            _drawerItem(context, 'Currency Converter', Icons.attach_money, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()))),
            const Divider(),
            _drawerItem(context, 'Hotel Booking', Icons.hotel, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HotelBookingScreen()))),
            _drawerItem(context, 'Transport Booking', Icons.directions_bus, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TransportBookingScreen()))),
            _drawerItem(context, 'Tour Guide Booking', Icons.person_pin, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TourGuideBookingScreen()))),
            _drawerItem(context, 'Booking History', Icons.history, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BookingHistoryScreen()))),
            _drawerItem(context, 'Payment', Icons.payment, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentScreen()))),
            const Divider(),
            _drawerItem(context, 'Profile', Icons.person, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()))),

            if (isAdmin)
              _drawerItem(context, 'Admin Dashboard', Icons.dashboard, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()))),

            if (isApprovedGuide)
              _drawerItem(context, 'My Guide Dashboard', Icons.work, () => _showComingSoon(context)),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF033E2B)),
      title: Text(title),
      onTap: onTap,
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Guide dashboard coming soon!')),
    );
  }
}

class MountainSceneryPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    final backgroundHillPaint = Paint()..color = const Color(0xFF8EB69B).withOpacity(0.5);
    final foregroundHillPaint = Paint()..color = const Color(0xFF8EB69B);
    final pineTreePaint = Paint()..color = const Color(0xFF022E20);
    final riverPaint = Paint()..color = const Color(0xFF8EB69B).withOpacity(0.3);
    final birdPaint = Paint()
      ..color = const Color(0xFF8EB69B).withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final backHillPath = Path()
      ..moveTo(width * 0.35, height)
      ..lineTo(width * 0.62, height * 0.43)
      ..lineTo(width * 0.78, height * 0.68)
      ..lineTo(width * 0.93, height * 0.52)
      ..lineTo(width, height * 0.62)
      ..lineTo(width, height)
      ..close();
    canvas.drawPath(backHillPath, backgroundHillPaint);

    final foreHillPath = Path()
      ..moveTo(width * 0.45, height)
      ..lineTo(width * 0.75, height * 0.45)
      ..lineTo(width * 0.88, height * 0.72)
      ..lineTo(width, height * 0.58)
      ..lineTo(width, height)
      ..close();
    canvas.drawPath(foreHillPath, foregroundHillPaint);

    final riverPath = Path()
      ..moveTo(width * 0.75, height * 0.85)
      ..quadraticBezierTo(width * 0.72, height * 0.88, width * 0.76, height * 0.92)
      ..quadraticBezierTo(width * 0.82, height * 0.95, width * 0.70, height)
      ..lineTo(width, height)
      ..lineTo(width * 0.85, height * 0.85)
      ..close();
    canvas.drawPath(riverPath, riverPaint);

    void drawBird(double cx, double cy, double birdSize) {
      final birdPath = Path()
        ..moveTo(cx - birdSize, cy)
        ..quadraticBezierTo(cx - (birdSize / 2), cy - (birdSize * 0.6), cx, cy - (birdSize * 0.1))
        ..quadraticBezierTo(cx + (birdSize / 2), cy - (birdSize * 0.6), cx + birdSize, cy);
      canvas.drawPath(birdPath, birdPaint);
    }
    drawBird(width * 0.62, height * 0.28, 8);
    drawBird(width * 0.78, height * 0.22, 11);
    drawBird(width * 0.86, height * 0.32, 7);

    void drawTree(double cx, double bottomY, double baseWidth, double treeHeight) {
      final treePath = Path()
        ..moveTo(cx, bottomY - treeHeight)
        ..lineTo(cx - baseWidth / 2, bottomY)
        ..lineTo(cx + baseWidth / 2, bottomY)
        ..close();
      canvas.drawPath(treePath, pineTreePaint);
    }
    drawTree(width * 0.58, height * 0.82, 16, 28);
    drawTree(width * 0.64, height * 0.84, 14, 24);
    drawTree(width * 0.69, height * 0.85, 11, 19);
    drawTree(width * 0.83, height * 0.85, 18, 32);
    drawTree(width * 0.89, height * 0.86, 14, 25);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _attractions = [
    {'title': 'Sundarbans', 'subtitle': 'Largest mangrove forest', 'image': 'assets/images/sundarbans.jpg'},
    {'title': 'Cox’s Bazar', 'subtitle': 'Longest sea beach', 'image': 'assets/images/cox_bazar.jpg'},
    {'title': 'Sylhet Tea Gardens', 'subtitle': 'Lush green plantations', 'image': 'assets/images/tea_garden.jpg'},
    {'title': 'Sajek Valley', 'subtitle': 'Hilltop scenic beauty', 'image': 'assets/images/sajek.jpg'},
    {'title': 'Saint Martin Island', 'subtitle': 'Coral island paradise', 'image': 'assets/images/saint_martin.jpg'},
  ];

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), _autoScroll);
  }

  void _autoScroll() {
    if (!mounted) return;
    int nextPage = (_currentPage + 1) % _attractions.length;
    _pageController.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Top Attractions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _attractions.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              Future.delayed(const Duration(seconds: 3), _autoScroll);
            },
            itemBuilder: (context, index) => _buildAttractionCard(_attractions[index]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _attractions.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index ? const Color(0xFF033E2B) : Colors.grey,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAttractionCard(Map<String, String> attraction) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(attraction['image']!, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attraction['title']!,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    attraction['subtitle']!,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
