import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';

/// Screen shown after signup — prompts user to verify their email.
/// Firebase sends a free verification email; we poll every 4s to detect click.
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with TickerProviderStateMixin {
  Timer? _pollTimer;
  bool _resendCooling = false;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;
  bool _checking = false;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Pulse animation for the email icon
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  Future<void> _checkVerified({bool manual = false}) async {
    if (_checking || !mounted) return;
    setState(() => _checking = true);
    debugPrint('[EmailVerificationScreen] Checking email verification status...');
    try {
      final verified = await context.read<AuthProvider>().checkEmailVerified();
      debugPrint('[EmailVerificationScreen] Verification status: $verified');
      if (!mounted) return;
      setState(() => _checking = false);
      if (verified) {
        debugPrint('[EmailVerificationScreen] Email verified! Navigating to /home.');
        if (mounted) Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      } else if (manual) {
        debugPrint('[EmailVerificationScreen] Email not verified yet. Showing SnackBar.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('❌ Email not verified yet. Please check your inbox and spam folders.'),
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmailVerificationScreen] Error checking verification: $e');
      if (mounted) {
        setState(() => _checking = false);
        if (manual) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Error checking status: $e'),
              backgroundColor: AppColors.danger,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    }
  }

  Future<void> _resendEmail() async {
    if (_resendCooling) return;
    final ok = await context.read<AuthProvider>().sendEmailVerification();
    if (!mounted) return;

    // Start 60-second cooldown on click to enforce rate limits
    setState(() {
      _resendCooling = true;
      _cooldownSeconds = 60;
    });
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _cooldownSeconds--);
      if (_cooldownSeconds <= 0) {
        t.cancel();
        setState(() => _resendCooling = false);
      }
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Verification email sent again!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<AuthProvider>().error ?? 'Failed to resend'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    _pollTimer?.cancel();
    await context.read<AuthProvider>().signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _cooldownTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated email icon
                      ScaleTransition(
                        scale: _pulse,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1B3A5C), Color(0xFF0A9396)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0A9396).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.mark_email_unread_rounded, color: Colors.white, size: 52),
                        ),
                      ),
                      const SizedBox(height: 36),

                      const Text(
                        'Verify your email',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We\'ve sent a verification link to',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.email,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                       const Text(
                        'Click the link in the email to activate your account, then click the button below to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
                      ),
                      const SizedBox(height: 12),

                      // Checking status indicator
                      if (_checking)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Checking status...',
                              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      const Spacer(),
                      const SizedBox(height: 24),

                      // Manual check button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () => _checkVerified(manual: true),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text("I've verified — Continue", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Resend button with cooldown
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _resendCooling ? null : _resendEmail,
                          icon: const Icon(Icons.send_rounded, size: 18),
                          label: Text(
                            _resendCooling
                                ? 'Resend in ${_cooldownSeconds}s'
                                : 'Resend verification email',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Wrong account? sign out
                      TextButton(
                        onPressed: _signOut,
                        child: const Text(
                          'Wrong account? Sign out',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
