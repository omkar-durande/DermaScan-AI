import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/disease_data.dart';

/// Card widget showing disease information
class DiseaseCard extends StatelessWidget {
  final String diseaseCode;
  final VoidCallback? onTap;
  final bool showRemedyCount;

  const DiseaseCard({
    super.key,
    required this.diseaseCode,
    this.onTap,
    this.showRemedyCount = true,
  });

  @override
  Widget build(BuildContext context) {
    final disease = DiseaseData.getDisease(diseaseCode);
    if (disease == null) return const SizedBox.shrink();

    final urgency = disease['urgency'] as String;
    final urgencyColor = AppColors.urgencyColor(urgency);
    final remedies = disease['remedies'] as List;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon circle
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: urgencyColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    disease['icon'] as String,
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      disease['full_name'] as String,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _UrgencyBadge(urgency: urgency, color: urgencyColor),
                        if (showRemedyCount) ...[
                          const SizedBox(width: 8),
                          Text(
                            '${remedies.length} remedies',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  final String urgency;
  final Color color;

  const _UrgencyBadge({required this.urgency, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        urgency.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
