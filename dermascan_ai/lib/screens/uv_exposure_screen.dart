import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../services/location_service.dart';

/// UV Exposure screen with current UV index, advice, and weekly forecast
class UvExposureScreen extends StatefulWidget {
  const UvExposureScreen({super.key});

  @override
  State<UvExposureScreen> createState() => _UvExposureScreenState();
}

class _UvExposureScreenState extends State<UvExposureScreen> {
  double _uvIndex = 5.0; // Placeholder
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUVData();
  }

  Future<void> _loadUVData() async {
    // In production, fetch from OpenWeatherMap API
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() { _uvIndex = 5.2; _isLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final uvLabel = LocationService.getUVLabel(_uvIndex);
    final advice = LocationService.getProtectionAdvice(_uvIndex);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text(AppStrings.uvExposure, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // UV Index card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                        colors: _uvIndex <= 2 ? [const Color(0xFF4CAF50), const Color(0xFF2E7D32)]
                            : _uvIndex <= 5 ? [const Color(0xFFFFA726), const Color(0xFFF57C00)]
                            : _uvIndex <= 7 ? [const Color(0xFFFF7043), const Color(0xFFE64A19)]
                            : [const Color(0xFFE53935), const Color(0xFFB71C1C)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.wb_sunny_rounded, color: Colors.white, size: 48),
                        const SizedBox(height: 12),
                        Text(_uvIndex.toStringAsFixed(1), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white)),
                        Text(uvLabel, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.9))),
                        const SizedBox(height: 4),
                        Text('UV Index', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Protection advice
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [Icon(Icons.shield_rounded, color: AppColors.accent, size: 22), SizedBox(width: 10), Text(AppStrings.sunProtection, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary))]),
                        const SizedBox(height: 12),
                        Text(advice, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.5)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sunscreen reminder
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFF8E1), borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Text('🧴', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Sunscreen Reminder', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(_uvIndex > 3 ? 'Apply SPF 50+ sunscreen before going out' : 'SPF 30 recommended for outdoor activities', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      ])),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Best/worst times
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Best Times to Go Outside', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        _TimeRow(icon: Icons.check_circle_rounded, color: AppColors.success, label: 'Safe', time: 'Before 10:00 AM'),
                        _TimeRow(icon: Icons.check_circle_rounded, color: AppColors.success, label: 'Safe', time: 'After 4:00 PM'),
                        _TimeRow(icon: Icons.warning_rounded, color: AppColors.warning, label: 'Caution', time: '10:00 AM - 12:00 PM'),
                        _TimeRow(icon: Icons.dangerous_rounded, color: AppColors.danger, label: 'Avoid', time: '12:00 PM - 4:00 PM'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // UV Scale reference
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('UV Index Scale', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        const SizedBox(height: 12),
                        _UVScaleRow(range: '0–2', label: 'Low', color: const Color(0xFF4CAF50)),
                        _UVScaleRow(range: '3–5', label: 'Moderate', color: const Color(0xFFFFA726)),
                        _UVScaleRow(range: '6–7', label: 'High', color: const Color(0xFFFF7043)),
                        _UVScaleRow(range: '8–10', label: 'Very High', color: const Color(0xFFE53935)),
                        _UVScaleRow(range: '11+', label: 'Extreme', color: const Color(0xFF7B1FA2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon; final Color color; final String label; final String time;
  const _TimeRow({required this.icon, required this.color, required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Icon(icon, size: 18, color: color), const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _UVScaleRow extends StatelessWidget {
  final String range; final String label; final Color color;
  const _UVScaleRow({required this.range, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        SizedBox(width: 50, child: Text(range, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
      ]),
    );
  }
}
