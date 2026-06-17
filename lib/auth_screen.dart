import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart';
import 'home_screen.dart';
import 'guide_home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // View toggles
  bool _isTouristLoginView = true;
  bool _isGuideLoginView = true;

  // Password visibility
  bool _obscureTouristLoginPassword = true;
  bool _obscureTouristSignupPassword = true;
  bool _obscureGuideLoginPassword = true;
  bool _obscureGuideSignupPassword = true;

  // Tourist controllers
  final _touristNameController = TextEditingController();
  final _touristEmailController = TextEditingController();
  final _touristPasswordController = TextEditingController();

  // Guide controllers
  final _guideNameController = TextEditingController();
  final _guideEmailController = TextEditingController();
  final _guidePasswordController = TextEditingController();
  final _guideDivisionController = TextEditingController();
  // Language controller removed
  final _guidePricePerDayController = TextEditingController();
  final _guideBioController = TextEditingController();

  bool _loadingTouristLogin = false;
  bool _loadingTouristSignup = false;
  bool _loadingGuideLogin = false;
  bool _loadingGuideSignup = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _touristNameController.dispose();
    _touristEmailController.dispose();
    _touristPasswordController.dispose();
    _guideNameController.dispose();
    _guideEmailController.dispose();
    _guidePasswordController.dispose();
    _guideDivisionController.dispose();
    _guidePricePerDayController.dispose();
    _guideBioController.dispose();
    super.dispose();
  }

  Future<void> _handleLoginFailure(String email) async {
    try {
      final accountCheck = await supabase
          .from('profiles')
          .select('id')
          .eq('full_name', _tabController.index == 0 ? _touristNameController.text.trim() : _guideNameController.text.trim())
          .maybeSingle();
      if (accountCheck == null) {
        _showError("This email account does not have an account registered. Please sign up first.");
      } else {
        _showError("Incorrect password. Please verify your typing and try again.");
      }
    } catch (_) {
      _showError("Invalid login credentials. Please check your email and password.");
    }
  }

  // ---------- Tourist Methods ----------
  Future<void> _touristLogin() async {
    final email = _touristEmailController.text.trim();
    final password = _touristPasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password required');
      return;
    }
    setState(() => _loadingTouristLogin = true);
    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) throw Exception('Login failed');

      final profile = await supabase
          .from('profiles')
          .select('role, is_approved')
          .eq('id', res.user!.id)
          .maybeSingle();

      if (profile != null && profile['role'] == 'tour_guide') {
        await supabase.auth.signOut();
        _showError('This account is a Tour Guide. Please use the Tour Guide tab.');
        setState(() => _loadingTouristLogin = false);
        return;
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials') || e.code == 'invalid_credentials') {
        await _handleLoginFailure(email);
      } else {
        _showError('Login error: ${e.message}');
      }
    } catch (e) {
      _showError('Login error: $e');
    } finally {
      if (mounted) setState(() => _loadingTouristLogin = false);
    }
  }

  Future<void> _resendConfirmation(String email) async {
    try {
      await supabase.auth.resend(email: email, type: OtpType.signup);
      _showMessage('Confirmation email resent to $email');
    } catch (e) {
      _showError('Failed to resend: $e');
    }
  }

  Future<void> _sendPasswordReset(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(email);
      _showMessage('Password reset link sent to $email');
    } catch (e) {
      _showError('Failed to send reset link: $e');
    }
  }

  Future<void> _touristSignup() async {
    final name = _touristNameController.text.trim();
    final email = _touristEmailController.text.trim();
    final password = _touristPasswordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      _showError('All fields are required');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (!email.contains('@')) {
      _showError('Enter a valid email address');
      return;
    }

    setState(() => _loadingTouristSignup = true);
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('full_name', name)
          .maybeSingle();
      if (existing != null) {
        _showError('Name already taken');
        setState(() => _loadingTouristSignup = false);
        return;
      }

      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'role': 'user'},
      );
      if (res.user == null) throw Exception('Sign up failed');
      if (res.session == null) {
        _showMessage('Account created! Please check your email to confirm.');
        _clearTouristFields();
        setState(() => _isTouristLoginView = true);
      } else {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
        }
      }
    } catch (e) {
      _showError('Sign up error: $e');
    } finally {
      if (mounted) setState(() => _loadingTouristSignup = false);
    }
  }

  // ---------- Guide Methods ----------
  Future<void> _guideLogin() async {
    final email = _guideEmailController.text.trim();
    final password = _guidePasswordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showError('Email and password required');
      return;
    }
    setState(() => _loadingGuideLogin = true);
    try {
      final res = await supabase.auth.signInWithPassword(email: email, password: password);
      if (res.user == null) throw Exception('Login failed');

      final profile = await supabase
          .from('profiles')
          .select('role, is_approved')
          .eq('id', res.user!.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'tour_guide') {
        await supabase.auth.signOut();
        _showError('This account is not a Tour Guide. Please use the Tourist tab.');
        setState(() => _loadingGuideLogin = false);
        return;
      }
      if (profile['is_approved'] == false) {
        await supabase.auth.signOut();
        _showError('Your tour guide account is pending admin approval.');
        setState(() => _loadingGuideLogin = false);
        return;
      }
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const GuideHomeScreen()));
      }
    } on AuthException catch (e) {
      if (e.message.contains('Invalid login credentials') || e.code == 'invalid_credentials') {
        await _handleLoginFailure(email);
      } else {
        _showError('Login error: ${e.message}');
      }
    } catch (e) {
      _showError('Login error: $e');
    } finally {
      if (mounted) setState(() => _loadingGuideLogin = false);
    }
  }

  Future<void> _guideSignup() async {
    final name = _guideNameController.text.trim();
    final email = _guideEmailController.text.trim();
    final password = _guidePasswordController.text.trim();
    final division = _guideDivisionController.text.trim();
    final priceStr = _guidePricePerDayController.text.trim();
    final bio = _guideBioController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || division.isEmpty || priceStr.isEmpty) {
      _showError('Please fill all required fields (*)');
      return;
    }
    if (password.length < 6) {
      _showError('Password must be at least 6 characters');
      return;
    }
    if (!email.contains('@')) {
      _showError('Enter a valid email address');
      return;
    }
    final price = double.tryParse(priceStr);
    if (price == null || price <= 0) {
      _showError('Price per day must be a positive number');
      return;
    }

    setState(() => _loadingGuideSignup = true);
    try {
      final existing = await supabase
          .from('profiles')
          .select('id')
          .eq('full_name', name)
          .maybeSingle();
      if (existing != null) {
        _showError('Name already taken');
        setState(() => _loadingGuideSignup = false);
        return;
      }

      // Language field removed from signup data
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': 'tour_guide',
          'guide_division': division,
          'price_per_day': price,
          'bio': bio,
          'is_approved': false,
          // languages not sent – will default to empty array in DB
        },
      );
      if (res.user == null) throw Exception('Sign up failed');
      if (res.session == null) {
        _showMessage('Account created! Please check your email to confirm.');
        _clearGuideFields();
        setState(() => _isGuideLoginView = true);
      } else {
        await supabase.auth.signOut();
        _showMessage('Registration successful! Please wait for admin approval.');
        _clearGuideFields();
        setState(() => _isGuideLoginView = true);
      }
    } catch (e) {
      _showError('Sign up error: $e');
    } finally {
      if (mounted) setState(() => _loadingGuideSignup = false);
    }
  }

  void _clearTouristFields() {
    _touristNameController.clear();
    _touristEmailController.clear();
    _touristPasswordController.clear();
  }

  void _clearGuideFields() {
    _guideNameController.clear();
    _guideEmailController.clear();
    _guidePasswordController.clear();
    _guideDivisionController.clear();
    _guidePricePerDayController.clear();
    _guideBioController.clear();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.teal.shade700));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8EB69B),
      body: SafeArea(
        child: Column(
          children: [
            // Top branding (unchanged)
            Container(
              padding: const EdgeInsets.only(top: 20, bottom: 15),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Image.asset('assets/company/BDTSlogo.png', height: 150, width: 150, fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Bangladesh Tourist Guide',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
            // Tab Bar (unchanged)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(32)),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(borderRadius: BorderRadius.circular(32), color: Colors.white),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: const Color(0xFF8EB69B),
                unselectedLabelColor: Colors.white,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                tabs: const [Tab(text: 'Tourist'), Tab(text: 'Tour Guide')],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildTouristCard()),
                  SingleChildScrollView(padding: const EdgeInsets.all(24), child: _buildGuideCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTouristCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isTouristLoginView ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tourist Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 20),
              TextField(
                controller: _touristEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _touristPasswordController,
                obscureText: _obscureTouristLoginPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureTouristLoginPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscureTouristLoginPassword = !_obscureTouristLoginPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loadingTouristLogin ? null : _touristLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8EB69B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loadingTouristLogin ? const CircularProgressIndicator(color: Colors.white) : const Text('Login as Tourist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: TextButton(onPressed: () => setState(() => _isTouristLoginView = false), child: const Text("Don't have an account? Sign Up", style: TextStyle(color: Color(0xFF8EB69B), fontWeight: FontWeight.w600)))),
            ],
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tourist Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 20),
              TextField(controller: _touristNameController, decoration: InputDecoration(labelText: 'Full Name', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _touristEmailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(
                controller: _touristPasswordController,
                obscureText: _obscureTouristSignupPassword,
                decoration: InputDecoration(
                  labelText: 'Password (min 6)',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureTouristSignupPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscureTouristSignupPassword = !_obscureTouristSignupPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loadingTouristSignup ? null : _touristSignup,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8EB69B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loadingTouristSignup ? const CircularProgressIndicator(color: Colors.white) : const Text('Register as Tourist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: TextButton(onPressed: () => setState(() => _isTouristLoginView = true), child: const Text("Already have an account? Login", style: TextStyle(color: Color(0xFF8EB69B), fontWeight: FontWeight.w600)))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isGuideLoginView ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Guide Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 20),
              TextField(controller: _guideEmailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(
                controller: _guidePasswordController,
                obscureText: _obscureGuideLoginPassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureGuideLoginPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscureGuideLoginPassword = !_obscureGuideLoginPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loadingGuideLogin ? null : _guideLogin,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8EB69B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loadingGuideLogin ? const CircularProgressIndicator(color: Colors.white) : const Text('Login as Guide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: TextButton(onPressed: () => setState(() => _isGuideLoginView = false), child: const Text("New Guide? Join Us here", style: TextStyle(color: Color(0xFF8EB69B), fontWeight: FontWeight.w600)))),
            ],
          ),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Guide Registration', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 20),
              TextField(controller: _guideNameController, decoration: InputDecoration(labelText: 'Full Name *', prefixIcon: const Icon(Icons.person_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _guideEmailController, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: 'Email *', prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(
                controller: _guidePasswordController,
                obscureText: _obscureGuideSignupPassword,
                decoration: InputDecoration(
                  labelText: 'Password (min 6) *',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureGuideSignupPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                    onPressed: () => setState(() => _obscureGuideSignupPassword = !_obscureGuideSignupPassword),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(controller: _guideDivisionController, decoration: InputDecoration(labelText: 'Operating Division *', prefixIcon: const Icon(Icons.location_on_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              // Language field removed here
              const SizedBox(height: 16),
              TextField(controller: _guidePricePerDayController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Price per Day (BDT) *', prefixIcon: const Icon(Icons.payments_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 16),
              TextField(controller: _guideBioController, maxLines: 3, decoration: InputDecoration(labelText: 'Bio / Experience Narrative', prefixIcon: const Icon(Icons.info_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loadingGuideSignup ? null : _guideSignup,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8EB69B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _loadingGuideSignup ? const CircularProgressIndicator(color: Colors.white) : const Text('Register as Guide', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: TextButton(onPressed: () => setState(() => _isGuideLoginView = true), child: const Text("Already have an account? Login", style: TextStyle(color: Color(0xFF8EB69B), fontWeight: FontWeight.w600)))),
            ],
          ),
        ),
      ),
    );
  }
}