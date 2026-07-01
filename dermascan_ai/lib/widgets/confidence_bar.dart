import 'package:flutter/material.dart';
import '../constants/colors.dart';

/// Animated confidence bar widget
class ConfidenceBar extends StatelessWidget {
  final String label;
  final double value;
  final bool isTopResult;
  final bool showPercentage;

  const ConfidenceBar({
    super.key,
    required this.label,
    required this.value,
    this.isTopResult = false,
    this.showPercentage = true,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.confidenceColor(value);
    final percentage = (value * 100).toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: isTopResult ? 14 : 13,
                    fontWeight: isTopResult ? FontWeight.w600 : FontWeight.w400,
                    color: isTopResult
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 8),
              if (showPercentage)
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontSize: isTopResult ? 14 : 13,
                    fontWeight: FontWeight.w600,
                    color: isTopResult ? color : AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, child) {
              return Stack(
                children: [
                  // Background
                  Container(
                    height: isTopResult ? 10 : 6,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  // Filled portion
                  FractionallySizedBox(
                    widthFactor: animatedValue.clamp(0.0, 1.0),
                    child: Container(
                      height: isTopResult ? 10 : 6,
                      decoration: BoxDecoration(
                        gradient: isTopResult
                            ? LinearGradient(
                                colors: [color, color.withOpacity(0.7)])
                            : null,
                        color: isTopResult ? null : color.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Large confidence display for results screen
class ConfidenceCircle extends StatelessWidget {
  final double confidence;
  final double size;

  const ConfidenceCircle({
    super.key,
    required this.confidence,
    this.size = 120,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.confidenceColor(confidence);
    final percentage = (confidence * 100).toStringAsFixed(1);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: confidence),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background circle
              CircularProgressIndicator(
                value: 1,
                strokeWidth: 8,
                color: color.withOpacity(0.12),
                strokeCap: StrokeCap.round,
              ),
              // Animated progress
              CircularProgressIndicator(
                value: animatedValue,
                strokeWidth: 8,
                color: color,
                strokeCap: StrokeCap.round,
              ),
              // Center text
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$percentage%',
                      style: TextStyle(
                        fontSize: size * 0.22,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    Text(
                      'Confidence',
                      style: TextStyle(
                        fontSize: size * 0.1,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
