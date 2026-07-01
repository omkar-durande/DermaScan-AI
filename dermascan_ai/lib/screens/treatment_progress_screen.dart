import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../models/treatment_log.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';

/// Treatment progress tracking screen
class TreatmentProgressScreen extends StatefulWidget {
  const TreatmentProgressScreen({super.key});

  @override
  State<TreatmentProgressScreen> createState() => _TreatmentProgressScreenState();
}

class _TreatmentProgressScreenState extends State<TreatmentProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final uid = context.read<AuthProvider>().uid;
      final disease = ModalRoute.of(context)?.settings.arguments as String?;
      if (uid != null) context.read<HistoryProvider>().loadTreatmentLogs(uid, disease: disease);
    });
  }

  void _addLog() {
    final disease = ModalRoute.of(context)?.settings.arguments as String? ?? '';
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _AddTreatmentSheet(disease: disease),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent, elevation: 0,
        title: const Text(AppStrings.treatmentProgress, style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary), onPressed: () => Navigator.pop(context)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addLog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Add Log', style: TextStyle(color: Colors.white)),
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, history, _) {
          if (history.treatmentLogs.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.healing_rounded, size: 64, color: AppColors.textTertiary),
                const SizedBox(height: 16),
                const Text('No treatment logs yet', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                const Text('Tap + to start tracking your treatment', style: TextStyle(color: AppColors.textTertiary, fontSize: 13)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: history.treatmentLogs.length,
            itemBuilder: (context, index) {
              final log = history.treatmentLogs[index];
              return _TreatmentLogTile(log: log);
            },
          );
        },
      ),
    );
  }
}

class _TreatmentLogTile extends StatelessWidget {
  final TreatmentLog log;
  const _TreatmentLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(log.improvementEmoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(log.treatment, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  Text(DateFormat('MMM dd, yyyy').format(log.date), style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: log.improvement == 'better' ? AppColors.success.withOpacity(0.1) : log.improvement == 'worse' ? AppColors.danger.withOpacity(0.1) : AppColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(log.improvement.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: log.improvement == 'better' ? AppColors.success : log.improvement == 'worse' ? AppColors.danger : AppColors.warning)),
              ),
            ],
          ),
          if (log.notes != null && log.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(log.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
          ],
        ],
      ),
    );
  }
}

class _AddTreatmentSheet extends StatefulWidget {
  final String disease;
  const _AddTreatmentSheet({required this.disease});

  @override
  State<_AddTreatmentSheet> createState() => _AddTreatmentSheetState();
}

class _AddTreatmentSheetState extends State<_AddTreatmentSheet> {
  final _treatmentController = TextEditingController();
  final _notesController = TextEditingController();
  String _improvement = 'same';

  @override
  void dispose() {
    _treatmentController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _save() {
    if (_treatmentController.text.isEmpty) return;
    final uid = context.read<AuthProvider>().uid ?? '';
    final log = TreatmentLog(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: uid, disease: widget.disease,
      date: DateTime.now(), treatment: _treatmentController.text,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
      improvement: _improvement,
    );
    context.read<HistoryProvider>().saveTreatmentLog(log);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.addTreatmentLog, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          TextField(controller: _treatmentController, decoration: InputDecoration(labelText: 'Treatment used', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 12),
          TextField(controller: _notesController, maxLines: 3, decoration: InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
          const SizedBox(height: 16),
          const Text(AppStrings.improvement, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: ['worse', 'same', 'better'].map((val) {
              final selected = _improvement == val;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _improvement = val),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.border),
                    ),
                    child: Center(child: Text(val.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.textSecondary))),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Save Log', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
