import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/notification_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  static const _teal = Color(0xFF4EC8C8);
  static const _softTop = Color(0xFFF8F3FF);
  static const _softBottom = Color(0xFFEEF6FF);

  final PageController _pageController = PageController();
  int _currentPage = 0;
  String? _selectedPersona;
  final Set<String> _selectedInterests = {};
  late AnimationController _breathingController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _breathingController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_currentPage >= 4) return;
    await _pageController.animateToPage(
      _currentPage + 1,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _savePersona(String value) async {
    await HapticFeedback.lightImpact();
    setState(() => _selectedPersona = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_persona', value);
  }

  Future<void> _toggleInterest(String value) async {
    await HapticFeedback.lightImpact();
    setState(() {
      if (_selectedInterests.contains(value)) {
        _selectedInterests.remove(value);
      } else {
        _selectedInterests.add(value);
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_interests', jsonEncode(_selectedInterests.toList()));
  }

  Future<void> _completeOnboarding({required bool enableNotifications}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    await prefs.setBool('notifications_enabled', enableNotifications);
    if (enableNotifications) {
      await NotificationService().initialize();
      await NotificationService().scheduleDailyRemindersIfEnabled();
    }
    if (!mounted) return;
    context.go('/signup');
  }

  Future<void> _skipOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    context.go('/signup');
  }

  SystemUiOverlayStyle _overlayForPage() {
    if (_currentPage == 0) {
      return const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      );
    }
    return const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    );
  }

  Widget _animatedPageShell({required Widget child}) {
    return TweenAnimationBuilder<double>(
      key: ValueKey<int>(_currentPage),
      tween: Tween<double>(begin: 0.94, end: 1.0),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Opacity(
          opacity: value.clamp(0, 1),
          child: Transform.scale(scale: value, child: child),
        );
      },
    );
  }

  Widget _buildTopSkip() {
    if (_currentPage == 4) return const SizedBox(height: 44);
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, right: 12),
          child: TextButton(
            onPressed: _skipOnboarding,
            child: Text(
              'Skip',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: _currentPage == 0 ? Colors.white : Colors.grey[700],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    if (_currentPage == 0) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
        child: Row(
          children: [
            TextButton(
              onPressed: _skipOnboarding,
              child: Text(
                'Skip',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final active = index == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 18 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? _teal : Colors.grey[350],
                      borderRadius: BorderRadius.circular(99),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 64),
          ],
        ),
      ),
    );
  }

  Widget _personaCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required String value,
  }) {
    final selected = _selectedPersona == value;
    return GestureDetector(
      onTap: () => _savePersona(value),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        scale: selected ? 1.02 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _teal : Colors.transparent,
              width: selected ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF2D2D3A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page1() {
    final breathing = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF4EC8C8), Color(0xFF8F7BFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          child: Column(
            children: [
              _buildTopSkip(),
              const Spacer(),
              ScaleTransition(
                scale: breathing,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.38),
                        blurRadius: 38,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.psychology, size: 80, color: Colors.white),
                ),
              ),
              const SizedBox(height: 34),
              Text(
                'Take a deep breath',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontStyle: FontStyle.italic,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You're in the right place.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.35),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: FilledButton(
                    onPressed: _nextPage,
                    style: FilledButton.styleFrom(
                      backgroundColor: _teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page2() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_softTop, _softBottom],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopSkip(),
              Text(
                "Let's get to know you",
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _teal,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'What brings you here today?',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D3A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us tailor your experience',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 20),
              _personaCard(
                icon: Icons.self_improvement,
                title: 'Adult with ADHD',
                subtitle: 'Navigating my own journey',
                accent: _teal,
                value: 'adult_with_adhd',
              ),
              _personaCard(
                icon: Icons.family_restroom,
                title: 'Parent of ADHD child',
                subtitle: 'Supporting my family',
                accent: const Color(0xFF7F67E8),
                value: 'parent_of_child',
              ),
              _personaCard(
                icon: Icons.favorite,
                title: 'Both',
                subtitle: 'Managing my own ADHD and my family',
                accent: const Color(0xFFE26CA8),
                value: 'both',
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _selectedPersona == null ? null : _nextPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    disabledBackgroundColor: _teal.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page3() {
    const interests = [
      'Getting things done',
      'Managing overwhelm',
      'Emotional regulation',
      'Building routines',
      'Focus and concentration',
      'Self-compassion',
      'Time management',
      'Sleep better',
    ];
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_softTop, _softBottom],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopSkip(),
              Text(
                'What matters most to you right now?',
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D3A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Pick as many as feel right',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: interests.map((interest) {
                  final selected = _selectedInterests.contains(interest);
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _toggleInterest(interest),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? _teal : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: selected ? null : Border.all(color: Colors.grey[350]!),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        interest,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: selected ? Colors.white : Colors.grey[800],
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard({
    required IconData icon,
    required Color accent,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2D2D3A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _page4() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_softTop, _softBottom],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTopSkip(),
              Text(
                "Here's what you'll get",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D3A),
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.96,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _featureCard(
                      icon: Icons.check_circle,
                      accent: _teal,
                      title: 'Focused Tasks',
                      subtitle: 'Daily planner designed for ADHD brains',
                    ),
                    _featureCard(
                      icon: Icons.timer,
                      accent: const Color(0xFF7F67E8),
                      title: 'Focus Sessions',
                      subtitle: 'Pomodoro timer with calming sounds',
                    ),
                    _featureCard(
                      icon: Icons.favorite,
                      accent: const Color(0xFFE26CA8),
                      title: 'Emotional Check-ins',
                      subtitle: 'Quick mood tracking with calming tools',
                    ),
                    _featureCard(
                      icon: Icons.psychology,
                      accent: const Color(0xFFF39B4A),
                      title: 'AI Coach Viv',
                      subtitle: 'Your 24/7 ADHD coach in your pocket',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page5() {
    final pulse = Tween<double>(begin: 0.96, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_softTop, _softBottom],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),
              ScaleTransition(
                scale: pulse,
                child: const Icon(
                  Icons.notifications_active,
                  size: 64,
                  color: _teal,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Gentle reminders?',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D2D3A),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                "We'll gently check in with you - only if you want.\nYou can change this anytime.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: () async {
                    await HapticFeedback.lightImpact();
                    await _completeOnboarding(enableNotifications: true);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _teal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    'Yes, remind me',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await HapticFeedback.lightImpact();
                  await _completeOnboarding(enableNotifications: false);
                },
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              _buildBottomNav(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _page1(),
      _page2(),
      _page3(),
      _page4(),
      _page5(),
    ];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _overlayForPage(),
      child: Scaffold(
        backgroundColor: _currentPage == 0 ? const Color(0xFF4EC8C8) : _softTop,
        body: PageView.builder(
          controller: _pageController,
          itemCount: pages.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            return _animatedPageShell(child: pages[index]);
          },
        ),
      ),
    );
  }
}
