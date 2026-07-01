import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../constants/disease_data.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../services/pdf_report_service.dart';
import '../widgets/scan_tile.dart';

/// Medical history screen with timeline, filters, and PDF export
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadScans());
  }

  void _loadScans() {
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) context.read<HistoryProvider>().loadScans(uid);
  }

  Future<void> _exportPdf(List scans) async {
    if (scans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No scans to export. Perform a scan first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isExporting = true);

    try {
      final auth = context.read<AuthProvider>();
      await PdfReportService.generateAndShare(
        scans: List.from(scans),
        user: auth.user,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          AppStrings.scanHistory,
          style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // No back arrow — inside IndexedStack
        actions: [
          Consumer<HistoryProvider>(
            builder: (context, history, _) => _isExporting
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: AppColors.accent, strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.picture_as_pdf_rounded,
                        color: AppColors.accent),
                    onPressed: () => _exportPdf(history.allScans),
                    tooltip: AppStrings.exportPdf,
                  ),
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, history, _) {
          return Column(
            children: [
              // Disease filter chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                        label: 'All',
                        isSelected: history.filterDisease == null,
                        onTap: () => history.setFilter(null)),
                    ...DiseaseData.allCodes.map((code) => _FilterChip(
                          label: code,
                          isSelected: history.filterDisease == code,
                          onTap: () => history.setFilter(code),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Show Firestore error if any
              if (history.error != null)
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(history.error!,
                            style: const TextStyle(
                                color: Colors.red, fontSize: 12)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close,
                            size: 16, color: Colors.red),
                        onPressed: () => history.clearError(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              // Scan list
              Expanded(
                child: history.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accent))
                    : history.scans.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_rounded,
                                    size: 64,
                                    color: AppColors.textTertiary),
                                const SizedBox(height: 16),
                                const Text(AppStrings.noScansYet,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 15)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16),
                            itemCount: history.scans.length,
                            itemBuilder: (context, index) {
                              final scan = history.scans[index];
                              return ScanTile(
                                scan: scan,
                                onTap: () => Navigator.pushNamed(
                                    context, '/results',
                                    arguments: scan),
                                onDelete: () =>
                                    history.deleteScan(scan.id),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color:
              isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : AppColors.border),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
