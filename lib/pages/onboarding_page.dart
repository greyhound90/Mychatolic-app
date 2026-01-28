import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mychatolic_app/features/auth/pages/login_page.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _slides = [
    {
      'icon': Icons.public,
      'title': 'Satu Iman, Satu Gereja',
      'subtitle':
          'Terhubung dengan umat Katolik dari seluruh dunia, lintas negara dan paroki.',
      'color': Color(0xFF8B5CF6), // Purple
    },
    {
      'icon': Icons.volunteer_activism,
      'title': 'Berbagi Cerita Iman',
      'subtitle':
          'Bagikan pengalaman rohani dan temukan inspirasi dari sesama.',
      'color': Color(0xFFEC4899), // Pink
    },
    {
      'icon': Icons.church_rounded,
      'title': 'Cari Misa Dimanapun',
      'subtitle':
          'Temukan jadwal misa terdekat atau saat bepergian ke luar negeri.',
      'color': Color(0xFFF59E0B), // Amber
    },
  ];

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Navigate to Login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Widget _buildGlowingIcon(IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 60,
            spreadRadius: 10,
          ),
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 100,
            spreadRadius: 20,
          ),
        ],
      ),
      child: Icon(icon, size: 120, color: Colors.white),
    );
  }

  Widget _buildPageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_slides.length, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: _currentPage == index ? 24 : 8,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? const Color(0xFF8B5CF6) // Active Purple
                : Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1121), // Dark Premium Background
      body: Stack(
        children: [
          // 1. Top Section (Icon Slides)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.65, // 65% height
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
              },
              itemCount: _slides.length,
              itemBuilder: (context, index) {
                return Center(
                  child: _buildGlowingIcon(
                    _slides[index]['icon'],
                    _slides[index]['color'],
                  ),
                );
              },
            ),
          ),

          // 2. Bottom Card (Text & Controls)
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.40, // 40% height
              padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B), // Dark Slate
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 20,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Indicator
                  _buildPageIndicator(),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    _slides[_currentPage]['title'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  Text(
                    _slides[_currentPage]['subtitle'],
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),

                  const Spacer(),

                  // Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF8B5CF6),
                              Color(0xFF6366F1),
                            ], // Violet -> Indigo
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: Text(
                            _currentPage == _slides.length - 1
                                ? 'MULAI SEKARANG'
                                : 'LANJUT',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
