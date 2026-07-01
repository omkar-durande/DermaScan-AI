import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../constants/disease_data.dart';
import '../widgets/disease_card.dart';

/// Home remedies screen — list of all diseases with their remedies
class HomeRemediesScreen extends StatelessWidget {
  const HomeRemediesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text('Home Remedies', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Disclaimer banner
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.warning),
              const SizedBox(width: 10),
              const Expanded(child: Text(AppStrings.remedyDisclaimer, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4))),
            ]),
          ),
          // Disease cards
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: DiseaseData.allCodes.length,
              itemBuilder: (context, index) {
                final code = DiseaseData.allCodes[index];
                return DiseaseCard(
                  diseaseCode: code,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _DiseaseRemedyDetail(diseaseCode: code))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseRemedyDetail extends StatelessWidget {
  final String diseaseCode;
  const _DiseaseRemedyDetail({required this.diseaseCode});

  @override
  Widget build(BuildContext context) {
    final disease = DiseaseData.getDisease(diseaseCode);
    if (disease == null) return Scaffold(body: Center(child: Text('Disease not found')));

    final remedies = disease['remedies'] as List;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: Text(disease['full_name'], style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Text(disease['icon'], style: const TextStyle(fontSize: 28)), const SizedBox(width: 10), Expanded(child: Text(disease['full_name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)))]),
                const SizedBox(height: 10),
                Text(disease['description'], style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
              ]),
            ),
            const SizedBox(height: 20),
            const Text('Remedies', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ...remedies.map((r) {
              final remedy = r as Map<String, dynamic>;
              final ingredients = (remedy['ingredients'] as List?)?.cast<String>() ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(remedy['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  if (ingredients.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6, runSpacing: 6,
                      children: ingredients.map((i) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: Text(i, style: const TextStyle(fontSize: 12, color: AppColors.accent)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.info_outline, size: 16, color: AppColors.textTertiary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(remedy['application'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4))),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.schedule_rounded, size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Text(remedy['frequency'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.accent)),
                  ]),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}
