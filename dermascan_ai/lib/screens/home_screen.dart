import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../constants/colors.dart';
import '../constants/strings.dart';
import '../providers/auth_provider.dart';
import '../providers/history_provider.dart';
import '../providers/scan_provider.dart';
import '../services/connectivity_service.dart';
import '../widgets/scan_tile.dart';
import '../widgets/offline_banner.dart';

/// Home screen / main dashboard
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final uid = context.read<AuthProvider>().uid;
    if (uid != null) {
      context.read<HistoryProvider>().loadScans(uid);
      context.read<ScanProvider>().checkServerHealth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Offline banner slides in automatically when no internet
            const OfflineBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  _loadData();
                  await ConnectivityService().checkNow();
                },
                color: AppColors.accent,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildServerStatus(),
                      const SizedBox(height: 20),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
                      const SizedBox(height: 24),
                      _buildAiChatBanner(),
                      const SizedBox(height: 24),
                      _buildRecentScans(),
                      const SizedBox(height: 24),
                      _buildUVCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        final name = auth.user?.displayName ?? 'User';
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${AppStrings.greeting}, $name 👋',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/profile'),
              child: () {
                final photoUrl = auth.user?.photoUrl;
                if (photoUrl != null && photoUrl.isNotEmpty) {
                  if (photoUrl.startsWith('data:image')) {
                    try {
                      final base64Content = photoUrl.split(',').last;
                      final bytes = base64Decode(base64Content);
                      return CircleAvatar(
                        radius: 22,
                        backgroundImage: MemoryImage(bytes),
                      );
                    } catch (e) {
                      // Fallback
                    }
                  } else {
                    return CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(photoUrl),
                    );
                  }
                }
                return CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'U',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                );
              }(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildServerStatus() {
    return Consumer<ScanProvider>(
      builder: (context, scan, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: scan.isServerHealthy ? AppColors.success.withOpacity(0.1) : AppColors.danger.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scan.isServerHealthy ? AppColors.success.withOpacity(0.3) : AppColors.danger.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(
                scan.isServerHealthy ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                size: 18,
                color: scan.isServerHealthy ? AppColors.success : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  scan.isServerHealthy ? 'AI Server is online' : 'AI Server is offline',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scan.isServerHealthy ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsRow() {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        final lastScan = history.lastScanDate;
        final lastScanStr = lastScan != null ? DateFormat('MMM dd').format(lastScan) : 'Never';
        return Row(
          children: [
            _StatCard(icon: Icons.document_scanner_rounded, label: AppStrings.totalScans, value: '${history.totalScans}', color: AppColors.accent),
            const SizedBox(width: 12),
            _StatCard(icon: Icons.calendar_today_rounded, label: AppStrings.lastScan, value: lastScanStr, color: AppColors.info),
            const SizedBox(width: 12),
            _StatCard(icon: Icons.local_fire_department_rounded, label: AppStrings.streakDays, value: '${history.streakDays}d', color: AppColors.warning),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Quick Actions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 12),
        Row(
          children: [
            _ActionButton(icon: Icons.camera_alt_rounded, label: 'Scan', gradient: AppColors.primaryGradient, onTap: () => Navigator.pushNamed(context, '/scan')),
            const SizedBox(width: 12),
            _ActionButton(icon: Icons.local_hospital_rounded, label: 'Hospitals', gradient: AppColors.accentGradient, onTap: () => Navigator.pushNamed(context, '/hospitals')),
            const SizedBox(width: 12),
            _ActionButton(icon: Icons.wb_sunny_rounded, label: 'UV Index', gradient: const LinearGradient(colors: [Color(0xFFE9C46A), Color(0xFFF4A261)]), onTap: () => Navigator.pushNamed(context, '/uv')),
            const SizedBox(width: 12),
            _ActionButton(icon: Icons.healing_rounded, label: 'Remedies', gradient: const LinearGradient(colors: [Color(0xFF2A9D8F), Color(0xFF4ECDC4)]), onTap: () => Navigator.pushNamed(context, '/remedies')),
          ],
        ),
      ],
    );
  }

  Widget _buildAiChatBanner() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/chat'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B3A5C), Color(0xFF0A9396)],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1B3A5C).withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ask AI Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  SizedBox(height: 3),
                  Text('Get answers about skin conditions · Free', style: TextStyle(fontSize: 12, color: Colors.white70)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('Chat', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScans() {
    return Consumer<HistoryProvider>(
      builder: (context, history, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(AppStrings.recentScans, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                if (history.allScans.isNotEmpty)
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/history'),
                    child: const Text('View All', style: TextStyle(color: AppColors.accent, fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (history.allScans.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.document_scanner_outlined, size: 40, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      const Text(AppStrings.noScansYet, textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
              )
            else
              ...history.recentScans.map((scan) => ScanTile(
                    scan: scan,
                    onTap: () => Navigator.pushNamed(context, '/results', arguments: scan),
                  )),
          ],
        );
      },
    );
  }

  Widget _buildUVCard() {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/uv'),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.wb_sunny_rounded, color: Colors.orange, size: 26),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('UV Index', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('Check today\'s UV levels for sun protection', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final LinearGradient gradient;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
