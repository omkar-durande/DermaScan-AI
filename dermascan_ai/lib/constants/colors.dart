import 'package:flutter/material.dart';

/// DermaScan AI Design System — Colors
class AppColors {
  AppColors._();

  // Primary palette
  static const Color primary = Color(0xFF1B3A5C);
  static const Color primaryLight = Color(0xFF2A5080);
  static const Color primaryDark = Color(0xFF0F2340);

  // Accent / Teal
  static const Color accent = Color(0xFF0A9396);
  static const Color accentLight = Color(0xFF14B8BB);

  // Semantic
  static const Color success = Color(0xFF2A9D8F);
  static const Color warning = Color(0xFFE9C46A);
  static const Color danger = Color(0xFFE63946);
  static const Color info = Color(0xFF457B9D);

  // Urgency levels
  static const Color urgencyLow = Color(0xFF2A9D8F);
  static const Color urgencyMedium = Color(0xFFE9C46A);
  static const Color urgencyHigh = Color(0xFFF4845F);
  static const Color urgencyCritical = Color(0xFFE63946);

  // Backgrounds
  static const Color background = Color(0xFFF0F4F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF7F9FC);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, success],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE63946), Color(0xFFFF6B6B)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B3A5C), Color(0xFF0A9396)],
  );

  /// Returns color based on confidence percentage
  static Color confidenceColor(double confidence) {
    if (confidence >= 0.8) return success;
    if (confidence >= 0.5) return warning;
    return danger;
  }

  /// Returns color based on urgency string
  static Color urgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'low':
        return urgencyLow;
      case 'medium':
        return urgencyMedium;
      case 'high':
        return urgencyHigh;
      case 'critical':
        return urgencyCritical;
      default:
        return textSecondary;
    }
  }
}
