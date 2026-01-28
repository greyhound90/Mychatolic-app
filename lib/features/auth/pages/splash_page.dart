import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mychatolic_app/features/auth/pages/login_page.dart';
import 'package:mychatolic_app/pages/main_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _arrowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _arrowAnimation = Tween<double>(
      begin: 0,
      end: 10,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToNextPage() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      // Wrap the entire Body in GestureDetector with Translucent behavior
      body: GestureDetector(
        behavior:
            HitTestBehavior.translucent, // Critical for full screen interaction
        onVerticalDragEnd: (details) {
          // Detect upward swipe (negative velocity)
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -200) {
            _navigateToNextPage();
          }
        },
        child: Stack(
          children: [
            // Layer 1: Premium Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.scaffoldBackgroundColor,
                    isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ],
                ),
              ),
            ),

            // Layer 2: Scattered Background Icons ("Stickers")
            _buildBackgroundIcon(
              Icons.church,
              80,
              20,
              100,
              angle: -15,
              color: theme.primaryColor,
            ),
            _buildBackgroundIcon(
              Icons.auto_awesome,
              150,
              300,
              60,
              angle: 20,
              color: theme.primaryColor,
            ),
            _buildBackgroundIcon(
              Icons.book,
              400,
              -20,
              120,
              angle: 10,
              color: theme.primaryColor,
            ),
            _buildBackgroundIcon(
              Icons.favorite,
              600,
              320,
              80,
              angle: -25,
              color: theme.primaryColor,
            ),
            // Scattered small stars
            _buildBackgroundIcon(
              Icons.star,
              200,
              150,
              20,
              color: theme.primaryColor,
            ),
            _buildBackgroundIcon(
              Icons.star,
              500,
              50,
              30,
              color: theme.primaryColor,
            ),
            _buildBackgroundIcon(
              Icons.star,
              700,
              200,
              25,
              color: theme.primaryColor,
            ),

            // Layer 3: Center Content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo with Glow
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withValues(alpha: 0.3),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/splash_logo_premium.png',
                      height: 120,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.church,
                          size: 80,
                          color: theme.primaryColor,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'MyCatholic',
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '100% KATOLIK',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: theme.textTheme.bodyMedium?.color,
                      letterSpacing: 2.0,
                    ),
                  ),
                ],
              ),
            ),

            // Layer 4: Floating Dock Button ("Geser Masuk")
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, -_arrowAnimation.value),
                      child: child,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(color: theme.dividerColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.keyboard_double_arrow_up,
                          color: theme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'GESER MASUK',
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.titleMedium?.color,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper Method for Background Icons
  Widget _buildBackgroundIcon(
    IconData icon,
    double top,
    double left,
    double size, {
    double angle = 0,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      child: Transform.rotate(
        angle: angle * (math.pi / 180),
        child: Icon(
          icon,
          size: size,
          color: color.withValues(alpha: 0.1), // Subtle styling
        ),
      ),
    );
  }
}
