import 'package:flutter/material.dart';
import 'constants.dart';               // <-- use constants, not main.dart
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
      appBar: AppBar(
        title: const Text('Bangladesh Tourist App'),
      ),
      drawer: _buildDrawer(context),
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: primaryMaroon,
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

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: primaryMaroon),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.account_circle, size: 50, color: Colors.white),
                SizedBox(height: 8),
                Text('Tourist App',
                    style: TextStyle(color: Colors.white, fontSize: 18)),
              ],
            ),
          ),
          _drawerItem(context, 'Home', Icons.home, () {
            Navigator.pop(context);
            setState(() => _currentIndex = 0);
          }),
          _drawerItem(context, 'Divisions', Icons.map, () {
            Navigator.pop(context);
            setState(() => _currentIndex = 1);
          }),
          _drawerItem(context, 'Language Translation', Icons.translate, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const LanguageScreen()));
          }),
          _drawerItem(context, 'Currency Converter', Icons.attach_money, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const CurrencyConverterScreen()));
          }),
          const Divider(),
          _drawerItem(context, 'Hotel Booking', Icons.hotel, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const HotelBookingScreen()));
          }),
          _drawerItem(context, 'Transport Booking', Icons.directions_bus, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TransportBookingScreen()));
          }),
          _drawerItem(context, 'Tour Guide Booking', Icons.person_pin, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const TourGuideBookingScreen()));
          }),
          _drawerItem(context, 'Booking History', Icons.history, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const BookingHistoryScreen()));
          }),
          _drawerItem(context, 'Payment', Icons.payment, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PaymentScreen()));
          }),
          const Divider(),
          _drawerItem(context, 'Profile', Icons.person, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()));
          }),
          _drawerItem(context, 'Admin Dashboard', Icons.dashboard, () {
            Navigator.pop(context);
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
          }),
        ],
      ),
    );
  }

  Widget _drawerItem(
      BuildContext context, String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: primaryMaroon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

// ------------------------------------------------
// Home content with image carousel
// ------------------------------------------------
class _HomeContent extends StatefulWidget {
  const _HomeContent();

  @override
  State<_HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<_HomeContent> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Top attractions with local image assets
  final List<Map<String, String>> _attractions = [
    {
      'title': 'Sundarbans',
      'subtitle': 'Largest mangrove forest',
      'image': 'assets/images/sundarbans.jpg',
    },
    {
      'title': 'Cox’s Bazar',
      'subtitle': 'Longest sea beach',
      'image': 'assets/images/cox_bazar.jpg',
    },
    {
      'title': 'Sylhet Tea Gardens',
      'subtitle': 'Lush green plantations',
      'image': 'assets/images/tea_garden.jpg',
    },
    {
      'title': 'Sajek Valley',
      'subtitle': 'Hilltop scenic beauty',
      'image': 'assets/images/sajek.jpg',
    },
    {
      'title': 'Saint Martin Island',
      'subtitle': 'Coral island paradise',
      'image': 'assets/images/saint_martin.jpg',
    },
  ];

  @override
  void initState() {
    super.initState();
    // Start auto‑scroll after 3 seconds
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
          child: Text(
            'Top Attractions',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _attractions.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              // Schedule next scroll
              Future.delayed(const Duration(seconds: 3), _autoScroll);
            },
            itemBuilder: (context, index) {
              return _buildAttractionCard(_attractions[index]);
            },
          ),
        ),
        // Dot indicators
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
                  color: _currentPage == index
                      ? primaryMaroon
                      : Colors.grey,
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,   // clip image to rounded corners
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Local image
          Image.asset(
            attraction['image']!,
            fit: BoxFit.cover,
          ),
          // Dark overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          // Text on top of the image
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.place, size: 50, color: Colors.white),
              const SizedBox(height: 16),
              Text(
                attraction['title']!,
                style: const TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                attraction['subtitle']!,
                style: const TextStyle(fontSize: 16, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}