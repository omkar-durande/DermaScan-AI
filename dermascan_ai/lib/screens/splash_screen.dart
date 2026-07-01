import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';
import 'auth/email_verification_screen.dart';

/// Splash screen with app logo, animated fade-in, and auto-navigation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _slideUp;
  late Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeIn = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    _slideUp = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0.2, 0.7, curve: Curves.easeOut)),
    );

    _scaleIn = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    _controller.forward();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

    if (!mounted) return;

    if (isFirstLaunch) {
      Navigator.of(context).pushReplacementNamed('/onboarding');
      return;
    }

    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.of(context).pushReplacementNamed('/login');
    } else {
      // Refresh user session verification status
      final verified = await auth.checkEmailVerified();
      if (!mounted) return;
      if (!verified) {
        final email = FirebaseAuth.instance.currentUser?.email ?? '';
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => EmailVerificationScreen(email: email),
          ),
        );
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.splashGradient,
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeIn.value,
              child: Transform.translate(
                offset: Offset(0, _slideUp.value),
                child: Transform.scale(
                  scale: _scaleIn.value,
                  child: child,
                ),
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.biotech_rounded,
                  size: 52,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              // App name
              const Text(
                AppStrings.appName,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              // Tagline
              Text(
                AppStrings.appTagline,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withOpacity(0.8),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),
              // Loading indicator
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                    Colors.white.withOpacity(0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
