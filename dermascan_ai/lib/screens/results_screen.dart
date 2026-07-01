import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../constants/disease_data.dart';
import '../models/scan_result.dart';
import '../widgets/confidence_bar.dart';
import 'ai_chat_screen.dart';

/// Results screen showing prediction details, remedies, and actions
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _remediesExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scan = ModalRoute.of(context)?.settings.arguments as ScanResult?;
    if (scan == null) {
      return Scaffold(body: Center(child: Text('No scan data')));
    }

    final disease = DiseaseData.getDisease(scan.disease);
    final urgencyColor = AppColors.urgencyColor(scan.severity);
    final isMelanoma = scan.disease == 'MEL';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
        title: const Text(AppStrings.detectedDisease, style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Melanoma urgent warning
            if (isMelanoma) _buildUrgentBanner(),

            // Low confidence warning
            if (scan.isLowConfidence && !isMelanoma) _buildLowConfidenceBanner(),

            // Image preview with local file check and base64 fallback
            _buildImagePreview(scan),
            const SizedBox(height: 20),

            // Disease name + confidence
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(disease?['icon'] ?? '🔬', style: const TextStyle(fontSize: 36)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(scan.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: urgencyColor.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                              child: Text(scan.severity.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: urgencyColor)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Confidence circle
                  ConfidenceCircle(confidence: scan.confidence, size: 100),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // All probabilities
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AppStrings.allProbabilities, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ...scan.sortedScores.map((entry) {
                    final name = DiseaseData.getFullName(entry.key);
                    return ConfidenceBar(label: '$name (${entry.key})', value: entry.value, isTopResult: entry.key == scan.disease);
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Disease info
            if (disease != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(AppStrings.diseaseInfo, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 8),
                    Text(disease['description'] as String, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                    const SizedBox(height: 12),
                    const Text('Symptoms', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    ...(disease['symptoms'] as List).map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.accent),
                            const SizedBox(width: 8),
                            Expanded(child: Text(s, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                          ]),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Home remedies (collapsible)
              Container(
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _remediesExpanded = !_remediesExpanded),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.healing_rounded, size: 20, color: AppColors.accent),
                            const SizedBox(width: 10),
                            const Expanded(child: Text(AppStrings.homeRemedies, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                            Icon(_remediesExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                    if (_remediesExpanded) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 16, color: AppColors.warning),
                              const SizedBox(width: 8),
                              const Expanded(child: Text(AppStrings.remedyDisclaimer, style: TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...(disease['remedies'] as List).map((r) {
                        final remedy = r as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(remedy['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(remedy['application'], style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                                const SizedBox(height: 4),
                                Text('Frequency: ${remedy['frequency']}', style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),

            // Action buttons
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/hospitals'),
                icon: const Icon(Icons.local_hospital_rounded),
                label: const Text(AppStrings.findHospitals),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  final diseaseName = DiseaseData.getDisease(scan.disease)?['name'] as String? ?? scan.fullName;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AiChatScreen(initialContext: diseaseName),
                    ),
                  );
                },
                icon: const Icon(Icons.psychology_rounded),
                label: const Text('Ask AI About This Condition'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A9396),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            // Saved badge — always shown since scan is auto-saved
            Container(
              width: double.infinity, height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                SizedBox(width: 8),
                Text('Saved to history', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgentBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(gradient: AppColors.dangerGradient, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(child: Text(AppStrings.melanomaWarning, style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildLowConfidenceBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.warning.withOpacity(0.3))),
      child: Row(
        children: [
          const Icon(Icons.refresh_rounded, color: AppColors.warning, size: 22),
          const SizedBox(width: 12),
          const Expanded(child: Text(AppStrings.lowConfidenceWarning, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  Widget _buildImagePreview(ScanResult scan) {
    if (scan.imagePath != null && scan.imagePath!.isNotEmpty) {
      final file = File(scan.imagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      }
    }

    if (scan.imageUrl != null && scan.imageUrl!.startsWith('data:image')) {
      try {
        final base64Content = scan.imageUrl!.split(',').last;
        final bytes = base64Decode(base64Content);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      } catch (e) {
        debugPrint('[ResultsScreen] Error decoding base64 image: $e');
      }
    }

    // Placeholder if neither local nor cloud image exists
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined, size: 48, color: AppColors.textTertiary),
            SizedBox(height: 8),
            Text(
              'Image no longer available',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
