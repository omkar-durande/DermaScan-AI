import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';

/// Onboarding screen with 3 slides and medical disclaimer
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      icon: Icons.camera_alt_rounded,
      iconColor: AppColors.accent,
      title: AppStrings.onboardingTitle1,
      description: AppStrings.onboardingDesc1,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0A9396), Color(0xFF005F73)],
      ),
    ),
    _OnboardingSlide(
      icon: Icons.analytics_rounded,
      iconColor: AppColors.success,
      title: AppStrings.onboardingTitle2,
      description: AppStrings.onboardingDesc2,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF2A9D8F), Color(0xFF264653)],
      ),
    ),
    _OnboardingSlide(
      icon: Icons.local_hospital_rounded,
      iconColor: AppColors.warning,
      title: AppStrings.onboardingTitle3,
      description: AppStrings.onboardingDesc3,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1B3A5C), Color(0xFF0A2A43)],
      ),
    ),
  ];

  void _onNext() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentSlide = _slides[_currentPage];

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: currentSlide.gradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Skip Button Row ──
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 20, top: 8),
                  child: _currentPage < _slides.length - 1
                      ? TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : const SizedBox(height: 48), // Keep spacing consistent
                ),
              ),

              // ── Onboarding Page Slides ──
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _slides.length,
                  onPageChanged: (index) => setState(() => _currentPage = index),
                  itemBuilder: (context, index) {
                    final slide = _slides[index];
                    return _SlideView(slide: slide);
                  },
                ),
              ),

              // ── Bottom Fixed Section (Never overlaps with slide content) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Disclaimer
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.white.withOpacity(0.8),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              AppStrings.medicalDisclaimer,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 11,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Page Indicator Dots & Next/Get Started Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Dots Indicator
                        Row(
                          children: List.generate(
                            _slides.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 8),
                              width: _currentPage == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: _currentPage == index
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),

                        // Action Button
                        ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ],
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
}

class _OnboardingSlide {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final LinearGradient gradient;

  _OnboardingSlide({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.gradient,
  });
}

class _SlideView extends StatelessWidget {
  final _OnboardingSlide slide;

  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Large icon with soft glow
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.iconColor.withOpacity(0.35),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: 58,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 36),
          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.85),
              height: 1.5,
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
