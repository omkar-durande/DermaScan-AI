import 'package:flutter/material.dart';
import '../../constants/colors.dart';

/// OTP screen — no longer used (Phone auth removed in favour of Email/Password).
/// Kept as an empty stub to avoid breaking any deep links or references.
class OtpScreen extends StatelessWidget {
  const OtpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.phone_disabled_rounded, size: 64, color: AppColors.textTertiary),
              SizedBox(height: 20),
              Text(
                'Phone login is no longer available.\nPlease use Email & Password to sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
